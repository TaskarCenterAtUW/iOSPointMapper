//
//  UIImage+OpenCV.cpp
//  IOSAccessAssessment
//
//  Created by Himanshu on 2/14/25.
//

#include "UIImage+OpenCV.h"

@implementation UIImage (OpenCV)

/**
    Convert UIImage to cv::Mat
 
    The following TODO task is to address the issue where the bitmap info is being hard-coded to only serve segmentation masks. We need to make it more generic.
    TODO: Later, we would like to use the attributes of the UIImage, such as bitmap data, color space, and alpha channel to create a cv::Mat object.
        
 */
-(cv::Mat)CVMat
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(self.CGImage);
    if (!colorSpace) {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    CGFloat cols = self.size.width;
    CGFloat rows = self.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to  data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaPremultipliedLast |
                                                    kCGImageByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), self.CGImage);
    CGContextRelease(contextRef);
    
    return cvMat;
}

- (cv::Mat)CVMat3
{
    cv::Mat result = [self CVMat];
    cv::cvtColor(result , result , cv::COLOR_RGBA2RGB);
    return result;

}

-(cv::Mat)CVGrayscaleMat
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    CGFloat cols = self.size.width;
    CGFloat rows = self.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC1); // 8 bits per component, 1 channels
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGImageByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), self.CGImage);
    CGContextRelease(contextRef);
    CGColorSpaceRelease(colorSpace);
    
    return cvMat;
}

+ (UIImage *)imageWithCVMat:(const cv::Mat&)cvMat
{
    return [[UIImage alloc] initWithCVMat:cvMat];
}

/**
    Convert cv::Mat to UIImage
 
    The following TODO task is to address the issue where the bitmap info is being hard-coded to only serve segmentation masks with fixed bitmap info and other parameters.
    We need to make it more generic.
    TODO: Later, we would like to use the attributes of the UIImage, such as bitmap data, color space, and alpha channel to create a cv::Mat object.
        
 */
- (id)initWithCVMat:(const cv::Mat&)cvMat
{
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize() * cvMat.total()];
    CGColorSpaceRef colorSpace;
    CGBitmapInfo bitmapInfo = kCGImageAlphaNone|kCGImageByteOrderDefault;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else if (cvMat.elemSize() == 3) {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    } else { // Assuming 4 channels
        colorSpace = CGColorSpaceCreateDeviceRGB();
        bitmapInfo = kCGImageAlphaLast|kCGImageByteOrderDefault;
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);

        // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                 //width
                                        cvMat.rows,                                 //height
                                        8,                                          //bits per component
                                        8 * cvMat.elemSize(),                       //bits per pixel
                                        cvMat.step[0],                              //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        bitmapInfo,                                 // bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );
    
        // Getting UIImage from CGImage
    self = [self initWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return self;
}

@end
