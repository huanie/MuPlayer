import GRDB
import SwiftUI

public struct AlbumButton: ButtonStyle {
  var selected: Bool
  public func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
      .font(.system(size: 14))
      .foregroundStyle(
        selected
          ? Color(nsColor: NSColor.textBackgroundColor)
          : Color(nsColor: NSColor.textColor)
      )
      .padding(.vertical)
      .padding(.leading, 10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .clipShape(.rect)
      .background(
        selected
          ? Color.accentColor
          : Color(nsColor: NSColor.textBackgroundColor))
  }
}

struct DefaultImage: View {
  var body: some View {
    Image(systemName: "music.note")
      .font(.system(size: 128))
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .scaledToFit()
      .padding()
  }
}

struct AlbumSongSplitView: View {
  let database: DatabaseQueue
  let albums: LazyList<Album>
  let mpv: AudioPlayer
  @State var albumArtPath: String?
  @State var selectedAlbum: Int?
  @State var selectedSong: Song.ID?
  init(db: DatabaseQueue, mpv: AudioPlayer) {
    self.database = db
    self.albums = Album.lazyList(db)
    self.mpv = mpv
    self.selectedAlbum = nil
    self.albumArtPath = nil
  }
  var body: some View {
    HSplitView {
      ScrollViewReader { scrollReader in
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(albums, id: \.rowid) { row in
              Button(
                action: {
                  if self.selectedAlbum == row.rowid {
                    self.mpv.playSong(
                      try! database.read {
                        try! Song.fetchOne(
                          $0,
                          sql: """
                            SELECT \(Song.columns(alias: "s"))
                            FROM song s
                            INNER JOIN album a on a.album_title = s.album_title AND a.artist_name = s.album_artist
                            WHERE s.disc_number = 1 AND s.track_number = 1 AND a.rowid = ?
                            """,
                          arguments: [
                            self.selectedAlbum!
                          ])!
                      })
                  } else {
                    self.selectedAlbum = row.rowid
                  }
                },
                label: {
                  LabeledContent(
                    content: {
                      VStack(alignment: .leading) {
                        Text(row.artistName)
                          .lineLimit(1)
                          .allowsTightening(true)

                        Text(row.albumTitle)
                          .lineLimit(1)
                          .allowsTightening(true)

                      }.padding(.trailing)
                    },
                    label: {
                      if mpv.currentSong?.albumTitle
                        == row.albumTitle
                      {
                        Image(systemName: "play.fill")
                      } else {
                        Image(systemName: "play.fill")
                          .hidden()
                      }
                    })
                }
              )
              .buttonStyle(
                AlbumButton(
                  selected: self.selectedAlbum == row.rowid)
              )
              .padding(0)
            }.onChange(of: self.mpv.currentSong) {
              if let currentSong = self.mpv.currentSong {
                self.selectedAlbum = try! database.read {
                  try! Int.fetchOne(
                    $0,
                    sql: """
                      SELECT a.rowid
                      FROM song s
                      INNER JOIN album a on a.album_title = s.album_title AND a.artist_name = s.album_artist
                      WHERE s.album_title = ? AND s.album_artist = ?
                      """,
                    arguments: [
                      currentSong.albumTitle,
                      currentSong.albumArtist,
                    ])
                }
                scrollReader.scrollTo(self.selectedAlbum!)
              }
            }
          }
        }
      }
      VStack {
        if let rowid = self.selectedAlbum {
          let songs = try! database.read {
            try! Song.fetchAll(
              $0,
              sql:
                """
                SELECT \(Song.columns(alias: "s"))
                FROM song s
                INNER JOIN album a on a.album_title = s.album_title AND a.artist_name = s.album_artist
                WHERE a.rowid = ?
                ORDER BY s.album_artist COLLATE NOCASE, s.album_title COLLATE NOCASE, s.disc_number, s.track_number
                """, arguments: [rowid]
            )
          }
          if let image = albumArt(for: songs.first!.path) {
            Image(
              nsImage: image
            ).resizable()
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .scaledToFit()
              .padding()
          } else {
            DefaultImage()
          }
          ScrollViewReader { scrollReader in
            ScrollView {
              LazyVStack(spacing: 0) {
                ForEach(
                  songs,
                  id: \.rowid
                ) { song in
                  VStack {
                    Divider().hidden()
                    HStack {
                      Image(systemName: "play.fill")
                        .opacity(
                          self.mpv.currentSong?.rowid
                            == song.rowid ? 1 : 0
                        ).padding(.leading)
                      Text(
                        "\(song.discNumber).\(song.trackNumber)"
                      )
                      Text(song.songTitle)
                        .allowsTightening(true)
                        .lineLimit(1)
                      Spacer()
                      Text(formatTime(song.duration))
                        .padding(.trailing)
                    }
                    Divider()
                  }.foregroundStyle(
                    self.selectedSong == song.rowid
                      ? Color(
                        nsColor: NSColor
                          .textBackgroundColor)
                      : Color(nsColor: NSColor.textColor)
                  )
                  .font(.system(.title2))
                  .background(
                    self.selectedSong == song.rowid
                      ? Color.accentColor
                      : Color(
                        nsColor: NSColor
                          .textBackgroundColor)
                  )
                  .onTapGesture(count: 1) {
                    self.selectedSong = song.rowid
                    self.mpv.playSong(song)
                  }
                }
              }.onChange(of: self.mpv.currentSong) {
                scrollReader.scrollTo(
                  self.mpv.currentSong!.rowid)
              }
            }
          }
          .frame(maxHeight: .infinity)
          .background(.background)
        } else {
          VStack(spacing: 0) {
            DefaultImage()
            Text("Select an album in the Album column")
              .font(.system(.title))
              .padding(.bottom)
              .padding(.horizontal)
          }
        }
      }
    }
  }
}
