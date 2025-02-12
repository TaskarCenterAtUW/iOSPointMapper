//
//  OpenCVWrapper.h
//  IOSAccessAssessment
//
//  Created by Himanshu on 2/12/25.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OpenCVWrapper : NSObject

    + (UIImage *)processImageWithOpenCV:(UIImage*)inputImage;

@end

NS_ASSUME_NONNULL_END
