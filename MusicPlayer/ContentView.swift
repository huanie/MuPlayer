import AppKit
import GRDB
import SwiftUI

struct ContentView: View {
  var db: DatabaseQueue
  let mpv: AudioPlayer
  @AppStorage("volume") var volume: Double = 40.0
  @Environment(\.openWindow) private var openWindow

  init() {
    self.db = Globals.database
    self.mpv = Globals.mpv
  }
  var body: some View {
    GeometryReader { geometry in
      AlbumSongSplitView(db: self.db, mpv: self.mpv)
        .onAppear {
          initCommandCenter(self.mpv)
          self.mpv.setVolume(UInt(self.volume))
        }
        .onChange(of: self.mpv.currentSong) {
          if let song = self.mpv.currentSong {
            updateNowPlaying(song)
            LastFM.updateNowPlaying(song)
          }
        }
        .onChange(of: self.mpv.paused) {
          nowPlayingPlayPause(
            self.mpv.paused,
            progress: self.mpv.progress
          )
        }
        .toolbar {
          ToolbarItemGroup(placement: .navigation) {
            Button(
              action: {
                if mpv.currentSong == nil {
                  mpv.playRandomStartOfAlbum()
                } else {
                  mpv.playPrevious()
                }
              },
              label: {
                Image(systemName: "backward.fill")
              })

            if self.mpv.paused {
              Button(
                action: {
                  if mpv.currentSong == nil {
                    mpv.playRandomStartOfAlbum()
                  }
                  self.mpv.unpause()
                },
                label: {
                  Image(systemName: "play.fill")
                })
            } else {
              Button(
                action: {
                  self.mpv.pause()
                },
                label: {
                  Image(systemName: "pause.fill")
                })
            }
            Button(
              action: {
                if mpv.currentSong == nil {
                  mpv.playRandomStartOfAlbum()
                } else {
                  mpv.playNext()
                }
              },
              label: {
                Image(systemName: "forward.fill")
              })

          }
          ToolbarItemGroup(placement: .principal) {
            VStack(spacing: 0) {
              if let song = mpv.currentSong {
                Text("\(song.songTitle)").foregroundStyle(
                  .primary)
                Text("\(song.albumArtist) - \(song.albumTitle)")
                  .font(.caption).foregroundStyle(
                    .gray)
                SeekSlider(mpv: self.mpv)
              } else {
                Text("Music Player").foregroundStyle(.primary)
              }
            }.frame(width: (geometry.size.width - 150) * 0.5)
          }
          ToolbarItemGroup(placement: .automatic) {
            Slider(value: $volume, in: 0...100) {
            } minimumValueLabel: {
              Image(systemName: "speaker.fill")
            } maximumValueLabel: {
              Image(systemName: "speaker.wave.3.fill")
            } onEditingChanged: {
              if !($0) {
                self.mpv.setVolume(UInt(volume))
              }
            }
            .frame(minWidth: 100).controlSize(.mini)
            Spacer()
            Button(
              action: {
                openWindow(id: "searchWindow")
              },
              label: {
                Image(systemName: "magnifyingglass")
              }
            )
          }
        }
    }
  }
}
