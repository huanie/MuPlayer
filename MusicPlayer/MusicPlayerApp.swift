import GRDB
import MediaPlayer
import SwiftUI

@main
struct MusicPlayerApp: App {
    @State var showMainView: ScanProgress = .None
    @State var rescanning: ScanProgress = .None
    @Environment(\.openWindow) private var openWindow
    @AppStorage("mode") var mode: AudioPlayer.Mode = AudioPlayer.Mode
        .AlbumShuffle
    var body: some Scene {
        let showScan =
            !FileManager.default.fileExists(atPath: databasePath)
            && showMainView != .ScanComplete
        WindowGroup {
            if showScan {
                WelcomeView(isScanning: $showMainView)
            } else if rescanning == .Scanning {
                ProgressView(label: {
                    Text("Scanning")
                        .font(.caption)
                        .foregroundColor(.secondary)
                })
                .progressViewStyle(.circular)
                .padding()
            } else {
                ContentView().onChange(of: mode) {
                    Globals.mpv.setMode(mode)
                }.onAppear {
                    Globals.mpv.setMode(mode)
                }
            }
        }.windowToolbarStyle(
            UnifiedWindowToolbarStyle(showsTitle: false)
        )
        .commands {
            CommandGroup(after: .newItem) {
                Button("Rescan") {
                    self.rescanning = .Scanning
                    Task {
                        let paths = try! Globals.database.read {
                            try! String.fetchAll($0, sql: "SELECT path FROM directory")
                        }
                        for path in paths {
                            if 0 != rescan(path: path, dbFile: databasePath) {
                                preconditionFailure("Some error at rescanning")
                            }
                        }
                        DispatchQueue.main.async {
                            self.rescanning = .None
                        }
                    }
                    
                }.disabled(showScan && rescanning == .Scanning).keyboardShortcut(
                    "r", modifiers: .command
                )
            }
            CommandGroup(after: .pasteboard) {
                Button("Find") {
                    openWindow(id: "searchWindow")
                }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(showScan)
            }
            CommandMenu("Playback") {
                Button("Random Album") {
                    Globals.mpv.playRandomStartOfAlbum()
                }.disabled(showScan && rescanning == .Scanning)
                    .keyboardShortcut("r", modifiers: .option)
                Picker(selection: $mode, label: Text("Shuffle")) {
                    Text("Off").tag(AudioPlayer.Mode.Sequential)
                    Text("Album").tag(AudioPlayer.Mode.AlbumShuffle)
                    Text("Track").tag(AudioPlayer.Mode.Shuffle)
                }
                .disabled(showScan && rescanning == .Scanning)
            }
        }
        Settings {
            SettingsView(isScanning: self.$rescanning)
        }
        Window("Search", id: "searchWindow") {
            if !showScan {
                SearchView(rescan: self.$rescanning)
            }
        }

    }
}
