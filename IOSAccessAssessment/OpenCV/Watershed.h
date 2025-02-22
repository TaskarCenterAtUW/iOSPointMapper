//
//  Watershed.hpp
//  IOSAccessAssessment
//
//  Created by Himanshu on 2/16/25.
//

#ifndef Watershed_hpp
#define Watershed_hpp
#include <opencv2/opencv.hpp>

cv::Mat watershed1DMaskAndDepth (cv::Mat mask, cv::Mat depth, int labelValue);

cv::Mat eraseBorders (cv::Mat mask, int borderSize);

cv::Mat makeBackgroundTransparent (cv::Mat mat, cv::Scalar backgroundColor);

std::tuple<cv::Mat, std::vector<std::vector<cv::Point>>, std::vector<cv::Vec3b>>
watershed1DMaskAndDepthAndReturnContoursColors (cv::Mat mask, cv::Mat depth, int labelValue);

#endif /* Watershed_hpp */
