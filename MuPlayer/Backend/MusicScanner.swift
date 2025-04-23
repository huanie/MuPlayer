//
//  MusicScanner.swift
//  MuPlayer
//
//  Created by Huan Thieu Nguyen on 06.04.25.
//

import Foundation
import GRDB
import SFBAudioEngine

enum MusicScanner {
    struct ScanError: Error, Identifiable {
        var id = UUID()
        let path: URL
        let message: String
        init(path: consuming URL, message: consuming String) {
            self.path = path
            self.message = message
        }
    }

    static func clearDatabase() throws {
        let queue = try DatabaseQueue(
            path: Globals.DATABASE_PATH.path(percentEncoded: false)
        )
        try queue.write {
            try Model.Song.deleteAll($0)
            try Model.Album.deleteAll($0)
            try Model.Directory.deleteAll($0)
            try Model.Artist.deleteAll($0)
            try $0.execute(literal: "DELETE FROM songSearch")
        }
    }

    static func rescan(directories: Set<URL>, destination: URL) -> [ScanError]?
    {
        try! clearDatabase()
        return scan(directories: directories, destination: destination)
    }

    static func scan(directories: Set<URL>, destination: URL) -> [ScanError]? {
        let dir = destination.deletingLastPathComponent()
        if !FileManager.default.fileExists(
            atPath: dir.path(percentEncoded: false)
        ) {
            try! FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true
            )
        }
        var config = Configuration()
        config.readonly = false
        config.readonly = false
        config.journalMode = .wal
        config.maximumReaderCount = 1
        let pool = try! DatabasePool(
            path: destination.path(percentEncoded: false),
            configuration: config
        )
        try! pool.write(Model.writeSchema)
        let group = DispatchGroup()
        let queue = DispatchQueue(
            label: "com.github.huanie.MuPlayer.ScanQueue",
            qos: .utility,
            attributes: .concurrent
        )
        var failures: [ScanError] = []

        for dir in directories {
            try! pool.write {
                try Model.Directory(
                    path: dir,
                    modifiedStamp: FileManager.default
                        .attributesOfItem(
                            atPath: dir.path(percentEncoded: false)
                        )[.modificationDate]! as! Date
                ).insert($0)
            }
            for file in FileManager.default.enumerator(
                at: dir,
                includingPropertiesForKeys: [
                    .contentModificationDateKey, .isDirectoryKey,
                    .isRegularFileKey,
                ]
            )! {
                queue.async(group: group) {
                    do {
                        let fileURL = file as! URL
                        if !Globals.AUDIO_EXTENSIONS.contains(
                            fileURL.pathExtension
                        ) {
                            return
                        } else {
                            try insert(
                                path: fileURL,
                                directory: dir,
                                pool: pool
                            )
                        }
                    } catch let error as ScanError {
                        failures.append(error)
                    } catch {
                        fatalError(
                            "Something went wrong at processing \(file as! URL): \(error.localizedDescription)"
                        )
                    }
                }
            }
        }
        group.wait()
        try! pool.write { db in
            try db.execute(
                sql: """
                    INSERT INTO songSearch (title, artistName, albumTitle, path)
                    SELECT songTitle, artistName, albumTitle, path FROM song
                    """
            )
        }
        if !failures.isEmpty {
            return failures
        } else {
            return nil
        }
    }

    static private func insert(path: URL, directory: URL, pool: DatabasePool)
        throws
    {
        do {
            let file = try AudioFile(readingPropertiesAndMetadataFrom: path)
            let metadata = file.metadata
            let artist =
                metadata.albumArtist ?? metadata.artist
                ?? Globals.Defaults.NO_ARTIST
            let album = metadata.albumTitle ?? Globals.Defaults.NO_ALBUM
            let disc = metadata.discNumber ?? Globals.Defaults.NO_DISC
            let title = metadata.title ?? Globals.Defaults.NO_TITLE
            let track = metadata.trackNumber ?? Globals.Defaults.NO_TRACK_NR
            let duration = file.properties.duration!
            let fileModified = try path.resourceValues(forKeys: [
                .contentModificationDateKey
            ]).contentModificationDate!
            try pool.write { db in
                try Model.Artist(name: artist).insert(db, onConflict: .ignore)
                try Model.Album(title: album, artist: artist).insert(
                    db,
                    onConflict: .ignore
                )
                try Model.Song(
                    path: path,
                    directory: directory,
                    songTitle: title,
                    artistName: artist,
                    albumTitle: album,
                    duration: duration,
                    trackNumber: track,
                    discNumber: disc,
                    modifiedStamp: fileModified,
                    rowid: nil
                ).insert(db)
            }
        } catch {
            throw ScanError(path: path, message: error.localizedDescription)
        }
    }
}
