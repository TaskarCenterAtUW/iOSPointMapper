//
//  OtherConversions.cpp
//  IOSAccessAssessment
//
//  Created by Himanshu on 2/21/25.
//

#include "OtherConversions.h"

@implementation OtherConversions

+ (std::tuple<int, int>) CVPointToTuple:(cv::Point)point {
    return std::make_tuple(point.x, point.y);
}

+ (cv::Point) TupleToCVPoint:(std::tuple<int, int>)tuple {
    return cv::Point(std::get<0>(tuple), std::get<1>(tuple));
}

+ (std::tuple<int, int, int>) CVVec3bToTuple:(cv::Vec3b)vec {
    return std::make_tuple(vec[0], vec[1], vec[2]);
}

+ (cv::Vec3b) TupleToCVVec3b:(std::tuple<int, int, int>)tuple {
    return cv::Vec3b(std::get<0>(tuple), std::get<1>(tuple), std::get<2>(tuple));
}

@end
