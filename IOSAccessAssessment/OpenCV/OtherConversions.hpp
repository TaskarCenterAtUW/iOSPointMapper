//
//  OtherConversions.hpp
//  IOSAccessAssessment
//
//  Created by Himanshu on 2/22/25.
//

#ifdef __cplusplus
#undef NO
#undef YES

#import <opencv2/imgcodecs.hpp>

#endif

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
/**
    This class is used to handle other types of conversions, that include OpenCV contours, OpenCV colours, etc.
 
    FIXME: The methods of this class are not being detected by the compilers. Hence, the methods have been temporarily added to the OpenCVWrapper class.
 */
@interface OtherConversions: NSObject

+ (NSArray<NSArray<NSValue *> *> *) convertContoursToNSValue:(std::vector<std::vector<cv::Point>>) contours;

+ (NSArray<NSValue *> *) convertColorsToNSValue:(std::vector<cv::Vec3b>) colors;

@end


/* OtherConversions_hpp */
