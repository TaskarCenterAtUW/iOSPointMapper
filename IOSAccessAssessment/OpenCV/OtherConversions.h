//
//  OtherConversions.hpp
//  IOSAccessAssessment
//
//  Created by Himanshu on 2/21/25.
//

#ifdef __cplusplus
#undef NO
#undef YES

/*
 Importing only the needed features can mitigate against build issues with other parts of openCV
 FIXME: These are the wrong imports
 */
#import <opencv2/stitching.hpp>
#import <opencv2/imgcodecs.hpp>

#endif

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
@interface OtherConversions : NSObject

+ (NSArray<NSArray<NSValue *> *> *)cvContoursToNSArray:(const std::vector<std::vector<cv::Point>> &)contours;

/**
    Convert cv::Vec3b to NSArray<NSValue *>.
    FIXME: This method is not generic and should be refactored.
 */
+ (NSArray<NSValue *> *)convertVec3bArray:(const std::vector<cv::Vec3b> &)vecArray;

@end
