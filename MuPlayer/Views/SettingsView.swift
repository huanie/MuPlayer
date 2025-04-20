//
//  SettingsView.swift
//  MuPlayer
//
//  Created by Huan Thieu Nguyen on 19.04.25.
//

import GRDB
import SwiftUI

struct SettingsView: View {
    let lastFM: LastFM
    @Binding var isScanning: ScanProgress
    @Binding var scanErrors: [MusicScanner.ScanError]
    var body: some View {
        TabView {
            Tab {
                LastFMCredentialsView(lastFM: lastFM)
            } label: {
                Label("last.fm", image: "lastfm")
            }
            if FileManager.default
                .fileExists(
                    atPath: Globals.DATABASE_PATH.path(percentEncoded: false)
                )
            {
                Tab("Library", systemImage: "folder") {
                    FolderSelectionView(
                        isScanning: $isScanning,
                        directories: Set(
                            try! DatabaseQueue(
                                path: Globals.DATABASE_PATH.path(
                                    percentEncoded: false
                                )
                            ).read {
                                try String
                                    .fetchAll(
                                        $0,
                                        sql: #"""
                                            SELECT path
                                            FROM directory
                                            """#
                                    ).map { $0.removingPercentEncoding! }
                            }
                        ),
                        errors: $scanErrors,
                        scanFun: MusicScanner.rescan
                    )
                }
            }
        }
        .frame(minWidth: 450, minHeight: 250)
    }
}

struct LastFMCredentialsView: View {
    let lastFM: LastFM
    enum LoginState { case none, ok, error }
    @State var username: String
    @State var password: String
    @State var loginState = LoginState.none
    @State var showError = false
    @State var errorMessage: String = ""
    init(lastFM: LastFM) {
        self.lastFM = lastFM
        self.username = lastFM.username
        self.password = lastFM.password
    }
    var body: some View {
        if loginState == .ok {
            Text("Logged in")
        }
        Form {
            Section {
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .autocorrectionDisabled()

                SecureField("Password", text: $password)
                    .autocorrectionDisabled()
                    .textContentType(.password)
            }
            Section {
                Button("Login") {
                    lastFM
                        .authenticate(
                            username: username,
                            password: password,
                            errorCallback: { msg in
                                DispatchQueue.main.async {
                                    loginState = .error
                                    showError = true
                                    errorMessage = msg
                                }
                            },
                            successCallback: { key in
                                DispatchQueue.main.async {
                                    loginState = .ok
                                    lastFM.apiSession = key
                                    lastFM.isVerified = .verified
                                    lastFM.username = username
                                    lastFM.password = password
                                }
                            }
                        )
                }
                .keyboardShortcut(.defaultAction)
                .disabled(username.isEmpty || password.isEmpty)
            }
        }
        .alert(
            "lastFM login error",
            isPresented: $showError
        ) {

        } message: {
            Text(errorMessage)
        }
        .padding()
    }
}
