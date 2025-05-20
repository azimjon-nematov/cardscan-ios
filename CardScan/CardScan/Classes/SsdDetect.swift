//
//  SsdDetect.swift
//  CardScan
//
//  Created by Zain on 8/5/19.
//

import Foundation
import os.log
import UIKit

import CoreML

/**
 Documentation on how SSD works
 
 */


@available(iOS 11.2, *)
public struct SsdDetect {
    static var ssdModel: SSD? = nil
    static var priors:[CGRect]? = nil
    
    // SSD Model Parameters
    static let ssdImageWidth = 300
    static let ssdImageHeight = 300
    static let probThreshold: Float = 0.3
    static let iouThreshold: Float = 0.45
    static let candidateSize = 200
    static let topK = 10

    /* We don't use the following constants, these values are determined at run time
    *  Regardless, this is good information to keep around.
    *  let NoOfClasses = 14
    *  let TotalNumberOfPriors = 2766
    *  let NoOfCordinates = 4
    */
    
    static public func warmUp() {
        // TODO(stk): implement this after we finish up dynamic model updating
    }
    
    public init() {
        if SsdDetect.priors == nil {
            SsdDetect.priors = PriorsGen.combinePriors()
        }
        
    }
    
    public static func initializeModels(contentsOf url: URL) {
        if SsdDetect.ssdModel == nil {
            SsdDetect.ssdModel = try? SSD(contentsOf: url)
        }
        
    }
    
    public static func isModelLoaded() -> Bool {
        return self.ssdModel != nil
    }
    
    func detectObjects(prediction: SSDOutput, image: UIImage) -> [DetectedSSDOcrBox] {
        var DetectedSSDBoxes = [DetectedSSDOcrBox]()
        var startTime = CFAbsoluteTimeGetCurrent()
        let boxes = prediction.getBoxes()
        let scores = prediction.getScores()
        var endTime = CFAbsoluteTimeGetCurrent() - startTime
        os_log("%@", type: .debug, "Get boxes and scores from mult-array time: \(endTime)")
        
        startTime = CFAbsoluteTimeGetCurrent()
        let normalizedScores = prediction.fasterSoftmax2D(scores)
        let regularBoxes = prediction.convertLocationsToBoxes(locations: boxes, priors: SsdDetect.priors ?? PriorsGen.combinePriors(), centerVariance: 0.1, sizeVariance: 0.2)
        let cornerFormBoxes = SSDOutput.centerFormToCornerForm(regularBoxes: regularBoxes)

        let result:Result = predictionAPI(scores:normalizedScores, boxes: cornerFormBoxes, probThreshold: SsdDetect.probThreshold, iouThreshold: SsdDetect.iouThreshold, candidateSize: SsdDetect.candidateSize, topK: SsdDetect.topK)
        endTime = CFAbsoluteTimeGetCurrent() - startTime
        os_log("%@", type: .debug, "Rest of the forward pass time: \(endTime)")
        
        for idx in 0..<result.pickedBoxes.count {
            DetectedSSDBoxes.append(DetectedSSDOcrBox(category: result.pickedLabels[idx], conf: result.pickedBoxProbs[idx], XMin: Double(result.pickedBoxes[idx][0]), YMin: Double(result.pickedBoxes[idx][1]), XMax: Double(result.pickedBoxes[idx][2]), YMax: Double(result.pickedBoxes[idx][3]), imageSize: image.size))
        }


       return DetectedSSDBoxes
        
    }
    
    /**
     * A utitliy struct that applies non-max supression to each class
     * picks out the remaining boxes, the class probabilities for classes
     * that are kept and composes all the information in one place to be returned as
     * an object.
     */
    func predictionAPI(scores: [[Float]], boxes: [[Float]], probThreshold: Float, iouThreshold: Float, candidateSize: Int , topK: Int) -> Result{
        var pickedBoxes:[[Float]] = [[Float]]()
        var pickedLabels:[Int] = [Int]()
        var pickedBoxProbs:[Float] = [Float]()
        
        
        for classIndex in 1..<scores[0].count{
            var probs: [Float] = [Float]()
            var subsetBoxes: [[Float]] = [[Float]]()
            var indicies : [Int] = [Int]()
            
            for rowIndex in 0..<scores.count{
                if scores[rowIndex][classIndex] > probThreshold{
                    probs.append(scores[rowIndex][classIndex])
                    subsetBoxes.append(boxes[rowIndex])
                }
            }
            
            if probs.count == 0{
                continue
            }
            
            indicies = NMS.hardNMS(subsetBoxes: subsetBoxes, probs: probs, iouThreshold: iouThreshold, topK: topK, candidateSize: candidateSize)
           
            for idx in indicies{
                pickedBoxProbs.append(probs[idx])
                pickedBoxes.append(subsetBoxes[idx])
                pickedLabels.append(classIndex)
            }
        }
        var result: Result = Result()
        result.pickedBoxProbs =  pickedBoxProbs
        result.pickedLabels = pickedLabels
        result.pickedBoxes = pickedBoxes
        
        return result
        
    }
    
    
    public func predict(image: UIImage) -> [DetectedSSDOcrBox]? {

        guard let pixelBuffer = image.pixelBuffer(width: SsdDetect.ssdImageWidth, height: SsdDetect.ssdImageHeight) else {
            os_log("Couldn't convert to pixel buffer", type: .debug)
            return nil
        }
        
        
        guard let detectModel = SsdDetect.ssdModel else {
            os_log("Model not initialized", type: .debug)
            return nil
        }
       
        let startTime = CFAbsoluteTimeGetCurrent()
        let input = SSDInput(_0: pixelBuffer)
        guard let prediction = try? detectModel.prediction(input: input) else {
            os_log("Couldn't predict", type: .debug)
            return nil
        }
        let endTime = CFAbsoluteTimeGetCurrent() - startTime
        os_log("%@", type: .debug, "Model Run without post-process time: \(endTime)")

        return self.detectObjects(prediction: prediction, image: image)
    }
    

}


struct Result{
    var pickedBoxProbs: [Float]
    var pickedLabels: [Int]
    var pickedBoxes: [[Float]]
    
    init() {
        pickedBoxProbs = [Float]()
        pickedLabels = [Int]()
        pickedBoxes = [[Float]]()
    }
}
