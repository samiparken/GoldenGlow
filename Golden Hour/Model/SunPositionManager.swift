import Foundation
import CoreLocation
import RealmSwift

protocol SunPositionManagerDelegate {
    func didUpdateCurrentCity(_ cityName: String)
    func didUpdateCurrentState(_ sunAngle: Double, _ isUp: Bool)
    func didUpdateCurrentScan(from: Date, to: Date, _ nowState: Int, _ nextState: Int)
    func didUpdateTodayScan(_ today: [SunTimestamp])
}

class SunPositionManager {
    var delegate: SunPositionManagerDelegate?
    
    let dataManager = DataManager()
    
    // Realm Object
    var locationData: Results<LocationData>?
    var selectedLocationData: LocationData?
    var timestampData: Results<TimestampData>?

    // Location Data
    var cityName: String = ""
    var countryName: String = ""
    var countryCode: String = ""
    var timezone: TimeZone?
    var GMT: Double {
        get{
            return Double(timezone!.secondsFromGMT()) / 3600
        }
    }
    var deviceGMT: Double = Double(TimeZone.current.secondsFromGMT()) / 3600
    var timezoneOffset: Double {
        get {
            return (self.GMT - deviceGMT) * 3600
        }
    }
    var Longitude: Double?
    var Latitude: Double?
    
    // Sun Position Data
    var SunAltitude: Double? {
        get {
            let now = Date()
            if let lon = self.Longitude,
               let lat = self.Latitude {
                var sun = SunPositionModel(now, self.GMT, longitude: lon, latitude: lat)
                sun.spa_calculate()
                return sun.declination
            } else {
                return 0
            }
        }
    }
    var SunAltitudeChange: Double? {
        get {
            if let lon = self.Longitude, let lat = self.Latitude
            {
                var sun1 = SunPositionModel(Date(), self.GMT, longitude: lon, latitude: lat)
                var sun2 = SunPositionModel(Date() + 10, self.GMT, longitude: lon, latitude: lat)

                sun1.spa_calculate()
                sun2.spa_calculate()
                
                return sun2.declination - sun1.declination

            } else {
                return 0
            }

        }
    }
    var isMorning: Bool?       // for PlanView
    
    
//MARK: - Init
    func initSunPositionSystem(_ cityName: String,
                               _ countryName: String,
                               _ countryCode: String,
                               long:  CLLocationDegrees,
                               lat:  CLLocationDegrees) {
        
        self.cityName = cityName
        self.countryName = countryName
        self.countryCode = countryCode
        self.Longitude = long
        self.Latitude = lat

        let loc = CLLocation.init(latitude: lat, longitude: long);
        let coder = CLGeocoder();
        coder.reverseGeocodeLocation(loc) { [self] (placemarks, error) in
            let place = placemarks?.last;
            self.timezone = place?.timeZone
                                    
            let locationData = LocationData() //Realm Object
            locationData.cityName = cityName
            locationData.countryName = countryName
            locationData.countryCode = countryCode
            locationData.longitude = long
            locationData.latitude = lat
            
            dataManager.storeLocationData(locationData)
                                                      
            let today = Date() //temporary
            timestampData = dataManager.readTimestampData(locationData, today)

            if( timestampData!.count == 0)
            {
                // scan data & store timestamps in RealmDB

                
                // show data
                            
            } else {
                
                

                // show data
            }
            
            /* START SUN POSITION SYSTEM */
            startSunPositionSystem()
        }
    }

//MARK: - Calculate
    func startSunPositionSystem()
    {
        // Update CityName & Localtime at the top
        self.delegate?.didUpdateCurrentCity(self.cityName)
        
        refreshCurrentState()
        refreshDateState()
    }
    
    func refreshCurrentState() {
        // Current Scan -> SkyView1 (Timer & Current State)
        let nowRange: [Date] = currentScan()
        let nowState = getState()
        let nowNext = getNextState()
        self.delegate?.didUpdateCurrentScan(from: nowRange[0], to: nowRange[1], nowState, nowNext)
        
        // BG & morning/evening
        self.delegate?.didUpdateCurrentState(self.SunAltitude!, isSunGoingUp())
    }
    
    func refreshDateState() {
        // Today Scan -> SkyView2
                
        let nowState = getState()
        let nowNext = getNextState()
        var targetDate = Date() + timezoneOffset
        
        if ( nowState == NIGHTTIME )
            && ( nowNext == BLUEHOUR )
            && ( isSunGoingUp() == false ) {
            targetDate += 86400
        }
                
        let calendar = Calendar.current
        let yyyy = String(calendar.component(.year, from: targetDate))
        let mm = String(calendar.component(.month, from: targetDate))
        let dd = String(calendar.component(.day, from: targetDate))
        let scanResult = dateScan(yyyy, mm, dd)
        self.delegate?.didUpdateTodayScan(scanResult)
    }
    
