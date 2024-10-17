import GRDB
import SwiftUI

class SearchModel: ObservableObject {
    @Published var text: String
    @Published var debouncedText: String
    init() {
        self.text = ""
        self.debouncedText = ""
        $text.debounce(for: .seconds(0.75), scheduler: RunLoop.main).assign(
            to: &$debouncedText)
    }
}

struct SearchView: View {
    let mpv: AudioPlayer = Globals.mpv
    let database: DatabaseQueue = Globals.database
    @FocusState private var focusedField: Bool
    @StateObject var searchModel = SearchModel()
    @State var selected: Song.ID? = nil
    var body: some View {
        VStack {
            TextField("Search songs", text: $searchModel.text)
                .focused($focusedField)
            if !searchModel.debouncedText.isEmpty {
                let songs = try! database.read {
                    try! Song.fetchAll(
                        $0,
                        sql: """
                                  SELECT \(Song.columns(alias: "s"))
                                  FROM song_search
                                  INNER JOIN song s ON song_search.path = s.path
                                  WHERE song_search MATCH ?
                                  ORDER BY s.artist_name COLLATE NOCASE, s.album_title COLLATE NOCASE, s.disc_number, s.track_number
                            """,
                        arguments: [self.searchModel.debouncedText])
                }
                Table(songs, selection: $selected) {
                    TableColumn("") {
                        Image(systemName: "play.fill")
                            .opacity(
                                $0.rowid == self.mpv.currentSong?.rowid ? 1 : 0)
                    }.width(max: 10)
                    TableColumn("Nr") {
                        Text("\($0.discNumber).\($0.trackNumber)")
                    }.width(ideal: 1)
                    TableColumn("Artist", value: \.artistName)
                    TableColumn("Album", value: \.albumTitle)
                    TableColumn("Title", value: \.songTitle)
                    TableColumn("Duration") {
                        Text(formatTime($0.duration))
                    }
                }.onChange(of: self.selected) {
                    if let rowid = self.selected {
                        let song = try! database.read {
                            try! Song.fetchOne(
                                $0,
                                sql:
                                    "SELECT \(Song.columns()) FROM song WHERE rowid = ?",
                                arguments: [rowid])!
                        }
                        self.mpv.playSong(song)
                    }
                }
            }
        }.frame(
            maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
