//
//  OpenCVWrapper.m
//  IOSAccessAssessment
//
//  Created by Himanshu on 2/12/25.
//

#import "OpenCVWrapper.h"
#import "UIImage+OpenCV.h"
#import "OtherConversions.hpp"
#import "Watershed.hpp"
#import <iostream>

@implementation WatershedResult

- (instancetype)initWithImage:(UIImage *)image
                     contours:(NSArray<NSArray<NSValue *> *> *)contours
                       colors:(NSArray<NSValue *> *)colors {
    self = [super init];
    if (self) {
        _image = image;
        _contours = contours;
        _colors = colors;
    }
    return self;
}

@end

@implementation OpenCVWrapper

+ (UIImage *)perform1DWatershed:(UIImage*)maskImage
                               depthImage:(UIImage*)depthImage
                               labelValue:(int)labelValue {
    cv::Mat maskMat = [maskImage CVMat];
    cv::Mat depthMat = [depthImage CVMat];
    
    cv::Mat outputMat = watershed1DMaskAndDepth(maskMat, depthMat, labelValue);
    return [UIImage imageWithCVMat:outputMat];
}

+ (WatershedResult *)perform1DWatershedWithContoursColors:(UIImage*)maskImage
                                                         depthImage:(UIImage*)depthImage
                                                         labelValue:(int)labelValue {
    cv::Mat maskMat = [maskImage CVMat];
    cv::Mat depthMat = [depthImage CVMat];
    
    std::tuple<cv::Mat, std::vector<std::vector<cv::Point>>, std::vector<cv::Vec3b>> output = watershed1DMaskAndDepthAndReturnContoursColors(maskMat, depthMat, labelValue);
    cv::Mat outputMat = std::get<0>(output);
    std::vector<std::vector<cv::Point>> contours = std::get<1>(output);
    std::vector<cv::Vec3b> colors = std::get<2>(output);
    
    UIImage *image = [UIImage imageWithCVMat:outputMat];
    NSArray<NSArray<NSValue *> *> *convertedContours = [OtherConversions convertContoursToNSValue:contours];
    NSArray<NSValue *> *convertedColors = [OtherConversions convertColorsToNSValue:colors];

    // Create and return an instance of WatershedResult
    return [[WatershedResult alloc] initWithImage:image contours:convertedContours colors:convertedColors];
}

@end
