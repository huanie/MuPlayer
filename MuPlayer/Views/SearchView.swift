//
//  SearchView.swift
//  MuPlayer
//
//  Created by Huan Thieu Nguyen on 18.04.25.
//

import SFBAudioEngine
import SwiftUI

struct SearchView: View {
    @Environment(\.appearsActive) var appearsActive
    @Environment(\.dismiss) var dismiss
    @FocusState private var searchFocused: Bool
    @Binding var searchModel: SearchModel
    @State var selected: Model.Song? = nil
    @FocusState private var listFocused: Bool
    var body: some View {
        VStack {
            TextField("Search", text: $searchModel.searchQuery)
                .task {
                    await searchModel.queryChannel.send(searchModel.searchQuery)
                }
                .onSubmit {
                    guard let song = searchModel.searchResult.first else {
                        return
                    }
                    searchFocused = false
                    listFocused = true
                    selected = song
                }
                .onAppear {
                    listFocused = false
                    searchFocused = true
                }
                .onKeyPress(.downArrow) {
                    guard let song = searchModel.searchResult.first else {
                        return .ignored
                    }
                    searchFocused = false
                    listFocused = true
                    selected = song
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    guard let song = searchModel.searchResult.last else {
                        return .ignored
                    }
                    searchFocused = false
                    listFocused = true
                    selected = song
                    return .handled
                }
                .focused($searchFocused)
            ScrollViewReader { scrollReader in
                GeometryReader { geometry in
                    List(searchModel.searchResult, selection: $selected) {
                        song in
                        HStack {
                            Text("\(song.discNumber).\(song.trackNumber)")
                                .frame(
                                    width: 25,
                                    alignment: .leading
                                )
                            VStack(alignment: .leading, spacing: 3) {
                                Text(song.albumTitle)
                                    .foregroundStyle(.primary)
                                    .frame(alignment: .leading)
                                Text(song.artistName)
                                    .foregroundStyle(.secondary)
                                    .frame(alignment: .leading)
                            }
                            .frame(
                                width: geometry.size.width / 4,
                                alignment: .leading
                            )
                            .padding(.horizontal)

                            Text(song.songTitle)
                                .frame(minWidth: 160, alignment: .leading)
                                .padding(.horizontal)

                            Spacer()

                            Text(
                                Duration
                                    .seconds(song.duration)
                                    .formatted(.time(pattern: .minuteSecond))
                            )
                        }
                        .font(.title3)
                        .lineLimit(1)
                        .allowsTightening(true)
                        .tag(song)
                    }
                    .onChange(of: selected) {
                        scrollReader.scrollTo(selected)
                    }
                    .focused($listFocused)
                    .contextMenu(
                        forSelectionType: Model.Song.self,
                        menu: { _ in
                        }
                    ) { x in
                        if let song = x.first {
                            searchModel.selectedSong = song
                            dismiss()
                        }
                    }
                }
            }
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Search")
        .onChange(of: appearsActive) {
            if !appearsActive {
                dismiss()
            }
        }
    }
}
