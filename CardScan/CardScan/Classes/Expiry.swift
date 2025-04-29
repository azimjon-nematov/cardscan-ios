import Foundation
// TODO: this may be deleted
public struct Expiry {
    public let string: String
    public let month: UInt
    public let year: UInt
    
    func display() -> String {
        let twoDigitYear = self.year % 100
        return String(format: "%02d/%02d", self.month, twoDigitYear)
    }
}
