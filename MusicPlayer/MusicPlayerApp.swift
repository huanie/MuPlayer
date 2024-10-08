import GRDB
import MediaPlayer
import SwiftUI

@main
struct MusicPlayerApp: App {
    @State var showMainView = false
    @Environment(\.openWindow) private var openWindow
    @AppStorage("mode") var mode: AudioPlayer.Mode = AudioPlayer.Mode.AlbumShuffle
    var body: some Scene {
        let showScan =
            !FileManager.default.fileExists(atPath: databasePath)
            && !showMainView
        WindowGroup {
            if showScan {
                WelcomeView(done: $showMainView)
            } else {
                ContentView().onChange(of: mode) {
                    Globals.mpv.setMode(mode)
                }.onAppear {                    
                    Globals.mpv.setMode(mode)
                }
                    .onDisappear {
                    NSApplication.shared.terminate(nil)
                }
            }
        }.windowToolbarStyle(
            UnifiedWindowToolbarStyle(showsTitle: false)
        )
        .commands {
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
                }.disabled(showScan)
                Picker(selection: $mode, label: Text("Shuffle")) {
                    Text("Off").tag(AudioPlayer.Mode.Sequential)
                    Text("Album").tag(AudioPlayer.Mode.AlbumShuffle)
                    Text("Track").tag(AudioPlayer.Mode.Shuffle)
                }
                .disabled(showScan)
            }
        }
        Settings {
            SettingsView()
        }
        Window("Search", id: "searchWindow") {
            if !showScan {
                SearchView()
            }
        }

    }
}
