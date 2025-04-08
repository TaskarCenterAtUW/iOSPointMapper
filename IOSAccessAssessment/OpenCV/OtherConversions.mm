//
//  OtherConversions.mm
//  IOSAccessAssessment
//
//  Created by Himanshu on 2/22/25.
//

#include "OtherConversions.hpp"

@implementation OtherConversions

+ (NSArray<NSArray<NSValue *> *> *) convertContoursToNSValue:(std::vector<std::vector<cv::Point>>) contours {
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

+ (NSArray<NSValue *> *) convertColorsToNSValue:(std::vector<cv::Vec3b>) colors {
    NSMutableArray<NSValue *> *convertedVec3bArray = [NSMutableArray array];
    for (const cv::Vec3b &vec : colors) {
        // Convert cv::Vec3b to an array of 3 UInt8 values
        uint8_t values[3] = {vec[0], vec[1], vec[2]};
        [convertedVec3bArray addObject:[NSValue valueWithBytes:&values objCType:@encode(uint8_t[3])]];
    }
    return convertedVec3bArray;
}

@end
