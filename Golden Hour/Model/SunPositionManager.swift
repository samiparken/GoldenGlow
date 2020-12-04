//
//  SunPositionManager.swift
//  Golden Hour
//
//  Created by Sam on 9/2/20.
//  Copyright © 2020 Sam. All rights reserved.
//

import Foundation
import CoreLocation

protocol SunPositionManagerDelegate {
    func didUpdateCurrentState(_ sunAngle: Double, _ isUp: Bool)
    func didUpdateCurrentScan(from: Date, to: Date, _ nowState: Int, _ nextState: Int)
    func didUpdateTodayScan(_ today: [SunTimestamp])
}

class SunPositionManager {
    var delegate: SunPositionManagerDelegate?
    var currentData = CurrentData()
    
    func isAboveEvent() -> Bool {
        let sun = currentData.SunAltitude!
        return isAboveEvent(sun)
    }
    func isAboveEvent(_ sun: Double) -> Bool {
        return sun > UPPERLIMIT ? true : false
    }
    
    func isLowSun() -> Bool {
        let sun = currentData.SunAltitude!
        return isLowSun(sun)
    }
    func isLowSun(_ sun: Double) -> Bool {
        return ( UPPERGOLDEN <= sun ) && ( sun <= UPPERLIMIT ) ? true : false
    }
    
    // GoldenHour+
    func isGoldenHourP() -> Bool {
        let sun = currentData.SunAltitude!
        return isGoldenHourP(sun)
    }
    func isGoldenHourP(_ sun: Double) -> Bool {
        return ( UPPERSETRISE <= sun ) && ( sun <= UPPERGOLDEN ) ? true : false
    }
    
    func isSetRise() -> Bool {
        let sun = currentData.SunAltitude!
        return isSetRise(sun)
    }
    func isSetRise(_ sun: Double) -> Bool {
        return ( LOWERSETRISE <= sun ) && ( sun <= UPPERSETRISE ) ? true : false
    }
    
    // GoldenHour-
    func isGoldenHourM() -> Bool {
        let sun = currentData.SunAltitude!
        return isGoldenHourM(sun)
    }
    func isGoldenHourM(_ sun: Double) -> Bool {
        return ( LOWERGOLDEN <= sun ) && ( sun <= LOWERSETRISE ) ? true : false
    }
    
    func isBlueHour() -> Bool {
        let sun = currentData.SunAltitude!
        return isBlueHour(sun)
    }
    func isBlueHour(_ sun: Double) -> Bool {
        return ( LOWERLIMIT <= sun ) && ( sun <= LOWERGOLDEN ) ? true : false
    }
    
    func isBelowEvent() -> Bool {
        let sun = currentData.SunAltitude!
        return isBelowEvent(sun)
    }
    func isBelowEvent(_ sun: Double) -> Bool {
        return sun < LOWERLIMIT ? true : false
    }

    
    func isAboveHorizon() -> Bool {
        let sun = currentData.SunAltitude!
        return isAboveHorizon(sun)
    }
    func isAboveHorizon(_ sun: Double) -> Bool {
        return sun > 0 ? true : false
    }

    
    func isSunGoingUp() -> Bool {
        let change = currentData.SunAltitudeChange!
        return change > 0 ? true : false
    }
    
    func getAltitude() -> Double {
        if let sun = currentData.SunAltitude { return sun }
        else { return 0 }
    }

    
    func getState(_ sunAngle: Double = INVALIDANGLE) -> Int
    {
        let inputAngle = sunAngle != INVALIDANGLE ? sunAngle : currentData.SunAltitude!
        
        if( isBelowEvent(inputAngle) ) { return NIGHTTIME }
        else if ( isBlueHour(inputAngle) ) { return BLUEHOUR }
        else if ( isGoldenHourM(inputAngle) ) { return GOLDENHOURM }
        else if ( isSetRise(inputAngle) ) { return SETRISE }
        else if ( isGoldenHourP(inputAngle) ) { return GOLDENHOURP }
        else if ( isLowSun(inputAngle) ) { return LOWSUN }
        else { return DAYTIME }
    }
    
