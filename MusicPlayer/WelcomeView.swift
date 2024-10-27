import MusicPlayerFFI
import SwiftUI

//
//  WelcomeView.swift
//  MusicPlayer
//
//  Created by Huan Nguyen on 23.07.24.
//
struct WelcomeView: View {
  @Binding var isScanning: ScanProgress
  var body: some View {
    if isScanning == .Scanning {
      ProgressView(label: {
        Text("Scanning")
          .font(.caption)
          .foregroundColor(.secondary)
      })
      .progressViewStyle(.circular).padding()
    } else {
      FolderView(scan_directory, isScanning: self.$isScanning)
    }
  }
}
