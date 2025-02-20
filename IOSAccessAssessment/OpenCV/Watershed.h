//
//  Watershed.hpp
//  IOSAccessAssessment
//
//  Created by Himanshu on 2/16/25.
//

#ifndef Watershed_hpp
#define Watershed_hpp
#include <opencv2/opencv.hpp>

cv::Mat watershedMaskAndDepth (cv::Mat mask, cv::Mat depth);

cv::Mat watershed1DMaskAndDepth (cv::Mat mask, cv::Mat depth, int labelValue);

cv::Mat eraseBorders (cv::Mat mask, int borderSize);

#endif /* Watershed_hpp */
