//
//  TimerManager.swift
//  Golden Hour
//
//  Created by Sam on 9/9/20.
//  Copyright © 2020 Sam. All rights reserved.
//

import Foundation
protocol TimerManagerDelegate {
    func didUpdateTimer(_ h: Int, _ m: Int, _ s: Int)
    func didEndTimer()
}

class TimerManager {
    var delegate: TimerManagerDelegate?
    var countdownTimer: Timer!
    var remainingTime: Int = 0
    //    var totalTime: Int = 1
    //    var progressPercent: Int = 100
    
    func startTimer() {
        countdownTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateTime), userInfo: nil, repeats: true)
    }
    
    @objc func updateTime() {
        let hour: Int = (remainingTime / 3600)
        let min: Int = (remainingTime / 60) % 60
        let sec: Int = remainingTime % 60
        self.delegate?.didUpdateTimer(hour, min, sec)
                
        if remainingTime > 0 { remainingTime -= 1 }
        else { endTimer() }
    }
    
    func endTimer() {
        countdownTimer.invalidate()
        self.delegate?.didEndTimer()        
    }
    
}
