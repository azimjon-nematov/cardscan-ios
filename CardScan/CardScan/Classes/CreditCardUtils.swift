import Foundation

public struct CreditCardUtils {
    static let maxCvvLength = 3
    static let maxCvvLengthAmex = 4
    
    static let maxPanLength = 16
    static let maxPanLengthAmericanExpress = 15
    static let maxPanLengthDinersClub = 14

    private static let prefixesAmericanExpress = ["34", "37"]
    private static let prefixesDinersClub = ["300", "301", "302", "303", "304", "305", "309", "36", "38", "39"]
    private static let prefixesDiscover = ["6011", "64", "65"]
    private static let prefixesJcb = ["35"]
    private static let prefixesMastercard = ["2221", "2222", "2223", "2224", "2225", "2226",
                                     "2227", "2228", "2229", "223", "224", "225", "226",
                                     "227", "228", "229", "23", "24", "25", "26", "270",
                                     "271", "2720", "50", "51", "52", "53", "54", "55",
                                     "67"]
    private static let prefixesUnionPay = ["62"]
    private static let prefixesVisa = ["4"]

    public static var prefixesRegional: [String] = []
    
    private static var cardTypeMap: [(ClosedRange<Int>, CardType)]? = nil
    
    /**
        Adds the BINs implemented by the MIR network in Russia as regional cards
     */
    public static func addMirSupport() {
        prefixesRegional += ["2200", "2201", "2202", "2203", "2204"]
    }
    
    /**
        Checks if the card number is valid.
        -   Parameter cardNumber: The card number as a string .
        -   Returns: `true` if valid, `false` otherwise
     */
    public static func isValidNumber(cardNumber: String) -> Bool {
        return isValidLuhnNumber(cardNumber: cardNumber) && isValidLength(cardNumber: cardNumber)
    }
    
    /**
        Checks if the card's cvv is valid
        -   Parameters:
            -   cvv: The cvv as a string
            -   network: The card's bank network
        -   Returns: `true` if valid, `false ` otherwise
     */
    public static func isValidCvv(cvv: String, network: CardNetwork) -> Bool {
        let cvv = cvv.trimmingCharacters(in: .whitespacesAndNewlines)
        return (network == CardNetwork.AMEX && cvv.count == maxCvvLengthAmex) || (cvv.count == maxCvvLength)
    }
    
