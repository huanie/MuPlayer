//
//  MuPlayerApp.swift
//  MuPlayer
//
//  Created by Huan Thieu Nguyen on 06.04.25.
//

import SFBAudioEngine
import SwiftUI

@main
struct MuPlayerApp: App {
    @Environment(\.openWindow) var openWindow
    @State var searchModel = SearchModel()
    @State var lastFM = LastFM()
    @State var isScanning = ScanProgress.none
    @State var errors: [MusicScanner.ScanError] = []
    @State var menuBarModel = MenuBarModel()
    var body: some Scene {
        Window(Globals.APP_NAME, id: "main") {
            ContentView(
                isScanning: $isScanning,
                errors: $errors,
                lastFM: lastFM
            )
            .environment(menuBarModel)
            .environment(searchModel)
        }
        .windowToolbarStyle(
            UnifiedWindowToolbarStyle(showsTitle: false)
        )
        .commands {
            let isScanning = isScanning == .scanning || isScanning == .error
            CommandGroup(after: .pasteboard) {
                Button("Find") {
                    openWindow(id: "search")
                }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(isScanning)
            }
            CommandMenu("Playback") {
                Button("Random Album") {
                    if let x = try! menuBarModel.playerDelegate?
                        .randomStartOfAlbum()
                    {
                        menuBarModel.player?.clearQueue()
                        try! menuBarModel.player?.play(x.path)
                        try! menuBarModel.player?.play()
                    }
                }
                .disabled(isScanning)
                .keyboardShortcut("r", modifiers: .command)
                if let delegate = menuBarModel.playerDelegate {
                    @Bindable var x = delegate
                    Picker(
                        selection: $x.mode,
                        label: Text("Shuffle")
                    ) {
                        Text("Off").tag(
                            AudioPlayerDelegate.PlaybackMode.sequential
                        )
                        Text("Album").tag(
                            AudioPlayerDelegate.PlaybackMode.albumShuffle
                        )
                        Text("Track").tag(
                            AudioPlayerDelegate.PlaybackMode.shuffle
                        )
                    }
                    .disabled(isScanning)
                }
            }
        }

        Window("Search", id: "search") {
            SearchView(searchModel: $searchModel).onDisappear {
                searchModel.reset()
            }
        }

        Settings {
            SettingsView(
                lastFM: lastFM,
                isScanning: $isScanning,
                scanErrors: $errors
            )
        }

        .windowLevel(.floating)
        .windowStyle(.hiddenTitleBar)
    }
}
