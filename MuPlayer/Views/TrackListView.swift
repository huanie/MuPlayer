//
//  TrackListView.swift
//  MuPlayer
//
//  Created by Huan Thieu Nguyen on 12.04.25.
//

import SFBAudioEngine
import SwiftUI

struct TrackListView<AnyList: RandomAccessCollection<Model.Song>>: View {
    let songs: AnyList
    @State var selectedSong: Model.Song.ID?
    @Binding var currentSong: Model.Song?
    @Binding var scrollTo: Model.Song.ID?
    let playbackState: AudioPlayer.PlaybackState
    let playSong: (Model.Song.ID) -> Void
    var body: some View {
        VStack {
            SongCoverView(song: songs.first)
            ScrollViewReader { scrollReader in
                List(songs, selection: $selectedSong) { song in
                    TrackListRowView(
                        song: song,
                        playbackState: playbackState,
                        currentSong: currentSong,
                    )
                    .tag(song.id)
                }
                .onChange(of: scrollTo) {
                    guard let x = scrollTo else {
                        return
                    }
                    selectedSong = x
                    scrollReader.scrollTo(x, anchor: .center)
                    scrollTo = nil
                }
                // double click
                .contextMenu(
                    forSelectionType: Model.Song.ID.self,
                    menu: { _ in
                    }
                ) { x in
                    if let song = x.first {
                        playSong(song)
                    }
                }
            }
        }
    }
}

private struct TrackListRowView: View {
    let song: Model.Song
    var playbackState: AudioPlayer.PlaybackState
    var currentSong: Model.Song?
    var body: some View {
        HStack {
            Label {
                Text("\(song.discNumber).\(song.trackNumber)")
            } icon: {
                (playbackState == AudioPlayer.PlaybackState.playing
                    ? Image(systemName: "speaker.2.fill")
                    : Image(systemName: "speaker.fill"))
                    .opacity(
                        song == currentSong ? 1.0 : 0.0
                    )
            }

            Text(song.songTitle)
                .allowsTightening(true)
                .lineLimit(1)

            Spacer()

            Text(
                Duration
                    .seconds(song.duration)
                    .formatted(.time(pattern: .minuteSecond))
            )
            .padding(.trailing)
        }
        .font(.title3)
        .listRowSeparator(.hidden)
    }
}

private struct SongCoverView: View {
    let song: Model.Song?
    var body: some View {
        if let x = song,
            let image = loadImage(x)
        {
            image
                .resizable()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaledToFit()
                .padding()
        } else {
            ContentUnavailableView("No picture", systemImage: "music.note")
        }
    }
    private func loadImage(_ song: Model.Song) -> Image? {
        guard
            let file = try? AudioFile(
                readingPropertiesAndMetadataFrom: song.path
            ),
            let imageData = file.metadata.attachedPictures.first?.imageData,
            let nsImage = NSImage(data: imageData)
        else {
            return nil
        }
        return Image(nsImage: nsImage)
    }
}
