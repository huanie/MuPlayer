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
    @State var searchModel = SearchModel()
    @State var lastFM = LastFM()
    @State var isScanning = ScanProgress.none
    @State var errors: [MusicScanner.ScanError] = []
    var body: some Scene {
        Window(Globals.APP_NAME, id: "main") {
            ContentView(
                isScanning: $isScanning,
                errors: $errors,
                lastFM: lastFM
            )
            .environment(searchModel)
        }
        .windowToolbarStyle(
            UnifiedWindowToolbarStyle(showsTitle: false)
        )

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
