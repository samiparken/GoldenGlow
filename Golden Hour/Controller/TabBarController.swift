//
//  TabBarController.swift
//  Golden Hour
//
//  Created by Sam on 9/21/20.
//  Copyright © 2020 Sam. All rights reserved.
//

import UIKit

// Keys for Notification & Observers
let CityNameUpdateNotificationKey = "co.samiparken.updateCityName"
let BGImageUpdateNotificationKey = "co.samiparken.updateBGImage"

class TabBarController: UITabBarController {
    
    static let singletonTabBar = TabBarController()
    
    // for Sharing Data Btw View Controllers
    var BGImageViewName: String = ""
    var currentLocation: String = ""

    // Managers
    var sunPositionManager = SunPositionManager()
    var locationManager = LocationManager()
    var timerManager = TimerManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Delegates
        sunPositionManager.delegate = self
        locationManager.delegate = self
        timerManager.delegate = self
        
        
    }
}


//MARK: - SunPositionManagerDelegate
extension TabBarController: SunPositionManagerDelegate {
    
    // + Update According to Sun's Altitude
    // -2:Night / -1:Golden- / 1:Golden+ / 2:Day
    func didUpdateStatus(_ status: Int) {
        switch status {
        case -2: BGImageViewName = "BG_Night"
        case -1: BGImageViewName = "BG_Golden-"
        case 1:  BGImageViewName = "BG_Golden+"
        case 2:  BGImageViewName = "BG_Day"
        default: BGImageViewName = "BG_Start"
        }
        let keyName = Notification.Name(rawValue: BGImageUpdateNotificationKey)
        NotificationCenter.default.post(name: keyName, object: nil)

    }
    
    func didUpdateRemainingTime(_ remain: Int, _ total: Int) {
        // Try Timer
        timerManager.remainingTime = remain
        timerManager.totalTime = total
        timerManager.startTimer()
    }
    
    func didUpdateGoldenHour(_ next: [Date]) {
        let start = next[0]
        let end = next[1]
        
//        centerTopLabel.text = "Lasts for"
        let last = Int( end.timeIntervalSince1970 - start.timeIntervalSince1970 )
        let lastMin: Int = last / 60
        let lastSec: Int = last % 60
//        timeDigitMin.text = String(format: "%02d", lastMin)
//        timeSaperator.text = ":"
//        timeDigitSec.text = String(format: "%02d", lastSec)
        
        let calendar = Calendar.current
        let hour1 = calendar.component(.hour, from: start)
        let minute1 = calendar.component(.minute, from: start)
//        page2.setGoldenHourTimeLabel(String(format: "%02d:%02d", hour1, minute1))
        
        let hour2 = calendar.component(.hour, from: end)
        let minute2 = calendar.component(.minute, from: end)
//        page2.setEndTimeLabel(String(format: "%02d:%02d", hour2, minute2))

    }
    
    func didUpdateSunsetTime(_ sunset: Date) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: sunset)
        let minute = calendar.component(.minute, from: sunset)
//        page2.setSunsetMode()
//        page2.setSetriseTimelabel(String(format: "%02d:%02d", hour, minute))
        
    }
    
    func didUpdateSunriseTime(_ sunrise: Date) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: sunrise)
        let minute = calendar.component(.minute, from: sunrise)
//        page2.setSunriseMode()
//        page2.setSetriseTimelabel(String(format: "%02d:%02d", hour, minute))
    }
    
}

//MARK: - LocationManagerDelegate
extension TabBarController: LocationManagerDelegate {
    
    func didUpdateLocation(_ locationData: [Double]) {
        sunPositionManager.currentData.Longitude = locationData[0]
        sunPositionManager.currentData.Latitude = locationData[1]
        
        // Start Calculating
        if let _ = sunPositionManager.currentData.SunAltitudeChange {}
        else { sunPositionManager.startSunPositionSystem() }
    }
    
    func didUpdateCityName(_ cityname: String) {
        currentLocation = cityname
        
        // Post Notification & Trigger Updates
        let keyName = Notification.Name(rawValue: CityNameUpdateNotificationKey)
        NotificationCenter.default.post(name: keyName, object: nil)
        
    }
}

//MARK: - TimerManagerDelegate
extension TabBarController: TimerManagerDelegate {
    
    func didUpdateTimer(_ min: Int, _ sec: Int) {
        let minString: String = String(format: "%02d", min)
        let secString: String = String(format: "%02d", sec)
        
//        timeDigitMin.text = minString
//        timeSaperator.text = ":"
//        timeDigitSec.text = secString
        
        // update SunAltitude every 5 seconds
        if (sec % 5 == 0)
        {
            sunPositionManager.updateCurrentAltitude()
            let sunAltitude = sunPositionManager.getCurrentAltitude()
            print("SunAltitude: \(String(format: "%2.2f", sunAltitude))")
        }
    }
        
    func didEndTimer() {
        sunPositionManager.updateScreen()
    }
}