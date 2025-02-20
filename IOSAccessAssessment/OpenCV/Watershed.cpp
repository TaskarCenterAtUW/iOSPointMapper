//
//  Watershed.cpp
//  IOSAccessAssessment
//
//  Created by Himanshu on 2/16/25.
//

#include "Watershed.h"
#include <iostream>
#include <fstream>

cv::Mat watershedMaskAndDepth (cv::Mat mask, cv::Mat depth) {
    std::cout << "Type of mask: " << mask.type() << std::endl;
    // Remove the alpha channel from the mask image
    cv::cvtColor(mask, mask, cv::COLOR_BGRA2BGR);
    std::cout << "Type of mask: " << mask.type() << std::endl;
    
    cv::Mat bg_mask;
    cv::inRange(mask, cv::Scalar(255, 255, 255), cv::Scalar(255, 255, 255), bg_mask);
    mask.setTo(cv::Scalar(0, 0, 0), bg_mask);
    
    // First, we need to compute the Laplacian of the depth map, to get the edges.
    cv::Mat kernel = (cv::Mat_<float>(3,3) << 1,  1, 1, 1, -8, 1, 1,  1, 1);
    cv::Mat imgLaplacian;
    cv::filter2D(mask, imgLaplacian, CV_32F, kernel);
    cv::Mat sharp;
    mask.convertTo(sharp, CV_32F);
    cv::Mat imgResult = sharp - imgLaplacian;

    std::cout << "Type of imgResult: " << imgResult.type() << std::endl;
    // convert back to 8bits gray scale
    imgResult.convertTo(imgResult, CV_8UC3);
    std::cout << "Type of imgResult: " << imgResult.type() << std::endl;
    imgLaplacian.convertTo(imgLaplacian, CV_8UC3);
    
    cv::Mat bw;
    cv::cvtColor(imgResult, bw, cv::COLOR_BGR2GRAY);
    cv::threshold(bw, bw, 0, 255, cv::THRESH_BINARY | cv::THRESH_OTSU);
    
    // Perform the distance transform algorithm
    cv::Mat dist;
    cv::distanceTransform(bw, dist, cv::DIST_L2, 3);
    
    // Normalize the distance image for range = {0.0, 1.0}
    // so we can visualize and threshold it
    cv::normalize(dist, dist, 0, 1.0, cv::NORM_MINMAX);
    
    // Threshold to obtain the peaks
    // This will be the markers for the foreground objects
    cv::threshold(dist, dist, 0.4, 1.0, cv::THRESH_BINARY);
    
    // Dilate the dist image
    cv::Mat kernel1 = cv::Mat::ones(3, 3, CV_8U);
    cv::dilate(dist, dist, kernel1);
    std::cout << "Type of dist: " << dist.type() << std::endl;
    
    // Create the CV_8U version of the distance image
    // It is needed for findContours()
    cv::Mat dist_8u;
    dist.convertTo(dist_8u, CV_8U);
    std::cout << "Type of dist_8u: " << dist_8u.type() << std::endl;
 
    // Find total markers
    std::vector<std::vector<cv::Point> > contours;
    cv::findContours(dist_8u, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
    std::cout << "Contours found: " << contours.size() << std::endl;
    
    // Create the marker image for the watershed algorithm
    cv::Mat markers = cv::Mat::zeros(dist.size(), CV_32SC1);
    
    // Draw the foreground markers
    for (size_t i = 0; i < contours.size(); i++)
    {
        cv::drawContours(markers, contours, static_cast<int>(i), cv::Scalar(static_cast<int>(i)+1), -1);
    }
    
    // Draw the background marker
    cv::circle(markers, cv::Point(5,5), 3, cv::Scalar(255), -1);
    std::cout << "Type of markers: " << markers.type() << std::endl;

    // Perform the watershed algorithm
    cv::watershed(imgResult, markers);
    
    // Generate random colors
    std::vector<cv::Vec3b> colors;
    for (size_t i = 0; i < contours.size(); i++)
    {
        int b = cv::theRNG().uniform(0, 256);
        int g = cv::theRNG().uniform(0, 256);
        int r = cv::theRNG().uniform(0, 256);
 
        colors.push_back(cv::Vec3b((uchar)b, (uchar)g, (uchar)r));
    }
    
    // Create the result image
    cv::Mat dst = cv::Mat::zeros(markers.size(), CV_8UC3);
 
//    // Fill labeled objects with random colors
    int i1 = -1;
    int j1 = -1;
    for (int i = 0; i < markers.rows; i++)
    {
        for (int j = 0; j < markers.cols; j++)
        {
            int index = markers.at<int>(i,j);
            if (index > 0 && index <= static_cast<int>(contours.size()))
            {
                dst.at<cv::Vec3b>(i,j) = colors[index-1];
                if ((i1 == -1) && (j1 == -1)) {
                    i1 = i;
                    j1 = j;
                }
            }
        }
    }
    
    std::cout << "dst size: " << dst.size() << ", type: " << dst.type() << std::endl;
    std::cout << "Value at i1 and j1: " << dst.at<cv::Vec3b>(i1, j1) << std::endl;
    std::cout << "Watershed done" << std::endl;
    
    return dst;
}
