//
//  SSDOcrDetect.swift
//  CardScan
//
//  Created by xaen on 3/21/20.
//

import CoreGraphics
import Foundation
import UIKit

/** Documentation for SSD OCR
 
 */

@available(iOS 11.2, *)
struct SSDOcrDetect {
    var ssdOcrModel: SSDOcr? = nil
    static var priors: [CGRect]? = nil
    
    static var ssdOcrResource = "SSDOcr"
    static let ssdOcrExtension = "mlmodelc"
    
    //SSD Model parameters
    static let sigma: Float = 0.5
    let ssdOcrImageWidth = 600
    let ssdOcrImageHeight = 375
    let probThreshold: Float = 0.45
    let filterThreshold: Float = 0.39
    let iouThreshold: Float = 0.5
    let centerVariance: Float = 0.1
    let sizeVariance: Float = 0.2
    let candidateSize = 200
    let topK = 20
    
    //Statistics about last prediction
    var lastDetectedBoxes: [CGRect] = []
    static var hasPrintedInitError = false
    
    public init() {
        if SSDOcrDetect.priors == nil{
            SSDOcrDetect.priors = OcrPriorsGen.combinePriors()
        }
        guard let ssdOcrUrl  = CSBundle.compiledModel(forResource: SSDOcrDetect.ssdOcrResource, withExtension: SSDOcrDetect.ssdOcrExtension) else {

            print("Could not find URL for ssd ocr")
            return
        }
        
        guard let ssdOcrModel = try? SSDOcr(contentsOf: ssdOcrUrl) else {
            print("Could not get contents of ssd ocr model with ssd ocr URL")
            return
        }
        
        self.ssdOcrModel = ssdOcrModel
    }
    
    static func initializeModels() {
        if SSDOcrDetect.priors == nil{
            SSDOcrDetect.priors = OcrPriorsGen.combinePriors()
        }
    }
    
    mutating func detectOcrObjects(prediction: SSDOcrOutput, image: UIImage) -> String? {
        var DetectedOcrBoxes = [DetectedSSDOcrBox]()
        

        var (scores, boxes, filterArray) = prediction.getScores(filterThreshold: filterThreshold)
        let regularBoxes = prediction.convertLocationsToBoxes(
            locations: boxes,
            priors: SSDOcrDetect.priors ?? OcrPriorsGen.combinePriors(),
            centerVariance: centerVariance,
            sizeVariance: sizeVariance
        )
        let cornerFormBoxes = SSDOutput.centerFormToCornerForm(regularBoxes: regularBoxes)
        
        (scores, boxes) = prediction.filterScoresAndBoxes(
            scores: scores,
            boxes: cornerFormBoxes,
            filterArray:  filterArray,
            filterThreshold: filterThreshold
        )
        
        if scores.isEmpty || boxes.isEmpty{
            return nil
        }
        
        let result: Result = self.predictionUtil(
            scores:scores,
            boxes: boxes,
            probThreshold: probThreshold,
            iouThreshold: iouThreshold,
            candidateSize: candidateSize,
            topK: topK
        )
    
        for idx in 0..<result.pickedBoxes.count {
            DetectedOcrBoxes.append(
                DetectedSSDOcrBox(
                    category: result.pickedLabels[idx],
                    conf: result.pickedBoxProbs[idx],
                    XMin: Double(result.pickedBoxes[idx][0]),
                    YMin: Double(result.pickedBoxes[idx][1]),
                    XMax: Double(result.pickedBoxes[idx][2]),
                    YMax: Double(result.pickedBoxes[idx][3]),
                    imageSize: image.size
                )
            )
        }
        
        if !DetectedOcrBoxes.isEmpty {
            self.lastDetectedBoxes = DetectedOcrBoxes.map { $0.rect }
        }
        
        if OcrDDUtils.isQuickRead(allBoxes: DetectedOcrBoxes){
            guard let (number, boxes) = OcrDDUtils.processQuickRead(allBoxes: DetectedOcrBoxes) else { return nil }
            self.lastDetectedBoxes = boxes
            return number
        } else {
            guard let (number, boxes) = OcrDDUtils.sortAndRemoveFalsePositives(allBoxes: DetectedOcrBoxes) else { return nil }
            self.lastDetectedBoxes = boxes
            return number
        }
        
        
    }

    public mutating func predict(image: UIImage) -> String? {
        
        SSDOcrDetect.initializeModels()
        guard let pixelBuffer = image.pixelBuffer(width: ssdOcrImageWidth,
                                                  height: ssdOcrImageHeight)
        else {
            print("Couldn't convert to pixel buffer")
            return nil
                                                    
        }
        
        guard let ocrDetectModel = ssdOcrModel else {
            if !SSDOcrDetect.hasPrintedInitError {
                print("Ocr Model not initialized")
                SSDOcrDetect.hasPrintedInitError = true
            }
            return nil
        }
        
        let input = SSDOcrInput(_0: pixelBuffer)
        
        guard let prediction = try? ocrDetectModel.prediction(input: input) else {
            print("Ocr Couldn't predict")
            return nil
        }
        return self.detectOcrObjects(prediction: prediction, image: image)
    }
    
    
    /**
     * A utitliy struct that applies non-max supression to each class
     * picks out the remaining boxes, the class probabilities for classes
     * that are kept and composes all the information in one place to be returned as
     * an object.
     */
    func predictionUtil(scores: [[Float]], boxes: [[Float]], probThreshold: Float,
                       iouThreshold: Float, candidateSize: Int , topK: Int) -> Result{
        var pickedBoxes = [[Float]]()
        var pickedLabels = [Int]()
        var pickedBoxProbs = [Float]()
        
        
        for classIndex in 0..<scores[0].count{
            var probs = [Float]()
            var subsetBoxes = [[Float]]()
            
            for rowIndex in 0..<scores.count{
                if scores[rowIndex][classIndex] > probThreshold{
                    probs.append(scores[rowIndex][classIndex])
                    subsetBoxes.append(boxes[rowIndex])
                }
            }
            
            if probs.count == 0{
                continue
            }
            
            var _pickedBoxes = [[Float]]()
            var _pickedScores = [Float]()

            (_pickedBoxes, _pickedScores) = SoftNMS.softNMS(subsetBoxes: subsetBoxes, probs: probs,
                                                            probThreshold: probThreshold, sigma: SSDOcrDetect.sigma, topK: topK,
                                                            candidateSize: candidateSize)

            for idx in 0..<_pickedScores.count{
                pickedBoxProbs.append(_pickedScores[idx])
                pickedBoxes.append(_pickedBoxes[idx])
                pickedLabels.append((classIndex + 1) % 10)
            }
        
        }
        var result: Result = Result()
        result.pickedBoxProbs =  pickedBoxProbs
        result.pickedLabels = pickedLabels
        result.pickedBoxes = pickedBoxes
        
        return result
        
    }
    
}
