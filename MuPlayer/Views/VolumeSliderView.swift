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
    @State var hovered = false
    @State var pressed = false
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).foregroundStyle(
                (hovered || pressed)
                    ? (pressed
                        ? Color.gray.opacity(0.35)
                        : Color.gray.opacity(0.2))
                    : .clear
            )
            .frame(maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.2), value: hovered)
            .animation(.easeInOut(duration: 0.1), value: pressed)
            
            Slider(value: $volume, in: 0...1) {
            } minimumValueLabel: {
                Image(systemName: "speaker.fill")
            } maximumValueLabel: {
                Image(systemName: "speaker.wave.3.fill")
            }
            .frame(minWidth: 100)
            .padding(.vertical)
        }
        .popover(isPresented: $fineEdit) {
            TextField("Volume", value: $volume, format: .percent)
        }
        .onHover {
            hovered = $0
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    pressed = true
                    fineEdit = true
                }
                .onEnded { _ in
                    pressed = false
                }

        )
        .frame(minWidth: 100, maxHeight: .infinity)
        .controlSize(.mini)

    }
}
