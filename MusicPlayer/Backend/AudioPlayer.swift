import Foundation
import GRDB

private let TIME_POS_ID = UInt64(1)
private let PLAYLIST_POS_ID = UInt64(2)

private enum LoadFile: String {
  case Append = "append"
  case Replace = "replace"
  case AppendPlay = "append-play"
}

private func wakeup(_ ctx: UnsafeMutableRawPointer?) {
  let obj = Unmanaged<AudioPlayer>.fromOpaque(ctx!).takeUnretainedValue()
  obj.eventQueue.async {
    obj.process_mpv_events(mpvHandle: obj.mpv)
  }
}

@MainActor
@Observable public class AudioPlayer {
  struct MpvHandle: @unchecked Sendable {
    var handle: OpaquePointer
    init(_ handle: OpaquePointer) { self.handle = handle }
  }
    public enum Mode: Int, RawRepresentable {
        case Sequential = 1
    case Shuffle = 2
    case AlbumShuffle = 3
  }
    public var mode: Mode
  public var paused = true
  public var currentSong: Song? = nil
  public var progress = Int64(0)
  @ObservationIgnored private var database: DatabaseQueue
  @ObservationIgnored let mpv: MpvHandle
  @ObservationIgnored private var queue = [Song](repeating: Song.dummy, count: 2)  // 0 next, 1 previous
  @ObservationIgnored let eventQueue = DispatchSerialQueue(label: "MPV EventQueue")
  public
    init(db: DatabaseQueue, volume: UInt = 40, shuffleMode: Mode = .AlbumShuffle)
  {
      self.database = db
      self.mode = shuffleMode
    let mpv_ctx = mpv_create()
    if mpv_initialize(mpv_ctx) != 0 || mpv_ctx == nil {
      preconditionFailure("Could not initialize MPV")
    }
    self.mpv = MpvHandle(mpv_ctx!)
    var v: Int64 = 100
    var cVolume = Int64(volume)
    if mpv_set_property(self.mpv.handle, "volume-max", MPV_FORMAT_INT64, &v) != 0 {
      preconditionFailure("property `volume-max` could not be set")
    }
    if mpv_set_property(self.mpv.handle, "volume", MPV_FORMAT_INT64, &cVolume) != 0 {
      preconditionFailure("property `volume` could not be set")
    }
    if mpv_set_property_string(self.mpv.handle, "gapless-audio", "weak") != 0 {
      preconditionFailure("property `gapless-audio` could not be set to `weak`")
    }
    if mpv_set_property_string(self.mpv.handle, "vid", "no") != 0 {
      preconditionFailure("property `vid` could not be set to `no`")
    }
    if mpv_observe_property(self.mpv.handle, TIME_POS_ID, "time-pos", MPV_FORMAT_INT64) != 0 {
      preconditionFailure("property `time-pos` could not be observed")
    }
    if mpv_observe_property(self.mpv.handle, PLAYLIST_POS_ID, "playlist-pos", MPV_FORMAT_INT64) != 0
    {
      preconditionFailure("property `playlist-pos` could not be observed")
    }

    mpv_set_wakeup_callback(self.mpv.handle, wakeup, Unmanaged.passUnretained(self).toOpaque())
  }
    public func setMode(_ mode: Mode) {
        self.mode = mode
        if let song = self.currentSong {
            self.newSongs(
                next: self.nextSong(song.path),
                previous: self.previousSong(song.path)
            )
        }
    }
    fileprivate nonisolated func process_mpv_events(mpvHandle: sending MpvHandle) {
    while true {
      let mpv_event = mpv_wait_event(mpvHandle.handle, 0)!
      switch mpv_event.pointee.event_id {
      case MPV_EVENT_PROPERTY_CHANGE:
        let data = UnsafeMutablePointer(
          mpv_event.pointee.data!.assumingMemoryBound(to: mpv_event_property.self))
        if data.pointee.format == MPV_FORMAT_INT64 {
          if mpv_event.pointee.reply_userdata == TIME_POS_ID {
            let newValue =
              data.pointee.data.assumingMemoryBound(to: Int64.self).pointee
            DispatchQueue.main.async {
              self.progress = newValue
            }
          }
//          if mpv_event.pointee.reply_userdata == PLAYLIST_POS_ID {
//            // file has been loaded
//            if data.pointee.data.assumingMemoryBound(to: Int64.self).pointee == 1 {
//              DispatchQueue.main.async {
//                self.preloadNext()
//              }
//            }
//          }
        }
        continue
      case MPV_EVENT_NONE:
        return
       case MPV_EVENT_END_FILE:
       let data = UnsafeMutablePointer(
         mpv_event.pointee.data!.assumingMemoryBound(to: mpv_event_end_file.self))
       if data.pointee.reason == MPV_END_FILE_REASON_EOF {
         DispatchQueue.main.async {
           self.preloadNext()
         }
       }
      case MPV_EVENT_SHUTDOWN:
        return
      default: continue
      }
    }
  }
  private func preloadNext() {
      // TODO: fix this
    let previous = self.currentSong
    self.clearPlaylist()
    let current = self.queueNext()
    self.currentSong = current
    self.newSongs(next: self.nextSong(current.path), previous: previous!)
  }