    func getNextState() -> Int
    {
        let result = isSunGoingUp() ? getState() + 1 : getState() - 1
        if ( result > DAYTIME ) { return LOWSUN }
        else if ( result < NIGHTTIME ) {return BLUEHOUR }
        else { return result }
    }
    
    func updateCurrentAltitude()
    {
        // Get current date & time
        let now = Date()
        let GMT = currentData.GMT
        if let lon = currentData.Longitude
        {
            let lat = currentData.Latitude!
            let sun = SunPositionModel(now, GMT, longitude: lon, latitude: lat)
            sun.spa_calculate()
            
            if let sunAltitude = currentData.SunAltitude //if not first try
            {
                // Save Rate of Sun Altitude Change
                currentData.SunAltitudeChange = sun.declination - sunAltitude
            }
            
            // Save currentSunAltitude
            currentData.SunAltitude = sun.declination
        }
    }
    
    func startSunPositionSystem()
    {
        // Get current date & time
        let now = Date()
        let now2 = Date() + 10
        let GMT = currentData.GMT
        
        // First Update Sun Altitude & Change
        if let lon = currentData.Longitude
        {
            let lat = currentData.Latitude!
            let sun1 = SunPositionModel(now, GMT, longitude: lon, latitude: lat)
            let sun2 = SunPositionModel(now2, GMT, longitude: lon, latitude: lat)
            sun1.spa_calculate()
            sun2.spa_calculate()
            
            currentData.SunAltitude = sun1.declination
            currentData.SunAltitudeChange = sun2.declination - sun1.declination
        }
        updateScreen()
    }
    
    func updateScreen()
    {
        // BG & morning/evening
        self.delegate?.didUpdateCurrentState(currentData.SunAltitude!, isSunGoingUp())
                
        // Current Scan -> SkyView1 (Timer & Current State)
        let nowRange: [Date] = currentScan()
        let nowState = getState()
        let nowNext = getNextState()
        self.delegate?.didUpdateCurrentScan(from: nowRange[0], to: nowRange[1], nowState, nowNext)

        // Today Scan -> SkyView2
        let today = Date()
        let calendar = Calendar.current
        let yyyy = String(calendar.component(.year, from: today))
        let mm = String(calendar.component(.month, from: today))
        let dd = String(calendar.component(.day, from: today))

        let todayScan: [SunTimestamp] = dailyScan(yyyy,mm,dd)
        self.delegate?.didUpdateTodayScan(todayScan)
        
    }
    
    
    func currentScan() -> [Date] {

        var result: [Date] = []     // result.count == 2

        let GMT = currentData.GMT
        let lon = currentData.Longitude!
        let lat = currentData.Latitude!

        let now = Date()
        let scanForwardLimit = now + 43200 // within 12h
        let scanBackwardLimit = now - 43200 // within 12h
        
        let sun = SunPositionModel(now, GMT, longitude: lon, latitude: lat)
        sun.spa_calculate()
        let currentAngle = sun.declination
        let currentState = getState(currentAngle)

        // Backward Scanning
        while ( (result.count == 0) && (scanBackwardLimit < sun.date) )
        {
            sun.spa_calculate()
            let sunAngle = sun.declination
            if ( currentState != getState(sunAngle) )
            {
                result.append(sun.date)
            }
            else {
                sun.date -= calculateTimeGap(sunAngle)   // decrease timestamp for scanning
            }
        }
        
        sun.setDate(now)
        
        // Forward Scanning
        while( (result.count == 1) && (sun.date < scanForwardLimit) )
        {
            sun.spa_calculate()
            let sunAngle = sun.declination
            if ( currentState != getState(sunAngle) )
            {
                result.append(sun.date)
            }
            else {
                sun.date += calculateTimeGap(sunAngle)   // increase timestamp for scanning
            }
        }
                
        return result
    }
    
    
    func dailyScan(_ year: String, _ month: String, _ day: String) -> [SunTimestamp] {
        
        var result: [SunTimestamp] = []

        let GMT = currentData.GMT
        let lon = currentData.Longitude!
        let lat = currentData.Latitude!

        let GMTString = String(format: "%+05d", GMT * 100)
        let inputDateString = year + "-" + month + "-" + day + " 00:00:00  " + GMTString
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"  //ex) 2020-03-13 13:37:00 +0100
        let inputDate = dateFormatter.date(from: inputDateString)
        let scanLimitDate = inputDate! + 86400 // within 24h
        
        let sun = SunPositionModel(inputDate!, GMT, longitude: lon, latitude: lat)
        sun.spa_calculate()
        var currentState = getState(sun.declination)
        sun.date += calculateTimeGap(sun.declination)   // increase timestamp for scanning

        repeat {
            sun.spa_calculate()
            let sunAngle = sun.declination
            let newState = getState(sunAngle)
            if ( currentState != newState )
            {
                let newTimestamp = SunTimestamp(time: sun.date, from: currentState, to: newState)
                result.append(newTimestamp)
                currentState = newState
            }
            sun.date += calculateTimeGap(sunAngle)   // increase timestamp for scanning
            print("\(year)-\(month)-\(day), \(sunAngle)")
        } while( (sun.date < scanLimitDate) && ( result.count < 12 ) )

        return result
    }
    
