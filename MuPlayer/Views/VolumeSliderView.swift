//
//  VolumeSliderView.swift
//  MuPlayer
//
//  Created by Huan Thieu Nguyen on 17.04.25.
//

import SwiftUI

struct VolumeSliderView: View {
    @Binding var volume: Double
    @State var fineEdit = false
    var body: some View {
        Slider(value: $volume, in: 0...1) {
        } minimumValueLabel: {
            Image(systemName: "speaker.fill")
        } maximumValueLabel: {
            Image(systemName: "speaker.wave.3.fill")
        }
        .frame(minWidth: 100)
        .controlSize(.mini)        
    }
}