    private func queueNext() -> Song {
    self.queue[0]
  }

    private func queuePrevious() -> Song {
    self.queue[1]
  }

  private func newSongs(next: consuming Song, previous: consuming Song) {
    self.queue[0] = next
    self.queue[1] = previous
      self.loadFile(self.queue[0], flag: LoadFile.Append)
      self.loadFile(self.queue[1], flag: LoadFile.Append)
  }

  private func loadFile(_ song: borrowing Song, flag: borrowing LoadFile) {
    self.command("loadfile", arguments: [song.path, flag.rawValue])
  }

  func clearPlaylist() {
    self.command("playlist-clear")
  }

  private func command(_ command: borrowing String, arguments: [String] = []) {
    var list = [UnsafePointer<CChar>?]()
    list.reserveCapacity(2 + arguments.count)
    list.append(strdup(command))
    for x in arguments { list.append(strdup(x)) }
    list.append(nil)
      defer {
          for ptr in list
          {
              if ptr != nil {
                  free(UnsafeMutablePointer(mutating: ptr!))
              }
          }
      }
    let ret = list.withUnsafeMutableBufferPointer {
      mpv_command(self.mpv.handle, $0.baseAddress)
    }
    if ret != 0 {
      preconditionFailure(
        "Command \(command) \(arguments) failed: \(String(cString: mpv_error_string(ret)))")
    }
  }

  public func seek(_ percentage: Double) {
    self.command("seek", arguments: ["\(percentage)", "absolute-percent"])
  }
  public func seekAbsolute(_ value: Double) {
    self.command("seek", arguments: ["\(value)", "absolute"])
  }

  public func playSong(_ song: Song) {
    self.loadFile(song, flag: LoadFile.Replace)
    self.unpause()
    self.currentSong = song
    self.clearPlaylist()
    self.newSongs(next: self.nextSong(song.path), previous: self.previousSong(song.path))
  }

  public func playNext() {
    let song = self.queueNext()
    self.currentSong = song
    self.command("playlist-next")
    self.clearPlaylist()
    self.newSongs(next: self.nextSong(song.path), previous: self.previousSong(song.path))
  }

  public func playPrevious() {
    self.command("playlist-play-index", arguments: ["2"])
    self.clearPlaylist()
    let song = self.queuePrevious()
    self.currentSong = song
    self.newSongs(next: self.nextSong(song.path), previous: self.previousSong(song.path))
  }

  public func pause() {
    var flag: Int32 = 1
    self.paused = true
    mpv_set_property(self.mpv.handle, "pause", MPV_FORMAT_FLAG, &flag)
  }

  public func unpause() {
    var flag: Int32 = 0
    self.paused = false
    mpv_set_property(self.mpv.handle, "pause", MPV_FORMAT_FLAG, &flag)
  }

  public func playRandomStartOfAlbum() {
    self.playSong(self.randomStartOfAlbum())
  }

  func randomSong() -> Song {
    let song = try! self.database.read {
      try! Song.fetchOne(
        $0, sql: "SELECT \(Song.columns()) FROM song ORDER BY RANDOM() LIMIT 1")!
    }
    if song == self.currentSong {
      return randomSong()
    } else {
      return song
    }
  }

