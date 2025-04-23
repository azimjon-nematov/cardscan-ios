//
//  DetectedAllBoxes.swift
//  CardScan
//
//  Created by Zain on 8/15/19.
//
/**
 Data structure used to store all the detected boxes per frame or scan
 
 */

public struct DetectedAllBoxes {
    var allBoxes: [DetectedSSDBox] = []
    
    public init() {}
}

