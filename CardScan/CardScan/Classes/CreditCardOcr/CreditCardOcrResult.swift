//
//  CreditCardOcrResult.swift
//  ocr-playground-ios
//
//  Created by Sam King on 3/20/20.
//  Copyright © 2020 Sam King. All rights reserved.
//

import Foundation

public class CreditCardOcrResult {
    public let mostRecentPrediction: CreditCardOcrPrediction
    public let number: String
    public let expiry: String?
    public let name: String?
    public let state: MainLoopState
    let duration: Double
    let frames: Int
    var framePerSecond: Double {
        return Double(frames) / duration
    }
    
    init(mostRecentPrediction: CreditCardOcrPrediction, number: String, expiry: String?, name: String?, state: MainLoopState, duration: Double, frames: Int) {
        self.mostRecentPrediction = mostRecentPrediction
        self.number = number
        self.expiry = expiry
        self.name = name
        self.state = state
        self.duration = duration
        self.frames = frames
    }
    
    public var expiryMonth: String? {
        return expiry.flatMap { $0.split(separator: "/").first.map { String($0) }}
    }
    public var expiryYear: String? {
        return expiry.flatMap { $0.split(separator: "/").last.map { String($0) }}
    }
    
    public static func finishedWithNonNumberSideCard(prediction: CreditCardOcrPrediction, duration: Double, frames: Int) -> CreditCardOcrResult {
        let result = CreditCardOcrResult(mostRecentPrediction: prediction, number: "", expiry: nil, name: nil, state: .finished, duration: duration, frames: frames)
        return result
    }
}
