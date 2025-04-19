//
//  MenubarModel.swift
//  MuPlayer
//
//  Created by Huan Thieu Nguyen on 19.04.25.
//

import Foundation
import SFBAudioEngine
import SwiftUI

@Observable
class MenuBarModel {
    var playerDelegate: AudioPlayerDelegate? = nil
    @ObservationIgnored var player: AudioPlayer? = nil
}
