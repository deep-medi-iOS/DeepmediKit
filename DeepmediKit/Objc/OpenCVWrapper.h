//
//  OpenCVWrapper.h
//  DeepmediFaceKit
//
//  Created by Demian on 2023/02/09.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface OpenCVWrapper : NSObject

+ (NSString *_Nullable)openCVVersionString;

+ (NSArray *_Nullable)preccessbuffer:(CMSampleBufferRef _Nonnull)sampleBuffer device:(NSString *_Nonnull)device;
+ (NSData *_Nullable)rgb36x36DataFromSampleBuffer:(CMSampleBufferRef _Nonnull)sampleBuffer
                                  exifOrientation:(NSInteger)exifOrientation
    NS_SWIFT_NAME(rgb36x36Data(from:exifOrientation:));
@end
