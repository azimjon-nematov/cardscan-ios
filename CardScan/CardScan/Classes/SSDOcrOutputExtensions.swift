//
//  SSDOcrOutputExtensions.swift
//  CardScan
//
//  Created by xaen on 3/22/20.
//

import Foundation
import Accelerate

@available(iOS 11.2, *)
extension SSDOcrOutput {
    
    func getScores(filterThreshold: Float) -> ([[Float]], [[Float]], [Float]) {
        let pointerScores
            = UnsafeMutablePointer<Float>(OpaquePointer(self.scores.dataPointer))
        let pointerBoxes
            = UnsafeMutablePointer<Float>(OpaquePointer(self.boxes.dataPointer))
        let pointerFilter
            = UnsafeMutablePointer<Float>(OpaquePointer(self.filter.dataPointer))
        
        let numOfRowsScores = self.scores.shape[3].intValue
        let numOfColsScores = self.scores.shape[4].intValue
        
        var scoresTest = [[Float]](
            repeating: [Float](
                repeating: 0.0,
                count: numOfColsScores
            ),
            count: numOfRowsScores
        )
        
        let numOfRowsBoxes = self.boxes.shape[3].intValue
        let numOfColsBoxes = self.boxes.shape[4].intValue
        
        var boxesTest = [[Float]](
            repeating: [Float](
                repeating: 0.0,
                count: numOfColsBoxes
            ),
            count: numOfRowsBoxes
        )
        
        var filterArray = [Float](
            repeating: 0.0,
            count: numOfRowsScores
        )
       
        for idx3 in 0..<self.filter.count {
           let offsetFilter = idx3 * self.filter.strides[4].intValue
           filterArray[idx3] = Float(pointerFilter[offsetFilter])
       }

        var countScores = 0
        var countBoxes = 0
        
        for idx2 in 0..<self.filter.count {
            if filterArray[idx2] > filterThreshold {

                for idx in countScores..<countScores + numOfColsScores {
                    let offset = idx * self.scores.strides[4].intValue
                    scoresTest[idx/numOfColsScores][idx%numOfColsScores]
                        = Float(pointerScores[offset])
                    }
                countScores = countScores + numOfColsScores

                for idx in countBoxes..<countBoxes + numOfColsBoxes {
                    let offset = idx * self.boxes.strides[4].intValue
                    boxesTest[idx/numOfColsBoxes][idx%numOfColsBoxes]
                        = Float(pointerBoxes[offset])
                }
                countBoxes = countBoxes + numOfColsBoxes
            }
            else {
                countScores = countScores + numOfColsScores
                countBoxes = countBoxes + numOfColsBoxes
            }
        }
        return (scoresTest, boxesTest, filterArray)
    }
    
    func convertLocationsToBoxes(
        locations: [[Float]],
        priors: [CGRect],
        centerVariance: Float,
        sizeVariance : Float
    ) -> [[Float]] {
        
        /** Convert regressional location results of
         SSD into boxes in the form of (center_x, center_y, h, w)
         */
        var boxes = [[Float]]()
        
        for i in 0..<locations.count {
            let box = [
                locations[i][0] * centerVariance * Float(priors[i].width) + Float(priors[i].minX),
                locations[i][1] * centerVariance * Float(priors[i].height) + Float(priors[i].minY),
                exp(locations[i][2] * sizeVariance) * Float(priors[i].width),
                exp(locations[i][3] * sizeVariance) * Float(priors[i].height)
            ]
            boxes.append(box)
        }
        return boxes
    }
   
    func filterScoresAndBoxes(
        scores: [[Float]],
        boxes: [[Float]],
        filterArray: [Float],
        filterThreshold: Float
    ) -> ([[Float]], [[Float]]) {
        
        var prunnedScores = [[Float]]()
        var prunnedBoxes = [[Float]]()
        
        for i in 0..<filterArray.count {
            if filterArray[i] > filterThreshold{
                prunnedScores.append(scores[i])
                prunnedBoxes.append(boxes[i])
            }
        }
        return (prunnedScores, prunnedBoxes)
    }
}
