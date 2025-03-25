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

@end
