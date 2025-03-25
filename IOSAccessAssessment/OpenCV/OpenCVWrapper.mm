//
//  OpenCVWrapper.m
//  IOSAccessAssessment
//
//  Created by Himanshu on 2/12/25.
//

#import "OpenCVWrapper.h"
#import "UIImage+OpenCV.h"
#import "OtherConversions.h"
#import "Watershed.h"
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

+ (UIImage *)grayScaleImageConversion:(UIImage*)inputImage {
    cv::Mat mat = [inputImage CVMat];
    
    cv::cvtColor(mat, mat, cv::COLOR_BGR2GRAY);
    
    return [UIImage imageWithCVMat:mat];
}

/**
 Convert the image to gray scale and then create an RGB image with all channels set to the gray value, and retain the alpha channel.
 */
+ (UIImage *)grayImageConversion:(UIImage*)inputImage {
    cv::Mat mat = [inputImage CVMat];
    
    cv::Mat grayMat, outputMat;
    std::vector<cv::Mat> channels(4);
    
    // Convert BGR (ignoring alpha) to Grayscale
    cv::cvtColor(mat, grayMat, cv::COLOR_BGRA2GRAY);
    
    // Split the original image into separate channels (B, G, R, A)
    cv::split(mat, channels);
    
    cv::Mat alphaChannel = channels[3];
    int zeroCounts = 0;
    for (int i = 0; i < alphaChannel.rows; i++) {
        for (int j = 0; j < alphaChannel.cols; j++) {
            if (alphaChannel.at<uchar>(i, j) == 0) {
                zeroCounts++;
            }
        }
    }
    std::cout << "Count of zero alpha pixels: " << zeroCounts << std::endl;
    
    // Replace B, G, R channels with grayscale values
    channels[0] = grayMat.clone(); // B
    channels[1] = grayMat.clone(); // G
    channels[2] = grayMat.clone(); // R
    
    // Merge channels back to an RGBA image
    cv::merge(channels, outputMat);
    
    return [UIImage imageWithCVMat:outputMat];
}

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
    
    // Convert Vector of Vectors of cv::Point to NSArray of NSValue of CGPoint
    // FIXME: Move this logic to a separate conversions file
    NSMutableArray<NSMutableArray<NSValue *> *> *convertedContours = [NSMutableArray array];
    for (const std::vector<cv::Point> &contour : contours) {
        NSMutableArray<NSValue *> *convertedContour = [NSMutableArray array];

        for (const cv::Point &point : contour) {
            CGPoint cgPoint = CGPointMake(point.x, point.y);
            [convertedContour addObject:[NSValue valueWithCGPoint:cgPoint]];
        }
        [convertedContours addObject:convertedContour];
    }
    
    // Convert Vector of cv::Vec3b to NSArray of NSValue of UInt8[3]
    // FIXME: Move this logic to a separate conversions file
    NSMutableArray<NSValue *> *convertedVec3bArray = [NSMutableArray array];
    for (const cv::Vec3b &vec : colors) {
        // Convert cv::Vec3b to an array of 3 UInt8 values
        uint8_t values[3] = {vec[0], vec[1], vec[2]};
        [convertedVec3bArray addObject:[NSValue valueWithBytes:&values objCType:@encode(uint8_t[3])]];
    }
    
    // Create and return an instance of WatershedResult
    return [[WatershedResult alloc] initWithImage:image contours:convertedContours colors:convertedVec3bArray];
    
//    return [UIImage imageWithCVMat:outputMat];
}


+ (UIImage *)setAlphaForPixel:(UIImage*)inputImage {
    cv::Mat mat = [inputImage CVMat];
    if (mat.channels() == 3) {
        cv::cvtColor(mat, mat, cv::COLOR_BGR2BGRA);
    }
    
    // Set alpha for pixel
    int countOfBlackPixels = 0;
    int countOfNonBlackPixels = 0;
    for (int i = 0; i < mat.rows; i++) {
        for (int j = 0; j < mat.cols; j++) {
            cv::Vec4b pixel = mat.at<cv::Vec4b>(i, j);
            if (pixel[0] == 0 && pixel[1] == 0 && pixel[2] == 0) {
                pixel[3] = 0;
                countOfBlackPixels++;
            }
            else {
                countOfNonBlackPixels++;
            }
        }
    }
    std::cout << "Count of black pixels: " << countOfBlackPixels << std::endl;
    std::cout << "Count of non-black pixels: " << countOfNonBlackPixels << std::endl;
    
    return [UIImage imageWithCVMat:mat];
}


@end
