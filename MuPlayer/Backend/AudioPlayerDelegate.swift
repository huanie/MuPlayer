//
//  AudioPlayer.swift
//  MuPlayer
//
//  Created by Huan Thieu Nguyen on 08.04.25.
//

import AppKit
import Foundation
import GRDB
import MediaPlayer
import SFBAudioEngine
import SwiftUI

private let SEQUENTIAL_ORDERING =
    "artistName COLLATE NOCASE, albumTitle COLLATE NOCASE, discNumber, trackNumber"

private let SEQUENTIAL_ORDERING_DESC =
    "artistName COLLATE NOCASE DESC, albumTitle COLLATE NOCASE DESC, discNumber DESC, trackNumber DESC"

@Observable
class AudioPlayerDelegate: NSObject, AudioPlayer.Delegate {
    enum PlaybackMode: Int {
        case sequential, shuffle, albumShuffle
    }
    var defaultMode: PlaybackMode {
        get {
            PlaybackMode(
                rawValue: UserDefaults.standard.integer(forKey: "playbackMode")
            ) ?? .sequential
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "playbackMode")
        }
    }
    @ObservationIgnored let pool: DatabasePool
    let lastFM: LastFM
    var playbackState = AudioPlayer.PlaybackState.paused
    var progress = 0
    var mode: PlaybackMode {
        didSet {
            defaultMode = mode
        }
    }
    var currentSong: Model.Song?
    init(
        pool: DatabasePool,
        playbackState: AudioPlayer.PlaybackState = AudioPlayer.PlaybackState
            .paused,
        progress: Int = 0,
        lastFM: LastFM
    ) {
        self.pool = pool
        self.playbackState = playbackState
        self.progress = progress
        self.lastFM = lastFM
        self.mode =
            PlaybackMode(
                rawValue: UserDefaults.standard.integer(forKey: "playbackMode")
            ) ?? .sequential
    }

    func audioPlayer(
        _ audioPlayer: AudioPlayer,
        encounteredError error: any Error
    ) {
        preconditionFailure(error.localizedDescription)
    }

    func audioPlayer(
        _ audioPlayer: AudioPlayer,
        playbackStateChanged playbackState: AudioPlayer.PlaybackState
    ) {
        self.playbackState = playbackState
    }

    func playAlbum(_ audioPlayer: AudioPlayer, album: Model.Album) throws {
        let song = try pool.read {
            try Model.Song
                .filter(
                    sql: "artistName = ? AND albumTitle = ?",
                    arguments: [album.artist, album.title]
                )
                .order(Column("discNumber"), Column("trackNumber"))
                .limit(1)
                .fetchOne($0)
        }
        try audioPlayer.play(song!.path)
    }

    func audioPlayer(
        _ audioPlayer: AudioPlayer,
        renderingComplete decoder: any PCMDecoding
    ) {
        if let song = currentSong {
            lastFM.scrobble(song)
        }
    }

    func randomSong() throws -> Model.Song {
        return try pool.read {
            try Model.Song.order(sql: "RANDOM()")
                .limit(1)
                .fetchOne($0)!
        }
    }

    func firstSongOfCollection() throws -> Model.Song {
        try pool.read {
            try Model.Song.order(sql: SEQUENTIAL_ORDERING)
                .limit(1)
                .fetchOne($0)!
        }
    }

    func lastSongOfCollection() throws -> Model.Song {
        try pool.read {
            try Model.Song.order(sql: SEQUENTIAL_ORDERING_DESC)
                .limit(1)
                .fetchOne($0)!
        }
    }

    func pause(_ audioPlayer: AudioPlayer, progress: TimeInterval) {
        let remoteCenter = MPNowPlayingInfoCenter.default()
        remoteCenter.playbackState = .paused
        remoteCenter.nowPlayingInfo?[
            MPNowPlayingInfoPropertyElapsedPlaybackTime
        ] = NSNumber(value: progress)
        audioPlayer.pause()
    }

    func resume(_ audioPlayer: AudioPlayer, progress: TimeInterval) {
        let remoteCenter = MPNowPlayingInfoCenter.default()
        remoteCenter.playbackState = .playing
        remoteCenter.nowPlayingInfo?[
            MPNowPlayingInfoPropertyElapsedPlaybackTime
        ] = NSNumber(value: progress)
        try! audioPlayer.play()
    }

    func firstSong() throws -> Model.Song {
        switch mode {
        case .sequential:
            try firstSongOfCollection()
        case .shuffle:
            try randomSong()
        case .albumShuffle:
            try randomStartOfAlbum()
        }
    }

    func lastSong() throws -> Model.Song {
        switch mode {
        case .sequential:
            try lastSongOfCollection()
        case .shuffle:
            try randomSong()
        case .albumShuffle:
            try randomStartOfAlbum()
        }
    }

    func previousSong(_ url: URL) throws -> Model.Song {
        return
            switch mode
        {
        case .sequential:
            try pool.read {
                try Model.Song.filter(
                    sql: #"""
                        (artistName COLLATE NOCASE, albumTitle COLLATE NOCASE, discNumber, trackNumber) <
                        (SELECT artistName COLLATE NOCASE, albumTitle COLLATE NOCASE, discNumber, trackNumber
                        FROM song
                        WHERE path = ?)
                        """#,
                    arguments: [url]
                )
                .order(sql: SEQUENTIAL_ORDERING_DESC)
                .limit(1)
                .fetchOne($0)
            } ?? lastSongOfCollection()
        case .shuffle:
            try randomSong()
        case .albumShuffle:
            try pool.read {
                return try Model.Song
                    .fetchOne(
                        $0,
                        sql: #"""
                            WITH selectedTrack AS (
                                SELECT discNumber, trackNumber, albumTitle, artistName
                                FROM song
                                WHERE path = ?
                            )
                            SELECT song.*, song.rowid
                            FROM song
                            WHERE albumTitle = (SELECT albumTitle FROM selectedTrack)
                            AND artistName = (SELECT artistName FROM selectedTrack)
                            AND (discNumber, trackNumber) <
                                (SELECT discNumber, trackNumber FROM selectedTrack)
                            ORDER BY discNumber DESC, trackNumber DESC
                            LIMIT 1
                            """#,
                        arguments: [url]
                    )
            } ?? randomStartOfAlbum()
        }
    }

    func nextSong(_ url: URL) throws -> Model.Song {
        return
            switch mode
        {
        case .sequential:
            try pool.read {
                try Model.Song.filter(
                    sql: #"""
                        (artistName COLLATE NOCASE, albumTitle COLLATE NOCASE, discNumber, trackNumber) > 
                        (SELECT artistName COLLATE NOCASE, albumTitle COLLATE NOCASE, discNumber, trackNumber
                        FROM song
                        WHERE path = ?)
                        """#,
                    arguments: [url]
                )
                .order(sql: SEQUENTIAL_ORDERING)
                .limit(1)
                .fetchOne($0)
            } ?? firstSongOfCollection()
        case .shuffle:
            try randomSong()
        case .albumShuffle:
            try pool.read {
                return try Model.Song
                    .fetchOne(
                        $0,
                        sql: #"""
                            WITH selectedTrack AS (
                                SELECT discNumber, trackNumber, albumTitle, artistName
                                FROM song
                                WHERE path = ?
                            )
                            SELECT song.*, song.rowid
                            FROM song
                            WHERE albumTitle = (SELECT albumTitle FROM selectedTrack)
                            AND artistName = (SELECT artistName FROM selectedTrack)
                            AND (discNumber, trackNumber) >
                                (SELECT discNumber, trackNumber FROM selectedTrack)
                            ORDER BY discNumber, trackNumber
                            LIMIT 1
                            """#,
                        arguments: [url]
                    )
            } ?? randomStartOfAlbum()
        }
    }

    func randomStartOfAlbum() throws -> Model.Song {
        return try pool.read {
            try Model.Song.fetchOne(
                $0,
                sql: #"""
                    SELECT s.rowid, s.*
                    FROM song s
                    JOIN (SELECT artist, title FROM album ORDER BY RANDOM() LIMIT 1) a on s.artistName = a.artist AND s.albumTitle = a.title
                    ORDER BY discNumber, trackNumber LIMIT 1
                    """#
            )!
        }
    }

    func playNext(_ audioPlayer: AudioPlayer, nowPlaying: (Model.Song) -> Void)
        throws
    {
        let song =
            if let current = currentSong {
                try nextSong(current.path)
            } else {
                try firstSong()
            }
        try audioPlayer.play(song.path)
        nowPlaying(song)
    }

    func playPrevious(
        _ audioPlayer: AudioPlayer,
        nowPlaying: (Model.Song) -> Void
    ) throws {
        let song =
            if let current = currentSong {
                try previousSong(current.path)
            } else {
                try lastSong()
            }
        try audioPlayer.play(song.path)
        nowPlaying(song)
    }

    func audioPlayer(
        _ audioPlayer: AudioPlayer,
        nowPlayingChanged nowPlaying: (any PCMDecoding)?,
        previouslyPlaying: (any PCMDecoding)?
    ) {
        guard let now = nowPlaying else {
            return
        }
        let current = self.getSong(now)!
        let song = try! self.pool
            .read {
                try Model.Song.filter(key: ["path": current.url]).fetchOne(
                    $0
                )
            }
        let imageData = current.metadata.attachedPictures.first?
            .imageData
        let nsImage: NSImage? =
            if let data = imageData { NSImage(data: data) } else { nil }
        lastFM.updateNowPlaying(song!)

        DispatchQueue.main.async {
            self.currentSong = song
            self.updateNowPlaying(
                self.currentSong!,
                image: nsImage
            )

            try! audioPlayer.enqueue(self.nextSong(current.url).path)
        }
    }

    func updateNowPlaying(_ song: borrowing Model.Song, image: NSImage?) {
        let nowPlaying = MPNowPlayingInfoCenter.default()
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = song.songTitle
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = song.albumTitle
        nowPlayingInfo[MPMediaItemPropertyArtist] = song.artistName
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = NSNumber(
            value: song.duration
        )
        nowPlayingInfo[MPMediaItemPropertyDiscNumber] = song.discNumber
        nowPlayingInfo[MPMediaItemPropertyAlbumTrackNumber] = song.trackNumber
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0

        if let nsImage = image {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(
                boundsSize: nsImage.size,
                requestHandler: { _ in nsImage }
            )
        }

        nowPlaying.playbackState =
            switch playbackState {
            case .paused: MPNowPlayingPlaybackState.paused
            case .playing: .playing
            case .stopped: .stopped
            @unknown default:
                .unknown
            }

        nowPlaying.nowPlayingInfo = nowPlayingInfo
    }

    func getSong(_ nowPlaying: (any PCMDecoding)?) -> AudioFile? {
        guard let url = nowPlaying?.inputSource.url else {
            return nil
        }
        return try? AudioFile(readingPropertiesAndMetadataFrom: url)
    }

}
