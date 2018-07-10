//
//  NonMaxSuppression.swift
//  SummerHolidayProject
//
//  Created by Darko on 2018/7/4.
//  Copyright © 2018年 Darko. All rights reserved.
//

import Foundation
import UIKit
import CoreML
import Accelerate

/**
 Computes intersection-over-union overlap between two bounding boxes.
 */
public func IOU(_ a: CGRect, _ b: CGRect) -> Float {
    let areaA = a.width * a.height
    if areaA <= 0 { return 0 }
    
    let areaB = b.width * b.height
    if areaB <= 0 { return 0 }
    
    let intersectionMinX = max(a.minX, b.minX)
    let intersectionMinY = max(a.minY, b.minY)
    let intersectionMaxX = min(a.maxX, b.maxX)
    let intersectionMaxY = min(a.maxY, b.maxY)
    let intersectionArea = max(intersectionMaxY - intersectionMinY, 0) *
                           max(intersectionMaxX - intersectionMinX, 0)
    return Float(intersectionArea / (areaA + areaB - intersectionArea))
}

public typealias NMSPrediction = (classIndex: Int, score: Float, rect: CGRect)

/**
 Removes bounding boxes that overlap too much with other boxes that have
 a higher score.
 */
public func nonMaxSuppression(predictions: [NMSPrediction], iouThreshold: Float, maxBoxes: Int) -> [Int] {
    return nonMaxSuppression(predictions: predictions, indices: Array(predictions.indices), iouThreshold: iouThreshold, maxBoxes: maxBoxes)
}

/**
 Removes bounding boxes that overlap too much with other boxes that have
 a higher score.
 
 - Note: This version of NMS ignores the class of the bounding boxes. Since it
 selects the bounding boxes in a greedy fashion, if a certain class has many
 boxes that are selected, then it is possible none of the boxes of the other
 classes get selected.
 
 - Parameters:
     - predictions: an array of bounding boxes and their scores.
     - indices: which predictions to look at
     - iouThreshold: used to decide whether boxes overlap too much
     - maxBoxes: the maximum number of boxes that will be selected
 
 - Returns: the array indices of the selected bounding boxes
 */
public func nonMaxSuppression(predictions: [NMSPrediction],
                              indices: [Int],
                              iouThreshold: Float,
                              maxBoxes: Int) -> [Int] {
    
    // Sort the boxes based on their confidence scores, from high to low.
    let sortedIndices = indices.sorted { predictions[$0].score > predictions[$1].score }
    
    var selected: [Int] = []
    
    // Loop through the bounding boxes, from highest score to lowest score
    // and determine whether or not to keep each box.
    for i in 0..<sortedIndices.count {
        if selected.count >= maxBoxes { break }
        
        var shouldSelect = true
        let boxA = predictions[sortedIndices[i]]
        
        // Does the current box overlap one of the selected boxes more than the
        // given threshold amount? Then it's too similar, so don't keep it.
        for j in 0..<selected.count {
            let boxB = predictions[selected[j]]
            if IOU(boxA.rect, boxB.rect) > iouThreshold {
                shouldSelect = false
                break
            }
        }
        
        // This bounding box did not overlap too much with any previously selected
        // bounding box, so we'll keep it.
        if shouldSelect {
            selected.append(sortedIndices[i])
        }
    }
    
    return selected
}

/**
 Multi-class version of non maximum suppression.
 
 Where `nonMaxSuppression()` does not look at the class of the predictions at all,
 the multi-class version first selects the best bounding boxes for each class,
 and then keeps the best ones of those.
 
 With this method you can usually expect to see at least one bounding box for each
 class (unless all the scores for a given class are really low).
 
 - Parameters:
     - numClasses: the number of classes
     - predictions: an array of bounding boxes and their scores
     - scoreThreshold: used to only keep bounding boxes with a high enough score
     - iouThreshold: used to decide whether boxes overlap too much
     - maxPerClass: the maximum number of boxes that will be selected per class
     - maxTotal: maximum number of boxes that will be selected over all classes
 
 - Returns: the array indices of the selected bounding boxes
 */
public func nonMaxSuppressionMultiClass(numClasses: Int, predictions: [NMSPrediction], scoreThreshold: Float, iouThreshold: Float, maxPerClass: Int, maxTotal: Int) -> [Int] {
    
    var selectedBoxes: [Int] = []
    
    // Look at all the classes one-by-one.
    for c in 0..<numClasses {
        var filteredBoxes = [Int]()
        
        // Look at every bounding boxe for this class
        for p in 0..<predictions.count {
            let prediction = predictions[p]
            if prediction.classIndex == c {
                // Only keep the box if its score is over the threshold
                if prediction.score > scoreThreshold {
                    filteredBoxes.append(p)
                }
            }
        }
        
        // Only keep the best bounding boxes for this class.
        let nmsBoxes = nonMaxSuppression(predictions: predictions, indices: filteredBoxes, iouThreshold: iouThreshold, maxBoxes: maxPerClass)
        
        // Add the indices of the surviving boxes to the big list
        selectedBoxes.append(contentsOf: nmsBoxes)
    }
    
    // Sort all the surviving boxes by score and only keep the best ones
    let sortedBoxes = selectedBoxes.sorted { predictions[$0].score > predictions[$1].score }
    return Array(sortedBoxes.prefix(maxTotal))
}
