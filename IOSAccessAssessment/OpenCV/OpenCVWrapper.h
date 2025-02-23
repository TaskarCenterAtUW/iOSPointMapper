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
#import <stdio.h>
#import <opencv2/imgcodecs.hpp>

#endif

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WatershedResult : NSObject

@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) NSArray<NSArray<NSValue *> *> *contours;
@property (nonatomic, strong) NSArray<NSValue *> *colors;

- (instancetype)initWithImage:(UIImage *)image
                     contours:(NSArray<NSArray<NSValue *> *> *)contours
                       colors:(NSArray<NSValue *> *)colors;

@end

@interface OpenCVWrapper : NSObject

    + (UIImage *)grayScaleImageConversion:(UIImage*)inputImage;

    + (UIImage *)grayImageConversion:(UIImage*)inputImage;

    + (UIImage *)perform1DWatershed:(UIImage*)maskImage:(UIImage*)depthImage:(int)labelValue;

    + (WatershedResult *)perform1DWatershedWithContoursColors:(UIImage*)maskImage:(UIImage*)depthImage:(int)labelValue;

    + (UIImage *)setAlphaForPixel:(UIImage*)inputImage;

@end

NS_ASSUME_NONNULL_END
