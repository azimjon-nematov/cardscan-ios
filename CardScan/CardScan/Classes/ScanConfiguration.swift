import Foundation

@objc public enum ScanPerformance: Int {
    case fast
    case accurate
}

@objc public class ScanConfiguration: NSObject {
    @objc public var runOnOldDevices = false
    @objc public var setPreviouslyDeniedDevicesAsIncompatible = false
    
    static func deviceType() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        var deviceType = ""
        for char in Mirror(reflecting: systemInfo.machine).children {
            guard let charDigit = (char.value as? Int8) else {
                return ""
            }
            
            if charDigit == 0 {
                break
            }
            
            deviceType += String(UnicodeScalar(UInt8(charDigit)))
        }
        
        return deviceType
    }
    
}
