import SwiftUI

struct SeekSlider: View {
  @State var isSeeking = false
  @State var songProgress = 0.0
  var mpv: AudioPlayer
  var body: some View {
    HStack {
      Text(formatTime(UInt(self.mpv.progress)))
      Slider(
        value: self.$songProgress, in: 0...100,
        onEditingChanged: {
          if !($0) {
            self.mpv.seek(self.songProgress)
            isSeeking = false
          } else {
            isSeeking = true
          }
        }
      )
      .onChange(of: self.mpv.progress) {
        if !self.isSeeking {
          self.songProgress =
            (Double(self.mpv.progress) / Double(self.mpv.currentSong!.duration)) * 100
        }
      }
      .controlSize(.mini)
      Text(formatTime(self.mpv.currentSong!.duration))
    }
  }
}
