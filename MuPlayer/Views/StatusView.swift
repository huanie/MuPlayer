//
//  StatusView.swift
//  MuPlayer
//
//  Created by Huan Thieu Nguyen on 17.04.25.
//

import SwiftUI

struct StatusView: View {
    let seekAction: (TimeInterval) -> Void
    @Binding var currentSong: Model.Song?
    @Binding var songProgress: TimeInterval
    @State var hovered = false
    @State var pressed = false
    let clickAction: (Model.Song) -> Void
    var body: some View {
        VStack(spacing: 0) {
            if let song = currentSong {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).foregroundStyle(
                        (hovered || pressed)
                            ? (pressed
                                ? Color.gray.opacity(0.35)
                                : Color.gray.opacity(0.2))
                            : .clear
                    )
                    .animation(.easeInOut(duration: 0.2), value: hovered)
                    .animation(.easeInOut(duration: 0.1), value: pressed)

                    VStack(alignment: .center, spacing: 0) {
                        VStack(spacing: 0) {
                            Text(song.songTitle)
                                .foregroundStyle(.primary)
                                .allowsTightening(true)
                                .lineLimit(1)
                            Text(
                                "\(song.artistName) \u{2013} \(song.albumTitle)"
                            )
                            .allowsTightening(true)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                        }

                        SeekSlider(
                            seekAction: seekAction,
                            songDuration: song.duration,
                            songProgress: $songProgress
                        )
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            pressed = true
                            clickAction(currentSong!)
                        }
                        .onEnded { _ in
                            pressed = false
                        }

                )
                .lineLimit(1)
                .allowsTightening(true)
                .onHover {
                    hovered = $0
                }
            } else {
                Text(Globals.APP_NAME).foregroundStyle(.primary)
            }
        }
    }
}
