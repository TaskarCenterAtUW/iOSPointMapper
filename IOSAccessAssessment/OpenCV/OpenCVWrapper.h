//
//  OpenCVWrapper.h
//  IOSAccessAssessment
//
//  Created by Himanshu on 2/12/25.
//

//#include <opencv2/opencv.hpp>

#ifdef __cplusplus
#undef NO
#undef YES

/*
 Importing only the needed features can mitigate against build issues with other parts of openCV
 */
#import <opencv2/imgcodecs.hpp>

#endif

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    UIImage *image;
    NSArray<NSArray<NSValue *> *> *contours;
    NSArray<NSValue *> *colors;
} WatershedResult;

@interface OpenCVWrapper : NSObject

    + (UIImage *)grayScaleImageConversion:(UIImage*)inputImage;

    + (UIImage *)grayImageConversion:(UIImage*)inputImage;

    + (UIImage *)performWatershed:(UIImage*)maskImage:(UIImage*)depthImage;

    + (UIImage *)perfor1DWatershed:(UIImage*)maskImage:(UIImage*)depthImage:(int)labelValue;

    + (WatershedResult)perfor1DWatershedWithContoursColors:(UIImage*)maskImage:(UIImage*)depthImage:(int)labelValue;

    + (UIImage *)setAlphaForPixel:(UIImage*)inputImage;

    /**
        The following methods are used to perform different kinds of conversions.
        These should eventually be moved to the OtherConversions class.
     */
    + (NSArray<NSArray<NSValue *> *> *)cvContoursToNSArray:(const std::vector<std::vector<cv::Point>> &)contours;

    + (NSArray<NSValue *> *)convertVec3bArray:(const std::vector<cv::Vec3b> &)vecArray;

@end

NS_ASSUME_NONNULL_END
