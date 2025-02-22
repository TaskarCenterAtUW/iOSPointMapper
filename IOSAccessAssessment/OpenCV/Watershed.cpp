//
//  Watershed.cpp
//  IOSAccessAssessment
//
//  Created by Himanshu on 2/16/25.
//

#include "Watershed.h"
#include <iostream>
#include <fstream>

cv::Mat watershed1DMaskAndDepth (cv::Mat mask, cv::Mat depth, int labelValue) {
    // Remove the alpha channel from the mask image
    cv::cvtColor(mask, mask, cv::COLOR_BGRA2BGR);
    
    // Remove all the other classes and the background from the mask
    cv::Mat bg_mask;
    cv::Scalar lowerBounds = cv::Scalar(labelValue - 3, labelValue - 3, labelValue - 3);
    cv::Scalar upperBounds = cv::Scalar(labelValue + 3, labelValue + 3, labelValue + 3);
    cv::inRange(mask, lowerBounds, upperBounds, bg_mask);
    cv::Mat bg_mask_inv;
    cv::bitwise_not(bg_mask, bg_mask_inv);
    mask.setTo(cv::Scalar(0, 0, 0), bg_mask_inv);
    
    // Erase borders from the mask
    cv::Mat maskEroded = eraseBorders(mask, 2);
    mask = maskEroded;
    
    // First, we need to compute the Laplacian of the depth map, to get the edges.
    cv::Mat kernel = (cv::Mat_<float>(3,3) << 1,  1, 1, 1, -8, 1, 1,  1, 1);
    cv::Mat imgLaplacian;
    cv::filter2D(mask, imgLaplacian, CV_32F, kernel);
    cv::Mat sharp;
    mask.convertTo(sharp, CV_32F);
    cv::Mat imgResult = sharp - imgLaplacian;

    // convert back to 8bits gray scale
    imgResult.convertTo(imgResult, CV_8UC3);
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
    
    // Create the CV_8U version of the distance image
    // It is needed for findContours()
    cv::Mat dist_8u;
    dist.convertTo(dist_8u, CV_8U);
 
    // Find total markers
    std::vector<std::vector<cv::Point> > contours;
    cv::findContours(dist_8u, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
    
    // Create the marker image for the watershed algorithm
    cv::Mat markers = cv::Mat::zeros(dist.size(), CV_32SC1);
    
    // Draw the foreground markers
    for (size_t i = 0; i < contours.size(); i++)
    {
        cv::drawContours(markers, contours, static_cast<int>(i), cv::Scalar(static_cast<int>(i)+1), -1);
    }
    
    // Draw the background marker
    cv::circle(markers, cv::Point(5,5), 3, cv::Scalar(255), -1);

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
    
    return makeBackgroundTransparent(dst, cv::Scalar(0, 0, 0, 255));
//    return dst;
}

/**
    This function erases the borders of the mask by a certain amount.
 */
cv::Mat eraseBorders (cv::Mat mat, int borderSize) {
    cv::Mat borderMask = cv::Mat::ones(mat.size(), CV_8UC1) * 255;
    
    // Set the mask borders to 0
    borderMask(cv::Rect(0, 0, borderMask.cols, borderSize)).setTo(0);
    borderMask(cv::Rect(0, borderMask.rows - borderSize, borderMask.cols, borderSize)).setTo(0);
    borderMask(cv::Rect(0, 0, borderSize, borderMask.rows)).setTo(0);
    borderMask(cv::Rect(borderMask.cols - borderSize, 0, borderSize, borderMask.rows)).setTo(0);
    
    cv::Mat output = cv::Mat::zeros(mat.size(), mat.type());
    mat.copyTo(output, borderMask);
    
    return output;
}

/**
    This function makes the background alpha channel of the image to 0.
 */
cv::Mat makeBackgroundTransparent (cv::Mat mat, cv::Scalar backgroundColor) {
    // If the image has 3 channels, we need to convert it to 4 channels
    if (mat.channels() == 3) {
        cv::cvtColor(mat, mat, cv::COLOR_BGR2BGRA);
    }
    
    // Create a mask of all the pixels that are not the background color
    cv::Mat mask;
    cv::inRange(mat, backgroundColor, backgroundColor, mask);
    cv::bitwise_not(mask, mask);
    
    // Create a transparent mat, and copy the image to it with the mask
    cv::Mat transparentMat = cv::Mat::zeros(mat.size(), mat.type());
    mat.copyTo(transparentMat, mask);
    
    return transparentMat;
}
    