    func currentScan() -> [Date] {

        var result: [Date] = []     // result.count == 2

        let lon = self.Longitude!
        let lat = self.Latitude!

        let now = Date()
        let scanForwardLimit = now + 86400 // within 24h
        let scanBackwardLimit = now - 86400 // within 24h
        
        var sun = SunPositionModel(now, self.GMT, longitude: lon, latitude: lat)
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
                sun.date -= calculateTimeGapInSecond(sunAngle)   // decrease timestamp for scanning
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
                sun.date += calculateTimeGapInSecond(sunAngle)   // increase timestamp for scanning
            }
        }
                
        return result
    }
    
    
    // Scan TargetDate & store TimestampData[]
    func dateScan(_ year: String, _ month: String, _ day: String) -> [SunTimestamp] {
        
        var result: [SunTimestamp] = []
        
        let targetDateString = year + "-" + month + "-" + day + " 00:00:00"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"  //ex) 2020-03-13 00:00:00 +0200
        let targetDate = dateFormatter.date(from: targetDateString)! - timezoneOffset
                
        let scanLimitDate = targetDate + 86400 // within 24h
        var sun = SunPositionModel(targetDate, GMT, longitude: self.Longitude!, latitude: self.Latitude!)
        sun.spa_calculate()
        var currentState = self.getState(sun.declination)
        sun.date += self.calculateTimeGapInSecond(sun.declination)   // increase timestamp for scanning
                
        repeat {
            sun.spa_calculate()
            let sunAngle = sun.declination
            let newState = getState(sunAngle)
            if ( currentState != newState )
            {
                let newTimestamp = SunTimestamp(time: sun.date + timezoneOffset, from: currentState, to: newState)
                result.append(newTimestamp)
                currentState = newState
            }
            sun.date += calculateTimeGapInSecond(sunAngle)   // increase timestamp for scanning
            print("dateScan: \(year)-\(month)-\(day), \(sunAngle)")
        } while( (sun.date < scanLimitDate) && ( result.count < 12 ) )
        
        return result
    }
/*
    func dailyScan(_ year: String, _ month: String, _ day: String) -> [SunTimestamp] {
        
        var result: [SunTimestamp] = []

        let lon = self.Longitude!
        let lat = self.Latitude!

        let GMTString = String(format: "%+05d", Int(GMT*10) * 10)
        let inputDateString = year + "-" + month + "-" + day + " 00:00:00  " + GMTString
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"  //ex) 2020-03-13 13:37:00 +0100
        let inputDate = dateFormatter.date(from: inputDateString)
        let scanLimitDate = inputDate! + 86400 // within 24h
        
        var sun = SunPositionModel(inputDate!, GMT, longitude: lon, latitude: lat)
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
    */
    
    // Applied 'Adaptive Step Size Algorithm(Method)'
    func calculateTimeGapInSecond(_ sunAngle: Double) -> Double {
        let absAngle = abs(sunAngle)
        let temp = (absAngle - 10) * 240   // most fastest case 4min/deg, it covers all the cases
                                           // OLD comment: divide 15, multiply 3600
        return ( temp > 60 ) ? temp : 60
    }

    

    
//MARK: - Get
    func isAboveEvent() -> Bool {
        let sun = self.SunAltitude!
        return isAboveEvent(sun)
    }
    func isAboveEvent(_ sun: Double) -> Bool {
        return sun > UPPERLIMIT ? true : false
    }
    
    func isLowSun() -> Bool {
        let sun = self.SunAltitude!
        return isLowSun(sun)
    }
    func isLowSun(_ sun: Double) -> Bool {
        return ( UPPERGOLDEN <= sun ) && ( sun <= UPPERLIMIT ) ? true : false
    }
    
    // GoldenHour+
    func isGoldenHourP() -> Bool {
        let sun = self.SunAltitude!
        return isGoldenHourP(sun)
    }
    func isGoldenHourP(_ sun: Double) -> Bool {
        return ( UPPERSETRISE <= sun ) && ( sun <= UPPERGOLDEN ) ? true : false
    }
    
    func isSetRise() -> Bool {
        let sun = self.SunAltitude!
        return isSetRise(sun)
    }
    func isSetRise(_ sun: Double) -> Bool {
        return ( LOWERSETRISE <= sun ) && ( sun <= UPPERSETRISE ) ? true : false
    }
    
    // GoldenHour-
    func isGoldenHourM() -> Bool {
        let sun = self.SunAltitude!
        return isGoldenHourM(sun)
    }
    func isGoldenHourM(_ sun: Double) -> Bool {
        return ( LOWERGOLDEN <= sun ) && ( sun <= LOWERSETRISE ) ? true : false
    }
    
    func isBlueHour() -> Bool {
        let sun = self.SunAltitude!
        return isBlueHour(sun)
    }
    func isBlueHour(_ sun: Double) -> Bool {
        return ( LOWERLIMIT <= sun ) && ( sun <= LOWERGOLDEN ) ? true : false
    }
    
    func isBelowEvent() -> Bool {
        let sun = self.SunAltitude!
        return isBelowEvent(sun)
    }
    func isBelowEvent(_ sun: Double) -> Bool {
        return sun < LOWERLIMIT ? true : false
    }

    
    func isAboveHorizon() -> Bool {
        let sun = self.SunAltitude!
        return isAboveHorizon(sun)
    }
    func isAboveHorizon(_ sun: Double) -> Bool {
        return sun > 0 ? true : false
    }

    
    func isSunGoingUp() -> Bool {
        let change = self.SunAltitudeChange!
        return change > 0 ? true : false
    }
    
    func getAltitude() -> Double {
        if let sun = self.SunAltitude { return sun }
        else { return 0 }
    }

    
    func getState(_ sunAngle: Double = INVALIDANGLE) -> Int
    {
        let inputAngle = sunAngle != INVALIDANGLE ? sunAngle : self.SunAltitude!
        
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
 
    
}

// XOR operation for Bool
extension Bool {
    static func ^ (left: Bool, right: Bool) -> Bool {
        return left != right
    }
}
