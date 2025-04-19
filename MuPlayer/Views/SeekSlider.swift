//
//  SeekSlider.swift
//  MuPlayer
//
//  Created by Huan Thieu Nguyen on 08.04.25.
//

import SwiftUI

private func formatTime(_ seconds: TimeInterval) -> String {
    return Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
}

struct SeekSlider: View {
    let seekAction: (TimeInterval) -> Void
    let songDuration: TimeInterval
    @Binding var songProgress: TimeInterval
    @State private var sliderProgress: TimeInterval = 0
    @State private var isEditing = false
    var body: some View {
        HStack {
            Text(formatTime(sliderProgress))
            Slider(
                value: self.$sliderProgress,
                in: 0...songDuration,
                onEditingChanged: {
                    // end of seek
                    if !($0) {
                        isEditing = false
                        songProgress = sliderProgress
                        seekAction(songProgress)
                    } else {
                        isEditing = true
                    }
                }
            )
            .controlSize(.mini)
            .onChange(of: songProgress) {
                if !isEditing {
                    sliderProgress = songProgress
                }
            }
            Text(formatTime(songDuration))
        }
    }
}
