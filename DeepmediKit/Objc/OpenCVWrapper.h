//
//  OpenCVWrapper.h
//  DeepmediFaceKit
//
//  Created by Demian on 2023/02/09.
//

#import <UIKit/UIKit.h>
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>

@interface OpenCVWrapper : NSObject

+ (NSString *)openCVVersionString;

+ (NSArray *)preccessbuffer:(CMSampleBufferRef)sampleBuffer device: (NSString *)device;
+ (NSArray *)detectFaceSampleBuffer:(CMSampleBufferRef)sampleBuffer;
+ (unsigned char *)detectChestSampleBuffer:(CMSampleBufferRef)sampleBuffer;

+ (UIImage *_Nullable)convertingBuffer:(CMSampleBufferRef)sampleBuffer;
+ (UIImage *_Nullable)convertingBufferToImage:(CMSampleBufferRef)sampleBuffer;
@end
