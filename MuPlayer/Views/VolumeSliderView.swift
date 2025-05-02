//
//  VolumeSliderView.swift
//  MuPlayer
//
//  Created by Huan Thieu Nguyen on 17.04.25.
//

import SwiftUI

let maxVolume = 0.45

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
            
            Slider(value: $volume, in: 0...maxVolume) {
            } minimumValueLabel: {
                Image(systemName: "speaker.fill")
            } maximumValueLabel: {
                Image(systemName: "speaker.wave.3.fill")
            }
            .frame(minWidth: 100)
            .padding(.vertical)
        }
        .popover(isPresented: $fineEdit) {
            TextField("Volume", value: $volume, format: VolumeValueFormatter())
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

private struct VolumeValueFormatter: FormatStyle {
    func format(_ value: Double) -> String {
        let clampedValue = min(max(value, 0.0), maxVolume)
        let percentage = (clampedValue / maxVolume) * 100
        return String(format: "%.0f%%", percentage)
    }
}

private struct VolumeParseStrategy: ParseStrategy {
    func parse(_ value: String) throws -> Double {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "%", with: "")
        
        guard let number = Double(trimmed) else {
            throw FormatError.invalidValue
        }
        
        return min(max(number / 100.0 * maxVolume, 0.0), maxVolume)
    }
    
    enum FormatError: Error {
        case invalidValue
    }
}

extension VolumeValueFormatter: ParseableFormatStyle {
    var parseStrategy: VolumeParseStrategy {
        VolumeParseStrategy()
    }
}