    /**
        Checks if the card's expiration date is valid
        -   Parameters:
            -   expMonth: The expiration month as a string
            -   expYear: The expiration year as a string
        -   Returns: `true` is both expiration month and year are valid, `false` otherwise
     */
    public static func isValidDate(expMonth: String, expYear: String) -> Bool {
        guard let expirationMonth = Int(expMonth.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        
        guard let expirationYear = Int(expYear.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        
        if !isValidMonth(expMonth: expirationMonth) {
            return false
        } else if !isValidYear(expYear: expirationYear) {
            return false
        } else {
            return !hasMonthPassed(expMonth: expirationMonth, expYear: expirationYear)
        }
    }
    
    /**
       Checks if the card's expiration month is valid
       -   Parameter expMonth: The expiration month as an integer
       -   Returns: `true` if valid, `false` otherwise
    */
    static func isValidMonth(expMonth: Int) -> Bool {
        return 1...12 ~= expMonth
    }
    
    /**
        Checks if the card's expiration year is valid
        -   Parameter expYear: The expiration year as an integer
        -   Returns: `true` if valid, `false` otherwise
     */
    static func isValidYear(expYear: Int) -> Bool {
        return !hasYearPassed(expYear: expYear)
    }
    
    /**
        Checks if the card's expiration month has passed
        - Parameters:
            -   expMonth: The expiration month as an integer
            -   expYear: The expiration year as an integer
        - Returns: `true` if expiration month has passed current time, `false` otherwise
     */
    static func hasMonthPassed(expMonth: Int, expYear: Int) -> Bool {
        let currentMonth = getCurrentMonth()
        let currentYear = getCurrentYear()
        
        if hasYearPassed(expYear: expYear) {
            return true
        } else {
            return normalizeYear(expYear: expYear) == currentYear && expMonth < currentMonth
        }
    }
    
    /**
        Checks if the card's expiration year has passed
        - Parameter expYear: The expiration year as an integer
        - Returns: `true` if expiration year has passed current time, `false` otherwise
     */
    static func hasYearPassed(expYear: Int) -> Bool {
        let currentYear = getCurrentYear()
        guard let expirationYear = normalizeYear(expYear: expYear) else {
            print("Could not get normalized expiration year")
            return false
        }
        return expirationYear < currentYear
    }
    
    /**
        Returns expiration year in four digits. If expiration year is two digits, it appends the current century to the beginning of the year
        -   Parameter expYear: The expiration year as an integer
        -   Returns: An `Int` of the four digit year, `nil` otherwise
     */
    static func normalizeYear(expYear: Int) -> Int? {
        let currentYear = getCurrentYear()
        var expirationYear: Int
    
        if 0...99 ~= expYear {
            let currentYearToString = String(currentYear)
            let currentYearPrefix = currentYearToString.prefix(2)
            guard let concatExpYear = Int("\(currentYearPrefix)\(expYear)") else {
                print("Could not convert newly concatenated exp year string to int")
                return nil
            }
            expirationYear = concatExpYear
        } else {
            expirationYear = expYear
        }
        
        return expirationYear
    }
    
    static func getCurrentYear() -> Int {
        let date = Date()
        let now = Calendar.current
        let currentYear = now.component(.year, from: date)
        return currentYear
    }
    
    static func getCurrentMonth() -> Int {
        let date = Date()
        let now = Calendar.current
        // The start of the month begins from 1
        let currentMonth = now.component(.month, from: date)
        return currentMonth
    }
    
    // https://en.wikipedia.org/wiki/Luhn_algorithm
    // assume 16 digits are for MC and Visa (start with 4, 5) and 15 is for Amex
    // which starts with 3
    /**
        Checks if the card number passes the Luhn's algorithm
        -   Parameter cardNumber: The card number as a string
        -   Returns: `true` if the card number is a valid Luhn number, `false` otherwise
     */
    static func isValidLuhnNumber(cardNumber: String) -> Bool {
        if cardNumber.isEmpty || !isValidBin(cardNumber: cardNumber){
            return false
        }
        
        var sum = 0
        let reversedCharacters = cardNumber.reversed().map { String($0) }
        for (idx, element) in reversedCharacters.enumerated() {
            guard let digit = Int(element) else { return false }
            switch ((idx % 2 == 1), digit) {
            case (true, 9): sum += 9
            case (true, 0...8): sum += (digit * 2) % 9
            default: sum += digit
            }
        }
        return sum % 10 == 0
    }
    
    /**
        Checks if the card number contains a valid bin
        -   Parameter cardNumber: The card number as a string
        -   Returns: `true` if the card number contains a valid bin, `false` otherwise
     */
    static func isValidBin(cardNumber: String) -> Bool {
        determineCardNetwork(cardNumber: cardNumber) != CardNetwork.UNKNOWN
    }
    
    static func isValidLength(cardNumber: String) -> Bool {
        return isValidLength(cardNumber: cardNumber, network: determineCardNetwork(cardNumber: cardNumber))
    }

    /**
        Checks if the inputted card number has a valid length in accordance with the card's bank network
        -   Parameters:
            -   cardNumber: The card number as a string
            -   network: The card's bank network
        -   Returns: `true` is card number is a valid length, `false` otherwise
     */
    static func isValidLength(cardNumber: String, network: CardNetwork ) -> Bool {
        let cardNumber = cardNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let cardNumberLength = cardNumber.count
        
        if cardNumber.isEmpty || network == CardNetwork.UNKNOWN {
            return false
        }
        
        switch network {
        case CardNetwork.AMEX:
            return cardNumberLength == maxPanLengthAmericanExpress
        case CardNetwork.DINERSCLUB:
            return cardNumberLength == maxPanLengthDinersClub
        default:
            return cardNumberLength == maxPanLength
        }
    }
    
    /**
        Returns the card's issuer / bank network based on the card number
        -   Parameter cardNumber: The card number as a string
        -   Returns: The card's bank network as a CardNetwork enum
     */
    public static func determineCardNetwork(cardNumber: String) -> CardNetwork {
        let cardNumber = cardNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cardNumber.isEmpty {
            return CardNetwork.UNKNOWN
        }
        
        switch true {
        case hasAnyPrefix(cardNumber: cardNumber, prefixes: prefixesAmericanExpress):
            return CardNetwork.AMEX
        case hasAnyPrefix(cardNumber: cardNumber, prefixes: prefixesDiscover):
            return CardNetwork.DISCOVER
        case hasAnyPrefix(cardNumber: cardNumber, prefixes: prefixesJcb):
            return CardNetwork.JCB
        case hasAnyPrefix(cardNumber: cardNumber, prefixes: prefixesDinersClub):
            return CardNetwork.DINERSCLUB
        case hasAnyPrefix(cardNumber: cardNumber, prefixes: prefixesVisa):
            return CardNetwork.VISA
        case hasAnyPrefix(cardNumber: cardNumber, prefixes: prefixesMastercard):
            return CardNetwork.MASTERCARD
        case hasAnyPrefix(cardNumber: cardNumber, prefixes: prefixesUnionPay):
            return CardNetwork.UNIONPAY
        case hasAnyPrefix(cardNumber: cardNumber, prefixes: prefixesRegional):
            return CardNetwork.REGIONAL
        default:
            return CardNetwork.UNKNOWN
        }
    }
    
    /**
        Determines whether a card number belongs to any bank network according to their bin
        -   Parameters:
            -   cardNumber: The card number as a string
            -   prefixes: The set of bin prefixes used with certain bank networks
        -   Returns: `true` if card number belongs to a bank network, `false` otherwise
    */
    static func hasAnyPrefix(cardNumber: String, prefixes: [String] ) -> Bool {
        return prefixes.filter { cardNumber.hasPrefix($0) }.count > 0
    }
    
    /**
        Returns the card number formatted for display
        -   Parameter cardNumber: The card number as a string
        -   Returns: The card number formatted
     */
    public static func formatCardNumber(cardNumber: String) -> String {
        if cardNumber.count == maxPanLength {
            return format16(cardNumber: cardNumber)
        } else if cardNumber.count == maxPanLengthAmericanExpress {
            return format15(cardNumber: cardNumber)
        } else {
            return cardNumber
        }
    }
    
    /**
        Returns the card's expiration date formatted for display
        -   Parameters:
                -   expMonth: The expiration month as a string
                -   expYear: The expiration year as a string
        -   Returns: The card's expiration date formatted as MM/YY
     */
    public static func formatExpirationDate(expMonth: String, expYear: String) -> String {
        var month = expMonth
        let year = "\(expYear.suffix(2))"
        
        if expMonth.count == 1 {
            month = "0\(expMonth)"
        }
        
        return "\(month)/\(year)"
    }
    
    static func format15(cardNumber: String) -> String {
        var displayNumber = ""
        for (idx, char) in cardNumber.enumerated() {
            if idx == 4 || idx == 10 {
                displayNumber += " "
            }
            displayNumber += String(char)
        }
        return displayNumber
    }
    
    static func format16(cardNumber: String) -> String {
        var displayNumber = ""
        for (idx, char) in cardNumber.enumerated() {
            if (idx % 4) == 0 && idx != 0 {
                displayNumber += " "
            }
            displayNumber += String(char)
        }
        return displayNumber
    }
}

//TODO: Added extension to make older network changes available, will remove in future version
extension CreditCardUtils {
    public static func isVisa(number: String) -> Bool {
        return determineCardNetwork(cardNumber: number) == CardNetwork.VISA
    }
    
    public static func isAmex(number: String) -> Bool {
        return determineCardNetwork(cardNumber: number) == CardNetwork.AMEX
    }
    
    public static func isDiscover(number: String) -> Bool {
        return determineCardNetwork(cardNumber: number) == CardNetwork.DISCOVER
    }
    
    public static func isMastercard(number: String) -> Bool {
        return determineCardNetwork(cardNumber: number) == CardNetwork.MASTERCARD
    }
    
    public static func isUnionPay(number: String) -> Bool {
        return determineCardNetwork(cardNumber: number) == CardNetwork.UNIONPAY
    }
}
