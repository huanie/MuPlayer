import AppKit
import GRDB
import MediaPlayer
import MusicPlayerFFI

@MainActor
private var commandCenterInitialized = false

/// Pass a path
public func albumArt(for path: borrowing String) -> NSImage? {
    var size: uintptr_t = 0
    guard let bytes = album_cover_get(path, &size) else {
        return nil
    }

    return NSImage(
        data: Data(
            bytesNoCopy: bytes,
            count: Int(size),
            deallocator: .custom { album_cover_free($0, UInt($1)) }
        )
    )
}

@MainActor
public func initCommandCenter(_ mpv: AudioPlayer) {
    if commandCenterInitialized {
        return
    }
    commandCenterInitialized = true
    let commandCenter = MPRemoteCommandCenter.shared()
    commandCenter.playCommand.isEnabled = true
    commandCenter.pauseCommand.isEnabled = true
    commandCenter.nextTrackCommand.isEnabled = true
    commandCenter.nextTrackCommand.addTarget { _ in
        mpv.playNext()
        return .success
    }
    commandCenter.previousTrackCommand.isEnabled = true
    commandCenter.previousTrackCommand.addTarget { event in
        mpv.playPrevious()
        return .success
    }
    commandCenter.pauseCommand.addTarget(handler: { _ in
        mpv.pause()
        return .success
    })
    commandCenter.playCommand.addTarget(handler: { _ in
        mpv.unpause()
        return .success
    })
    commandCenter.changePlaybackPositionCommand.addTarget {
        event in
        if let timeEvent = event as? MPChangePlaybackPositionCommandEvent {
            mpv.seekAbsolute(timeEvent.positionTime)
            return .success
        } else {
            return .commandFailed
        }
    }
    commandCenter.changePlaybackPositionCommand.isEnabled = true
}

public func updateTime(_ time: Int64) {
    let nowPlaying = MPNowPlayingInfoCenter.default()
    nowPlaying.nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = NSNumber(
        value: time
    )
}

public func nowPlayingPlayPause(_ paused: Bool, progress: Int64) {
    let nowPlaying = MPNowPlayingInfoCenter.default()
    if paused {
        nowPlaying.playbackState = .paused
    } else {
        nowPlaying.playbackState = .playing
    }
    nowPlaying.nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = NSNumber(
        value:
            progress
    )
}

public func updateNowPlaying(_ song: borrowing Song) {
    var nowPlayingInfo = [String: Any]()
    let nowPlaying = MPNowPlayingInfoCenter.default()
    nowPlayingInfo[MPMediaItemPropertyTitle] = song.songTitle
    nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = song.albumTitle
    nowPlayingInfo[MPMediaItemPropertyArtist] = song.artistName
    nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = NSNumber(
        value: song.duration)
    nowPlayingInfo[MPMediaItemPropertyDiscNumber] = song.discNumber
    nowPlayingInfo[MPMediaItemPropertyAlbumTrackNumber] = song.trackNumber
    let image = albumArt(for: song.path)
    if let image {
        nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(
            boundsSize: image.size
        ) { _ in
            return image
        }
    }
    nowPlaying.nowPlayingInfo = nowPlayingInfo

}
