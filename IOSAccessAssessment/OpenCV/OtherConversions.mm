//
//  OtherConversions.cpp
//  IOSAccessAssessment
//
//  Created by Himanshu on 2/21/25.
//

#include "OtherConversions.h"
#import <iostream>

@implementation OtherConversions

+ (NSArray<NSArray<NSValue *> *> *)cvContoursToNSArray:(const std::vector<std::vector<cv::Point>> &)contours {
    NSMutableArray<NSMutableArray<NSValue *> *> *convertedContours = [NSMutableArray array];
    
    for (const std::vector<cv::Point> &contour : contours) {
        NSMutableArray<NSValue *> *convertedContour = [NSMutableArray array];
        
        for (const cv::Point &point : contour) {
            CGPoint cgPoint = CGPointMake(point.x, point.y);
            [convertedContour addObject:[NSValue valueWithCGPoint:cgPoint]];
        }
        [convertedContours addObject:convertedContour];
    }
    return convertedContours;
}

+ (std::vector<cv::Point>)convertNSArrayToCvPoints:(NSArray<NSArray<NSValue *> *> *)points {
    std::vector<cv::Point> convertedPoints;
    
    for (NSArray<NSValue *> *pointArray in points) {
        for (NSValue *pointValue in pointArray) {
            CGPoint cgPoint = [pointValue CGPointValue];
            cv::Point point = cv::Point(cgPoint.x, cgPoint.y);
            convertedPoints.push_back(point);
        }
    }
    return convertedPoints;
}


+ (NSArray<NSValue *> *)convertVec3bArray:(const std::vector<cv::Vec3b> &)vecArray {
    NSMutableArray<NSValue *> *convertedVec3bArray = [NSMutableArray array];
    
    for (const cv::Vec3b &vec : vecArray) {
        // Convert cv::Vec3b to an array of 3 UInt8 values
        uint8_t values[3] = {vec[0], vec[1], vec[2]};
        [convertedVec3bArray addObject:[NSValue valueWithBytes:&values objCType:@encode(uint8_t[3])]];
    }
    return convertedVec3bArray;
}

+ (std::vector<cv::Vec3b>)convertNSArrayToVec3bArray:(NSArray<NSValue *> *)array {
    std::vector<cv::Vec3b> convertedVec3bArray;
    
    for (NSValue *value in array) {
        uint8_t values[3];
        [value getValue:&values];
        
        cv::Vec3b vec(values[0], values[1], values[2]);
        convertedVec3bArray.push_back(vec);
    }
    
    return convertedVec3bArray;
}

@end
