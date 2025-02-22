//
//  UIImage+OpenCV.hpp
//  IOSAccessAssessment
//
//  Created by Himanshu on 2/14/25.
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
@interface UIImage (OpenCV)

    //cv::Mat to UIImage
+ (UIImage *)imageWithCVMat:(const cv::Mat&)cvMat;
- (id)initWithCVMat:(const cv::Mat&)cvMat;

    //UIImage to cv::Mat
- (cv::Mat)CVMat;
- (cv::Mat)CVMat3;  // no alpha channel
- (cv::Mat)CVGrayscaleMat;

@end
