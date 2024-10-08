import Foundation
import GRDB

public protocol Model {
  var rowid: Int { get }
}

public struct Song: Hashable, Codable, Model, Identifiable,
  Equatable, Sendable
{
  public let path: String
  public let songTitle: String
  public let artistName: String
  public let albumTitle: String
  public let discNumber: UInt
  public let trackNumber: UInt
  public let duration: UInt
  public let rowid: Int

  public var id: Int { rowid }
  public static let dummy = Song(
    path: "", songTitle: "", artistName: "", albumTitle: "", discNumber: 0, trackNumber: 0,
    duration: 0, rowid: 0)

  public static func columns(alias: String = "") -> String {
    let list = [
      "artist_name", "title", "album_title", "disc_number", "track_number", "rowid", "path",
      "duration",
    ]
    return
      (alias.isEmpty
      ? list
      : list.map { "\(alias).\($0)" }).joined(separator: ", ")
  }
  public static func == (lhs: Self, rhs: Self) -> Bool {
    return lhs.rowid == rhs.rowid
  }
  public static func lazyList(_ db: DatabaseQueue) -> LazyList<Song> {
    LazyList<Song>(
      db,
      totalSizeQuery: "SELECT count(rowid) FROM song",
      anchorQuery: #"""
        WITH Numbered AS (
          SELECT artist_name, title, album_title, disc_number, track_number, duration, rowid, path,
                 ROW_NUMBER()
                   OVER (ORDER BY artist_name COLLATE NOCASE, album_title COLLATE NOCASE, disc_number, track_number) as rn
          FROM song
        )

        SELECT artist_name, title, album_title, disc_number, track_number, duration, rowid, path
        FROM Numbered
        WHERE rn % ? = 1
        """#,
      fetchQuery: #"""
        SELECT artist_name, title, album_title, disc_number, track_number, duration, rowid, path
        FROM song
        WHERE (artist_name COLLATE NOCASE, album_title COLLATE NOCASE, disc_number, track_number) >=
              (SELECT artist_name COLLATE NOCASE, album_title COLLATE NOCASE, disc_number, track_number
               FROM song
               WHERE rowid = ?)
        ORDER BY artist_name COLLATE NOCASE, album_title COLLATE NOCASE, disc_number, track_number
        LIMIT ?
        """#
    )
  }
  public static func array(_ db: DatabasePool) -> [Song] {
    try! db.read {
      try! Song.fetchAll(
        $0,
        sql:
          #"""
              SELECT artist_name, title, album_title, disc_number, track_number, duration, rowid, path
              FROM song            
              ORDER BY artist_name COLLATE NOCASE, album_title COLLATE NOCASE, disc_number, track_number
          """#)
    }
  }
}

extension Song: FetchableRecord {
  public init(row: Row) throws {
    self.path = row["path"]
    self.songTitle = row["title"]
    self.artistName = row["artist_name"]
    self.albumTitle = row["album_title"]
    self.discNumber = row["disc_number"]
    self.duration = row["duration"]
    self.rowid = row["rowid"]
    self.trackNumber = row["track_number"]
  }
}

public struct Album: Hashable, Model, Identifiable, Equatable, PersistableRecord,
  Codable
{
  public let artistName: String
  public let albumTitle: String
  public let rowid: Int
  public static func columns(alias: String = "") -> String {
    let list = ["album_title", "artist_name", "rowid"]
    return
      (alias.isEmpty
      ? list
      : list.map { "\(alias).\($0)" }).joined(separator: ", ")
  }
  public var id: Int { rowid }
  public static func == (lhs: Self, rhs: Self) -> Bool {
    return lhs.rowid == rhs.rowid
  }
  public static func lazyList(_ db: DatabaseQueue) -> LazyList<Album> {
    LazyList<Album>(
      db,
      totalSizeQuery: "SELECT count(rowid) FROM album",
      anchorQuery: #"""
        WITH Numbered AS (
        SELECT album_title, artist_name, rowid,
                 ROW_NUMBER()
                   OVER (ORDER BY artist_name COLLATE NOCASE, album_title COLLATE NOCASE) as rn
          FROM album
        )

        SELECT album_title, artist_name, rowid
        FROM Numbered
        WHERE rn % ? = 1
        """#,
      fetchQuery: #"""
        SELECT album_title, artist_name, rowid
        FROM album
        WHERE (artist_name COLLATE NOCASE, album_title COLLATE NOCASE) >=
              (SELECT artist_name COLLATE NOCASE, album_title COLLATE NOCASE
               FROM album
               WHERE rowid = ?)
        ORDER BY artist_name COLLATE NOCASE, album_title COLLATE NOCASE
        LIMIT ?
        """#
    )
  }
}

extension Album: FetchableRecord {
  public init(row: Row) throws {
    self.rowid = row["rowid"]
    self.albumTitle = row["album_title"]
    self.artistName = row["artist_name"]
  }
}
