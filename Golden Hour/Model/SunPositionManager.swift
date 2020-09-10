//
//  SunPositionManager.swift
//  Golden Hour
//
//  Created by Sam on 9/2/20.
//  Copyright © 2020 Sam. All rights reserved.
//

import Foundation

protocol SunPositionManagerDelegate {
    func didUpdateStatus(_ status: Int)   // -1:Night / 0:Golden / 1:Day
    func didUpdateGoldenHour(_ next: [Date])
    func didUpdateRemainingTime(_ time: Int)
    func didUpdateSunsetTime(_ sunset: Date)
    func didUpdateSunriseTime(_ sunrise: Date)
}

class SunPositionManager {
    var delegate: SunPositionManagerDelegate?
    var currentData = CurrentData()
    
    func isGoldenHour() -> Bool
    {
        let sun = currentData.SunAltitude!
        return ( LOWERLIMIT <= sun ) && ( sun <= UPPERLIMIT ) ? true : false
    }
    
    func isAboveHorizon() -> Bool
    {
        let sun = currentData.SunAltitude!
        return sun > 0 ? true : false
    }
    
    func isAboveGoldenHour() -> Bool
    {
        let sun = currentData.SunAltitude!
        return sun > UPPERLIMIT ? true : false
    }
    
    func isBelowGoldenHour() -> Bool
    {
        let sun = currentData.SunAltitude!
        return sun < LOWERLIMIT ? true : false
    }
    
    func isSunGoingUp() -> Bool
    {
        let change = currentData.SunAltitudeChange!
        return change > 0 ? true : false
    }
    
    func getCurrentAltitude() -> Double
    {
        if let sun = currentData.SunAltitude { return sun }
        else { return 0 }
    }
    
    func startSunPositionSystem()
    {
        // Get current date & time
        let now = Date()
        let now2 = Date() + 5
        let GMT = currentData.GMT
        
        // First Update Sun Altitude
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
        if( isGoldenHour() )
        {
            if ( isAboveHorizon() ) { self.delegate?.didUpdateStatus(1)}
            else { self.delegate?.didUpdateStatus(-1) }
            
            let now = Date()
            var thisTime: [Date] = []
            let startTime: Date = getStartTimeThisGoldenHour()
            let endTime: Date = getEndTimeThisGoldenHour()
            thisTime.append(startTime)
            thisTime.append(endTime)
            self.delegate?.didUpdateGoldenHour(thisTime)
            
            let remainingTime = Int(endTime.timeIntervalSince1970 - now.timeIntervalSince1970)
            self.delegate?.didUpdateRemainingTime(remainingTime)
            
        }
        else
        {
            if( isAboveGoldenHour() )
            { self.delegate?.didUpdateStatus(2) }
            else if( isBelowGoldenHour() )
            { self.delegate?.didUpdateStatus(-2)}
            
            let nextTime: [Date] = getTimesForNextGoldenHour()
            self.delegate?.didUpdateGoldenHour(nextTime)
        }
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
    
    
    func getTimesForThisGoldenHour() -> [Date]
    {
        var result: [Date] = []
        result.append(getStartTimeThisGoldenHour())
        result.append(getEndTimeThisGoldenHour())
        return result
    }
    
    func getStartTimeThisGoldenHour() -> Date
    {
        let time = Date()
        let GMT = currentData.GMT
        let lon = currentData.Longitude!
        let lat = currentData.Latitude!
        let sun = SunPositionModel(time, GMT, longitude: lon, latitude: lat)
        
        var currentState = self.isAboveHorizon()
        
        for _ in 0 ... 86400
        {
            sun.date -= 1
            sun.spa_calculate()
            if ((sun.declination <= LOWERLIMIT) || ( UPPERLIMIT <= sun.declination ))
            {
                break
            }
            // Checking if passing Horizon
            else if ( currentState ^ (sun.declination > 0))
            {
                if(currentState)
                {
                    //sunrise
                    self.delegate?.didUpdateSunriseTime(sun.date)
                }
                else
                {
                    //sunset
                    self.delegate?.didUpdateSunsetTime(sun.date)
                }
                currentState = !currentState
            }
        }
        return sun.date
    }
    
    func getEndTimeThisGoldenHour() -> Date
    {
        let time = Date()
        let GMT = currentData.GMT
        let lon = currentData.Longitude!
        let lat = currentData.Latitude!
        let sun = SunPositionModel(time, GMT, longitude: lon, latitude: lat)
        
        var currentState = self.isAboveHorizon()
        
        for _ in 0 ... 86400
        {
            sun.date += 1
            sun.spa_calculate()
            if ((sun.declination <= LOWERLIMIT) || ( UPPERLIMIT <= sun.declination ))
            {
                break
            }
            // Checking if passing Horizon
            else if ( currentState ^ (sun.declination > 0))
            {
                if(currentState)
                {
                    //sunset
                    self.delegate?.didUpdateSunsetTime(sun.date)
                }
                else
                {
                    //sunrise
                    self.delegate?.didUpdateSunriseTime(sun.date)
                }
                currentState = !currentState
            }
        }
        return sun.date
    }
    
    
    func getTimesForNextGoldenHour() -> [Date]
    {
        var result: [Date] = []
        
        let time = Date()
        let GMT = currentData.GMT
        let lon = currentData.Longitude!
        let lat = currentData.Latitude!
        let sun = SunPositionModel(time, GMT, longitude: lon, latitude: lat)
        
        var currentState = self.isAboveHorizon()
        
        if( currentData.SunAltitude! >= UPPERLIMIT )
        {
            for i in 0 ... 17280
            {
                sun.date += 5 //increase
                sun.spa_calculate()
                if( (result.count == 0) && (sun.declination <= UPPERLIMIT) )
                {
                    result.append(sun.date)
                }
                    // Checking if passing Horizon
                else if ( currentState ^ (sun.declination > 0))
                {
                    if(currentState)
                    {
                        //sunset
                        self.delegate?.didUpdateSunsetTime(sun.date)
                    }
                    else
                    {
                        //sunrise
                        self.delegate?.didUpdateSunriseTime(sun.date)
                    }
                    currentState = !currentState
                }
                else if( (result.count == 1) && ((sun.declination <= LOWERLIMIT) || ( UPPERLIMIT <= sun.declination )) )
                {
                    result.append(sun.date)
                    break
                }
                print(" \(i), \(sun.declination)")
            }
        }
        else if ( currentData.SunAltitude! <= LOWERLIMIT )
        {
            for i in 0 ... 17280
            {
                sun.date += 5 //increase
                sun.spa_calculate()
                if( (result.count == 0) && (sun.declination >= LOWERLIMIT) )
                {
                    result.append(sun.date)
                }
                else if( (result.count == 1) && ((UPPERLIMIT <= sun.declination) || (sun.declination <= LOWERLIMIT)) )
                {
                    result.append(sun.date)
                    break
                }
                print(" \(i), \(sun.declination)")
            }
        }
        
        return result
    }
    
}


// XOR operation for Bool
extension Bool {
    static func ^ (left: Bool, right: Bool) -> Bool {
        return left != right
    }
}
