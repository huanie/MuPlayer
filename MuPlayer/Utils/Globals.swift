//
//  Globals.swift
//  MuPlayer
//
//  Created by Huan Thieu Nguyen on 06.04.25.
//

import Foundation

struct Globals {
    private init() {}

    static let APP_NAME = "MuPlayer"
    
    static let DATABASE_PATH = try! FileManager.default.url(
        for: .cachesDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: false
    )
    .appending(components: String(describing: APP_NAME), "data")
    .appendingPathExtension(
        "db"
    )
    
    static let AUDIO_EXTENSIONS = Set([
        "flac",
        "mp3",
        "ogg",
        "wav",
        "m4a",
        "vorbis",
        "opus",
    ])
    
    struct Defaults {
        private init() {}
        static let NO_DISC = 1
        static let NO_TRACK_NR = 1
        static let NO_ALBUM = "Unknown Album"
        static let NO_ARTIST = "Unknown Artist"
        static let NO_TITLE = "Unknown Title"
    }
}