    // Scan TargetDate & return TimestampData[]
    func dailyScan2(_ year: String, _ month: String, _ day: String, _ lon: Double,_ lat: Double) {
        
        var DLSOffset: Double = 0.0
        
        let loc = CLLocation.init(latitude: lat, longitude: lon);
        let coder = CLGeocoder();
        coder.reverseGeocodeLocation(loc) { [self] (placemarks, error) in
            let place = placemarks?.last;
            let GMT = Double((place?.timeZone?.secondsFromGMT())!) / 3600  // 2.0
            
            let GMTString = String(format: "%+05d", GMT * 100)     // +0200
            let inputDateString = year + "-" + month + "-" + day + " 00:00:00  " + GMTString
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"  //ex) 2020-03-13 00:00:00 +0200
            var inputDate = dateFormatter.date(from: inputDateString)
            
            DLSOffset = Double(((place?.timeZone?.daylightSavingTimeOffset(for: inputDate!))!)) / 3600
            inputDate! -= DLSOffset*3600
                        
            let scanLimitDate = inputDate! + 86400 // within 24h
            let sun = SunPositionModel(inputDate!, GMT+DLSOffset, longitude: lon, latitude: lat)
            sun.spa_calculate()
            var currentState = self.getState(sun.declination)
            sun.date += self.calculateTimeGap(sun.declination)   // increase timestamp for scanning

//            repeat {
//                sun.spa_calculate()
//                let sunAngle = sun.declination
//                let newState = getState(sunAngle)
//                if ( currentState != newState )
//                {
//                    let newTimestamp = SunTimestamp(time: sun.date, from: currentState, to: newState)
//                    result.append(newTimestamp)
//                    currentState = newState
//                }
//                sun.date += calculateTimeGap(sunAngle)   // increase timestamp for scanning
//                print("\(year)-\(month)-\(day), \(sunAngle)")
//            } while( (sun.date < scanLimitDate) && ( result.count < 12 ) )
//
        }
    }
    
    func calculateTimeGap(_ sunAngle: Double) -> Double {
        let absAngle = abs(sunAngle)
        let temp = (absAngle - 10) * 240   // divide 15, multiply 3600
        return ( temp > 60 ) ? temp : 60
    }
        
    
}

// XOR operation for Bool
extension Bool {
    static func ^ (left: Bool, right: Bool) -> Bool {
        return left != right
    }
}
