//
//  PngDecoder.mm
//  IOSAccessAssessment
//
//  Created by Himanshu on 2/18/26.
//

#import <Foundation/Foundation.h>
#import "PngDecoder.h"
#import "lodepng.h"
#include <cmath>

@implementation PngDecoder {
    NSData *_fileData;
}
- (instancetype)initWithContentsOfFile:(NSData *)fileContents {
    self = [super init];
    if (self) {
        _fileData = fileContents;
    }
    return self;
}
- (NSData *)depthDataWithWidth:(int *)width height:(int *)height {
    std::vector<unsigned char> pngData(
        (unsigned char *)_fileData.bytes,
        (unsigned char *)_fileData.bytes + _fileData.length
    );

    std::vector<unsigned char> image;
    unsigned w = 0;
    unsigned h = 0;

    unsigned error = lodepng::decode(
        image,
        w,
        h,
        pngData,
        LCT_GREY,
        16
    );

    if (error) {
        return nil;
    }

    size_t pixelCount = w * h;

    std::vector<float> floatDepth(pixelCount);

    for (size_t i = 0; i < pixelCount; i++) {
        uint16_t msb = image[i * 2];
        uint16_t lsb = image[i * 2 + 1];

        uint16_t depthMM = (msb << 8) | lsb;

        floatDepth[i] = depthMM / 1000.0f; // mm → meters
    }

    *width = (int)w;
    *height = (int)h;

    return [NSData dataWithBytes:floatDepth.data()
                          length:pixelCount * sizeof(float)];
}
@end
