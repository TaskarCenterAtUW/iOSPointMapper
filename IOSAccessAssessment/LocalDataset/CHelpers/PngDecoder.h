//
//  PngDecoder.h
//  IOSAccessAssessment
//
//  Created by Himanshu on 2/18/26.
//

#ifndef PngDecoder_h
#define PngDecoder_h
#include <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface PngDecoder : NSObject

- (instancetype) initWithContentsOfFile:(NSData*)fileContents;
- (NSData * _Nullable)depthDataWithWidth:(int *)width
                                  height:(int *)height;

@end
NS_ASSUME_NONNULL_END
#endif /* PngDecoder_h */