  func previousSong(_ song: String) -> Song {
    switch self.mode {
    case .AlbumShuffle:
      try! self.database.read {
        try! Song.fetchOne(
          $0,
          sql:
            """
            WITH selected_track AS (
            SELECT disc_number, track_number, album_title, artist_name
            FROM song
            WHERE path = ?
            )
            SELECT \(Song.columns())
            FROM song
            WHERE album_title = (SELECT album_title FROM selected_track)  -- same album
            AND artist_name = (SELECT artist_name FROM selected_track) -- same artist
            AND (disc_number, track_number) <
            (SELECT disc_number, track_number FROM selected_track)   -- later track
            ORDER BY disc_number DESC, track_number DESC
            LIMIT 1
            """,
          arguments: [song])
      } ?? self.randomStartOfAlbum()
    case .Sequential:
      try! self.database.read {
        try! Song.fetchOne(
          $0,
          sql:
            """
            SELECT \(Song.columns())
            FROM song
            WHERE (artist_name COLLATE NOCASE, album_title COLLATE NOCASE, disc_number, track_number) <
            (SELECT artist_name, album_title, disc_number, track_number
            FROM song
            WHERE path = ?1)
            ORDER BY artist_name COLLATE NOCASE DESC, album_title COLLATE NOCASE DESC, disc_number DESC, track_number DESC
            LIMIT 1
            """,
          arguments: [song])
      } ?? self.lastSong()
    case .Shuffle: self.randomSong()
    }
  }

  func nextSong(_ song: String) -> Song {
    switch self.mode {
    case .AlbumShuffle:
      try! self.database.read {
        try! Song.fetchOne(
          $0,
          sql:
            """
            WITH selected_track AS (
            SELECT disc_number, track_number, album_title, artist_name
            FROM song
            WHERE path = ?
            )
            SELECT \(Song.columns())
            FROM song
            WHERE album_title = (SELECT album_title FROM selected_track)  -- same album
            AND artist_name = (SELECT artist_name FROM selected_track) -- same artist
            AND (disc_number, track_number) >
            (SELECT disc_number, track_number FROM selected_track)   -- later track
            ORDER BY disc_number, track_number
            LIMIT 1
            """,
          arguments: [song])
      } ?? self.randomStartOfAlbum()
    case .Sequential:
      try! self.database.read {
        try! Song.fetchOne(
          $0,
          sql:
            """
            SELECT \(Song.columns())
            FROM song
            WHERE (artist_name COLLATE NOCASE, album_title COLLATE NOCASE, disc_number, track_number) <
            (SELECT artist_name, album_title, disc_number, track_number
            FROM song
            WHERE path = ?1)
            ORDER BY artist_name COLLATE NOCASE DESC, album_title COLLATE NOCASE DESC, disc_number DESC, track_number DESC
            LIMIT 1
            """,
          arguments: [song])
      } ?? self.firstSong()
    case .Shuffle: self.randomSong()
    }
  }

  func firstSong() -> Song {
    try! self.database.read {
      try! Song.fetchOne(
        $0,
        sql:
          """
          SELECT \(Song.columns())
          FROM song
          ORDER BY artist_name COLLATE NOCASE, album_title COLLATE NOCASE, disc_number, track_number
          LIMIT 1
          """)!
    }
  }

  func lastSong() -> Song {
    try! self.database.read {
      try! Song.fetchOne(
        $0,
        sql:
          """
          SELECT \(Song.columns())
          FROM song
          ORDER BY artist_name COLLATE NOCASE DESC, album_title COLLATE NOCASE DESC, disc_number DESC, track_number DESC
          LIMIT 1
          """)!
    }
  }

  func randomStartOfAlbum() -> Song {
    let song = try! self.database.read {
      try! Song.fetchOne(
        $0,
        sql:
          """
          SELECT \(Song.columns())
          FROM song
          WHERE track_number = 1 AND disc_number = 1
          ORDER BY RANDOM()
          LIMIT 1
          """)!
    }
    if song.albumTitle == self.currentSong?.albumTitle {
      return randomStartOfAlbum()
    } else {
      return song
    }
  }

  public func setVolume(_ vol: UInt) {
    var volume = UInt64(vol)
    mpv_set_property(self.mpv.handle, "volume", MPV_FORMAT_INT64, &volume)
  }

  deinit {
    mpv_terminate_destroy(mpv.handle)
  }
}
