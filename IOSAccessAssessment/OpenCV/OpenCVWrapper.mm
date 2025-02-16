//
//  OpenCVWrapper.m
//  IOSAccessAssessment
//
//  Created by Himanshu on 2/12/25.
//

#import "OpenCVWrapper.h"
#import "UIImage+OpenCV.h"

@implementation OpenCVWrapper

+ (UIImage *)grayScaleImageConversion:(UIImage*)inputImage {
    cv::Mat mat = [inputImage CVMat];
        
    // Convert to grayscale
    cv::cvtColor(mat, mat, cv::COLOR_BGR2GRAY);
        
    return [UIImage imageWithCVMat:mat];
}

@end
