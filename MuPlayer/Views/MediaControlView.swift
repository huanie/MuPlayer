//
//  MediaControlView.swift
//  MuPlayer
//
//  Created by Huan Thieu Nguyen on 17.04.25.
//

import SwiftUI
import SFBAudioEngine

struct MediaControlView: View {
    typealias F = () -> Void
    let play: F
    let pause: F
    let backward: F
    let forward: F

    @Binding var playbackState: AudioPlayer.PlaybackState
    var body: some View {
        Button {
            backward()
        } label: {
            Image(systemName: "backward.fill")
        }
        .keyboardShortcut(KeyboardShortcut(.leftArrow, modifiers: .control))
        .help("Backward")
        if playbackState == .playing {
            Button {
                pause()
            } label: {
                Image(systemName: "pause.fill")
            }.help("Pause")
        } else {
            Button {
                play()
            } label: {
                Image(systemName: "play.fill")
            }.help("Play")
        }
        Button {
            forward()
        } label: {
            Image(systemName: "forward.fill")
        }.help("Forward")
    }
}
