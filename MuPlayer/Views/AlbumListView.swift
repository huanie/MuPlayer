//
//  AlbumView.swift
//  MuPlayer
//
//  Created by Huan Thieu Nguyen on 09.04.25.
//

import SwiftUI

struct AlbumListView<AnyList: RandomAccessCollection<Model.Album>>: View {
    let albums: AnyList
    @Binding var selectedAlbum: Model.Album.ID?
    @Binding var currentSong: Model.Song?
    @Binding var scrollTo: Model.Album.ID?
    let playAlbum: (Model.Album.ID) -> Void
    var body: some View {
        ScrollViewReader { scrollReader in
            List(albums, selection: $selectedAlbum) { album in
                Label {
                    VStack(alignment: .leading) {
                        Text(album.title)
                            .foregroundStyle(.primary)
                        Text(album.artist)
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                } icon: {
                    Image(systemName: "play.fill").opacity(
                        currentSong?.albumTitle == album.title
                            && currentSong?.artistName == album.artist
                            ? 1.0 : 0.0
                    )
                }
                .labelStyle(CentreAlignedLabelStyle())
                .padding(.vertical, 5)
                .tag(album.id)
                .lineLimit(1)
                .allowsTightening(true)
                .font(.title2)
                .listRowSeparator(.hidden)
            }
            .onChange(of: scrollTo) {
                guard let x = scrollTo else {
                    return
                }
                selectedAlbum = x
                scrollReader.scrollTo(x, anchor: .center)
                scrollTo = nil
            }
            // double click
            .contextMenu(
                forSelectionType: Model.Album.ID.self,
                menu: { _ in
                }
            ) { x in
                if let album = x.first {
                    playAlbum(album)
                }
            }
        }
    }
    private struct CentreAlignedLabelStyle: LabelStyle {
        func makeBody(configuration: Configuration) -> some View {
            HStack {
                configuration.icon
                configuration.title
            }
        }
    }
}
