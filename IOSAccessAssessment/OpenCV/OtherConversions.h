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

+ (std::tuple<int, int>) CVPointToTuple:(cv::Point)point;

+ (cv::Point) TupleToCVPoint:(std::tuple<int, int>)tuple;

+ (std::tuple<int, int, int>) CVVec3bToTuple:(cv::Vec3b)vec;

+ (cv::Vec3b) TupleToCVVec3b:(std::tuple<int, int, int>)tuple;

@end
