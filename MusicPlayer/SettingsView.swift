//
//  Settings.swift
//  MusicPlayer
//
//  Created by Huan Nguyen on 10.10.24.
//

import SwiftUI
import MusicPlayerFFI

struct LastFMCredentialsView: View {
    @AppStorage("LastFMUsername") var username = ""
    @AppStorage("LastFMPassword") var password = ""
    @State var error: String = ""
    enum VerificationState: Int {
        case Nothing, Running, Error, AlreadyVerified
    }
    @AppStorage("LastFMVerificationState") var verifying = VerificationState
        .Nothing
    var body: some View {
        VStack {
            TextField("Username", text: $username)
            SecureField("Password", text: $password)
            Button(action: {
                verifying = .Running
                LastFM.authenticate(
                    username: username, password: password,
                    errorCallback: { err in
                        Task { @MainActor in
                            error = err
                            verifying = .Error
                        }
                    },
                    successCallback: { session in
                        Task { @MainActor in
                            Storage.shared.apiSession = session
                            verifying = .AlreadyVerified
                        }
                    })
            }) {
                Text("Sign in")
            }.keyboardShortcut(.defaultAction)
            switch verifying {
            case .Nothing:
                EmptyView()
            case .Running:
                ProgressView()
            case .Error:
                Text("Error").foregroundStyle(.red)
                Text(error)
            case .AlreadyVerified:
                Text("Already verified")
            }
        }
        .padding()
    }
}

struct SettingsView: View {
    @Binding var isScanning: ScanProgress
    var body: some View {
        TabView {
            Tab(
                content: {
                    LastFMCredentialsView()
                },
                label: {
                    Label("LastFM", image: "lastfm")
                })
            if FileManager.default.fileExists(atPath: databasePath) {
                Tab("Library", systemImage: "folder") {
                    FolderView( rescan,
                        isScanning: self.$isScanning,
                        directories: Set(try! Globals.database.read {
                                try! String.fetchAll($0, sql: "SELECT path FROM directory")
                        })
                    )
                }
            }
        }
        .frame(width: 450, height: 250)
    }
}
