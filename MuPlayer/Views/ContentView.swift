//
//  ContentView.swift
//  MuPlayer
//
//  Created by Huan Thieu Nguyen on 06.04.25.
//

import GRDB
import SwiftUI

struct ContentView: View {
    @Binding var isScanning: ScanProgress
    @Binding var errors: [MusicScanner.ScanError]
    var lastFM: LastFM

    var body: some View {
        if !FileManager.default.fileExists(
            atPath: Globals.DATABASE_PATH.path(percentEncoded: false)
        ) && isScanning != .done {
            FolderSelectionView(
                isScanning: $isScanning,
                errors: $errors,
                scanFun: MusicScanner.scan
            )
        } else if isScanning == .error {
            VStack {
                List(errors) { err in
                    HStack {
                        Text(err.path.path(percentEncoded: false))
                        Text(err.message)
                    }
                }
                Button("Close") {
                    isScanning = .none
                }
            }
            .onDisappear {
                try! MusicScanner.clearDatabase()
            }
        } else if isScanning == .scanning {
            ProgressView {
                Text("Scanning")
            }.progressViewStyle(.circular)
                .padding()
        } else {
            MainView(
                try! DatabasePool(
                    path: Globals.DATABASE_PATH.path(percentEncoded: false)
                ),
                lastFM: lastFM
            )
        }
    }
}
