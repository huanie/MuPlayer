import GRDB
import SwiftUI

@MainActor
struct Storage {
    @AppStorage("apiSession") var apiSession: String = ""
    static let shared = Storage()
    private init() {}
}
@MainActor
struct Globals {
    static let database: DatabaseQueue = {
        try! DatabaseQueue(path: databasePath)
    }()
    static let mpv: AudioPlayer = {
        AudioPlayer(db: database)
    }()

}
