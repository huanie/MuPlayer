//
//  PlayerView.swift
//  MuPlayer
//
//  Created by Huan Thieu Nguyen on 08.04.25.
//

import AsyncAlgorithms
import CSFBAudioEngine
import GRDB
import MediaPlayer
import SwiftUI

struct MainView: View {
    enum PlaybackMode: Int, RawRepresentable {
        case sequential
        case shuffle
        case albumShuffle
    }
    init(_ db: DatabasePool, lastFM: LastFM) {
        self.player = AudioPlayer()
        self.playerDelegate = AudioPlayerDelegate(pool: db, lastFM: lastFM)
        self.pool = db
        self.albums = try! pool.read {
            try Model.Album
                .order(sql: "artist COLLATE NOCASE, title COLLATE NOCASE")
                .fetchAll($0)
        }
        //        self.albums = LazyList(
        //            db,
        //            totalSizeQuery: "SELECT count(rowid) FROM album",
        //            anchorQuery: #"""
        //                WITH Numbered AS (
        //                SELECT title, artist, rowid,
        //                    ROW_NUMBER()
        //                        OVER (ORDER BY artist COLLATE NOCASE, title COLLATE NOCASE) as rn
        //                FROM album )
        //
        //                SELECT title, artist, rowid
        //                FROM Numbered
        //                WHERE rn % ? = 1
        //                """#,
        //            fetchQuery: #"""
        //                SELECT title, artist, rowid
        //                FROM album
        //                WHERE
        //                    (artist COLLATE NOCASE, title COLLATE NOCASE) >=
        //                    (SELECT artist COLLATE NOCASE, title COLLATE NOCASE
        //                    FROM album
        //                    WHERE rowid = ?)
        //                ORDER BY artist COLLATE NOCASE, title COLLATE NOCASE
        //                LIMIT ?
        //                """#
        //        )
        self.timer = SafeDispatchSourceTimer(queue: .main)
        self.player.delegate = self.playerDelegate

        timer.timer
            .schedule(
                deadline: DispatchTime.now(),
                repeating: .milliseconds(200),
                leeway: .milliseconds(100)
            )
        try! self.player.setVolume(Float(self.volume))
        self.initCommandCenter()
    }
    @State private var player: AudioPlayer
    @State private var playerDelegate: AudioPlayerDelegate
    private var timer: SafeDispatchSourceTimer
    private let albums: [Model.Album]
    @Environment(MenuBarModel.self) var menuBarModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.appearsActive) var appearsActive
    @Environment(SearchModel.self) var searchModel
    @State private var selectedAlbum: Model.Album? = nil
    @State private var sliderWidth: CGFloat = 0
    @State private var songProgress: TimeInterval = 0
    @State private var scrollToAlbum: Model.Album? = nil
    @State private var scrollToSong: Model.Song? = nil
    @AppStorage("volume") var volume: Double = 0.1
    let pool: DatabasePool

    var body: some View {
        @Bindable var model = self.searchModel
        NavigationSplitView {
            AlbumListView(
                albums: albums,
                selectedAlbum: $selectedAlbum,
                currentSong: self.$playerDelegate.currentSong,
                scrollTo: $scrollToAlbum,
                playAlbum: {
                    try! playerDelegate.playAlbum(player, album: $0)
                }
            )
            .frame(minWidth: 250, idealWidth: 300)
        } detail: {
            DetailView(isMain: selectedAlbum != nil) {
                TrackListView(
                    songs: try! pool.read {
                        try! Model.Song
                            .filter(
                                sql: "albumTitle = ? AND artistName = ?",
                                arguments: [
                                    selectedAlbum!.title,
                                    selectedAlbum!.artist,
                                ]
                            )
                            .order(
                                Column("discNumber"),
                                Column("trackNumber")
                            )
                            .fetchAll($0)
                    },
                    currentSong: $playerDelegate.currentSong,
                    scrollTo: $scrollToSong,
                    playbackState: playerDelegate.playbackState,
                    playSong: {
                        try! self.player.play($0.path)
                    }
                )
            } empty: {
                ContentUnavailableView(
                    "No album",
                    systemImage: "music.note",
                    description: Text("Select an album in the sidebar")
                )
            }
        }
        .debounce(
            $model.searchQuery,
            using: model.queryChannel,
            for: .seconds(0.33),
            action: {
                performSearch($0)
            }
        )
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: {
            sliderWidth = ($0.width - 250) * 0.5
        }
        .toolbar {
            ToolbarItemGroup(placement: .destructiveAction) {
                MediaControlView(
                    play: {
                        if playerDelegate.currentSong == nil {
                            try! playerDelegate.playNext(player)
                        } else {
                            player.resume()
                            try! player.play()
                        }
                    },
                    pause: {
                        player.pause()
                    },
                    backward: {
                        try! playerDelegate.playPrevious(player)
                    },
                    forward: {
                        try! playerDelegate.playNext(player)
                    },
                    playbackState: $playerDelegate.playbackState
                )
            }
            ToolbarItemGroup(placement: .status) {
                StatusView(
                    seekAction: {
                        player.seek(time: $0)
                    },
                    currentSong: self.$playerDelegate.currentSong,
                    songProgress: $songProgress,
                    clickAction: { song in
                        try! pool.read {
                            let album = try! Model.Album.filter(
                                sql: "artist = ? AND title = ?",
                                arguments: [song.artistName, song.albumTitle]
                            ).fetchOne($0)
                            let song = try! Model.Song.filter(key: [
                                "path": song.path
                            ]).fetchOne($0)
                            scrollToAlbum = album
                            scrollToSong = song
                        }
                    }
                )
                .frame(minWidth: sliderWidth)
            }
            ToolbarItemGroup(placement: .confirmationAction) {
                VolumeSliderView(volume: $volume)
                    .onChange(of: volume) {
                        try! self.player.setVolume(Float(volume))
                    }
                Button {
                    openWindow(id: "search")
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
                .help("Search")
                .keyboardShortcut("F", modifiers: .command)

            }
        }
        .onAppear {
            menuBarModel.player = self.player
            menuBarModel.playerDelegate = self.playerDelegate
            timer.timer.setEventHandler {
                if let time = self.player.time {
                    self.songProgress = time.currentTime
                }
            }
        }
        .onChange(of: playerDelegate.playbackState) {
            // Reduce CPU usage from rerendering and unecessarily checking the time
            if playerDelegate.playbackState == .playing && appearsActive {
                timer.resume()
            } else {
                timer.suspend()
            }
        }
        .onChange(of: appearsActive) {
            // Reduce CPU usage from rerendering the seekbar
            if appearsActive && playerDelegate.playbackState == .playing {
                timer.resume()
            } else {
                timer.suspend()
            }
        }
        .onChange(of: searchModel.selectedSong) {
            if let song = model.selectedSong {
                try! player.play(song.path)
                model.selectedSong = nil
            }
        }
        .onDisappear {
            menuBarModel.player = nil
            menuBarModel.playerDelegate = nil
            playerDelegate.currentSong = nil
            player.stop()
            timer.suspend()
        }
    }
    private func performSearch(_ query: String) {
        if query.isEmpty {
            return
        }
        let search = FTS5Pattern(matchingPhrase: query)
        self.searchModel.searchResult =
            try! pool.read {
                try! Model.Song
                    .fetchAll(
                        $0,
                        sql: #"""
                            SELECT s.rowid, s.*
                            FROM song s
                            JOIN songSearch sr on s.path = sr.path
                            WHERE songSearch MATCH ?
                            ORDER BY artistName COLLATE NOCASE, albumTitle COLLATE NOCASE, discNumber, trackNumber
                            """#,
                        arguments: [search]
                    )
            }
    }

    private func initCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { _ in
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { event in
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget(handler: { _ in
            return .success
        })

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget(handler: { _ in
            return .success
        })

        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget {
            print($0)
            return .success
        }
    }
}
