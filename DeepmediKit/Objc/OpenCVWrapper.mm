//
//  OpenCVWrapper.m
//  DeepmediFaceKit
//
//  Created by Demian on 2023/02/09.
//

#import <opencv2/opencv.hpp>
#import "OpenCVWrapper.h"

@implementation OpenCVWrapper

+ (NSString *)openCVVersionString {
return [NSString stringWithFormat:@"OpenCV Version %s",  CV_VERSION];
}

+ (cv::Mat)applyExifOrientation:(const cv::Mat&)src exifOrientation:(NSInteger)exifOrientation {
    cv::Mat dst;

    switch (exifOrientation) {
        case 1:
            dst = src.clone();
            break;
        case 2:
            cv::flip(src, dst, 1);
            break;
        case 3:
            cv::rotate(src, dst, cv::ROTATE_180);
            break;
        case 4:
            cv::flip(src, dst, 0);
            break;
        case 5:
            cv::transpose(src, dst);
            break;
        case 6:
            cv::rotate(src, dst, cv::ROTATE_90_CLOCKWISE);
            break;
        case 7: {
            cv::Mat transposed;
            cv::transpose(src, transposed);
            cv::flip(transposed, dst, -1);
            break;
        }
        case 8:
            cv::rotate(src, dst, cv::ROTATE_90_COUNTERCLOCKWISE);
            break;
        default:
            dst = src.clone();
            break;
    }

    return dst;
}

+ (NSData *_Nullable)rgb36x36DataFromSampleBuffer:(CMSampleBufferRef)sampleBuffer
                                  exifOrientation:(NSInteger)exifOrientation {
    if (!sampleBuffer) {
        return nil;
    }

    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!imageBuffer) {
        return nil;
    }

    CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    NSData *result = nil;

    const int width = (int)CVPixelBufferGetWidth(imageBuffer);
    const int height = (int)CVPixelBufferGetHeight(imageBuffer);
    const size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    if (!baseAddress || width <= 0 || height <= 0) {
        CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
        return nil;
    }

    const OSType pixelFormat = CVPixelBufferGetPixelFormatType(imageBuffer);
    cv::Mat rgb;

    if (pixelFormat == kCVPixelFormatType_32BGRA) {
        cv::Mat bgra(height, width, CV_8UC4, baseAddress, bytesPerRow);
        cv::cvtColor(bgra, rgb, cv::COLOR_BGRA2RGB);
    } else if (pixelFormat == kCVPixelFormatType_32RGBA) {
        cv::Mat rgba(height, width, CV_8UC4, baseAddress, bytesPerRow);
        cv::cvtColor(rgba, rgb, cv::COLOR_RGBA2RGB);
    } else {
        NSLog(@"[OpenCVWrapper] Unsupported pixel format for face bin resize: %u", pixelFormat);
        CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
        return nil;
    }

    cv::Mat oriented = [OpenCVWrapper applyExifOrientation:rgb exifOrientation:exifOrientation];
    if (oriented.empty()) {
        CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
        return nil;
    }

    cv::Mat resized;
    cv::resize(oriented, resized, cv::Size(36, 36), 0, 0, cv::INTER_AREA);
    if (resized.empty()) {
        CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
        return nil;
    }

    if (!resized.isContinuous()) {
        resized = resized.clone();
    }

    result = [NSData dataWithBytes:resized.data length:(36 * 36 * 3)];
    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    return result;
}

+ (NSArray *)preccessbuffer:(CMSampleBufferRef)sampleBuffer device: (NSString *)device {
    cv::Mat mBGR;
    cv::Mat edgeMat;
    cv::Mat dataBuffer;
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    void* bufferAddress;
    size_t width;
    size_t height;
    size_t bytesPerRow;
    
    bufferAddress = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
    width = CVPixelBufferGetWidthOfPlane(imageBuffer, 0);
    height = CVPixelBufferGetHeightOfPlane(imageBuffer, 0);
    //  bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0);
    bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    unsigned char *pixel = (unsigned char *)CVPixelBufferGetBaseAddress(imageBuffer);
    
    dataBuffer = cv::Mat((int)height, (int)width, CV_8UC4, pixel, bytesPerRow);
    mBGR = cv::Mat((int)height, (int)width, CV_8UC4, bufferAddress, 0);
    edgeMat = cv::Mat((int)height, (int)width, CV_8UC1, bufferAddress, 0);
    
    cv::cvtColor(dataBuffer, dataBuffer, cv::COLOR_BGR2RGB);
    cv::cvtColor(mBGR, edgeMat, cv::COLOR_RGB2GRAY);
    cv::Canny(edgeMat, edgeMat, 60, 120);
    
    double canny = sum(edgeMat)[0] / (edgeMat.cols * edgeMat.rows);
    cv::Scalar mRGB = cv::mean(dataBuffer);
    
    float r = mRGB.val[0],
    g = mRGB.val[1],
    b = mRGB.val[2];
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    BOOL result;
    if ([device containsString:@"Pad"]){
        if(canny < 3.0 && (r / 255) > 0.07f && (g / 255) < 2.0f) {
            result = true;
        } else {
            result = false;
        }
    } else {
        if([device containsString:@"X"]) {
            if(canny < 3.0 && (r / 255) > 0.25f && (g / 255) < 0.97f) {
                result = true;
            } else {
                result = false;
            }
        } else if ([device containsString:@"7"] || [device containsString:@"8"]) {
            if(canny < 3.0 && (r / 255) > 0.2f && (g / 255) < 0.5f) {
                result = true;
            } else {
                result = false;
            }
        } else {
            if(canny < 3.0 && (r / 255) > 0.4f && (g / 255) < 0.1f) {
                result = true;
            } else {
                result = false;
            }
        }
    }
    
    NSMutableArray *Return = [[NSMutableArray alloc] init];
    
    [Return insertObject:[NSNumber numberWithBool:result] atIndex:0];
    [Return insertObject:[NSNumber numberWithFloat:r] atIndex:1];
    [Return insertObject:[NSNumber numberWithFloat:g] atIndex:2];
    [Return insertObject:[NSNumber numberWithFloat:b] atIndex:3];
    
    dataBuffer.release();
    mBGR.release();
    edgeMat.release();
    
    return Return;
}

@end
