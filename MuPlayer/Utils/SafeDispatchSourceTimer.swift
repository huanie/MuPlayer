//
//  SafeDispatchSourceTimer.swift
//  MuPlayer
//
//  Created by Huan Thieu Nguyen on 17.04.25.
//
import Foundation

class SafeDispatchSourceTimer {
    enum State { case running, paused }
    private var state = State.paused
    var timer: DispatchSourceTimer
    init(queue: DispatchQueue) {
        timer = DispatchSource.makeTimerSource(queue: queue)
    }
    func getState() -> State {
        state
    }
    func resume() {
        if state == .running {
          return
        }
        state = .running
        timer.resume()
    }
    
    func suspend() {
        if state == .paused {
            return
        }
        state = .paused
        timer.suspend()
    }
    deinit {
        timer.setEventHandler {}
        timer.cancel()
        resume()
    }
}
