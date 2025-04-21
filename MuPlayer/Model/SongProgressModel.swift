//
//  SongProgressModel.swift
//  MuPlayer
//
//  Created by Huan Thieu Nguyen on 21.04.25.
//

import SwiftUI

/// This is necessary because the MPRemoteCommandCenter closures will otherwise capture a copy of songProgress which would be 0!
@Observable
class SongProgressModel {
    var current: TimeInterval = 0
}
