//
//  OtherConversions.hpp
//  IOSAccessAssessment
//
//  Created by Himanshu on 2/21/25.
//

#ifdef __cplusplus
#import <vector>
#import <opencv2/core.hpp>       // Core structures (cv::Mat, cv::Point, cv::Vec3b)
#import <opencv2/imgproc.hpp>    // Image processing (contours, morphology, etc.)
#endif

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
@interface OtherConversions : NSObject

+ (NSArray<NSArray<NSValue *> *> *)cvContoursToNSArray:(const std::vector<std::vector<cv::Point>> &)contours;

+ (std::vector<cv::Point>)convertNSArrayToCvPoints:(NSArray<NSArray<NSValue *> *> *)points;

/**
    Convert cv::Vec3b to NSArray<NSValue *>.
    FIXME: This method is not generic and should be refactored.
 */
+ (NSArray<NSValue *> *)convertVec3bArray:(const std::vector<cv::Vec3b> &)vecArray;

+ (std::vector<cv::Vec3b>)convertNSArrayToVec3bArray:(NSArray<NSValue *> *)array;

@end
