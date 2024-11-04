//
//  OpenCVWrapper.m
//  DeepmediFaceKit
//
//  Created by Demian on 2023/02/09.
//

#import <opencv2/opencv.hpp>
#import <opencv2/videoio/cap_ios.h>
#import <opencv2/imgcodecs/ios.h>
#import "OpenCVWrapper.h"

#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>

@interface OpenCVWrapper()

@property (nonatomic) cv::Mat YY;
@property (nonatomic) cv::Mat Xmtx;
@property (nonatomic) cv::Mat Ymtx;
@property (nonatomic) cv::Mat Acoeff;
@property (nonatomic) cv::Mat Bcoeff;
@property (nonatomic) cv::Mat buff;

@end


@implementation OpenCVWrapper

+ (NSString *)openCVVersionString {
return [NSString stringWithFormat:@"OpenCV Version %s",  CV_VERSION];
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
    
    //  printf("r/255 %f / g/255 %f \n", (r / 255), (g / 255));
    //  printf("r %f / r/255 %f / g %f / g/255 %f /  b %f \n", r, (r / 255), g, (g / 255), b);
    //  printf("->canny %f / r/255 %f / g/255 %f /  b/255 %f \n",(canny), (r / 255), (g / 255), (b / 255));
    
    BOOL result;
    if ([device containsString:@"Pad"]){
        if(canny < 3.0 && (r / 255) > 0.07f && (g / 255) < 2.0f) {
            result = true;
        } else {
            result = false;
        }
    } else {
        if([device containsString:@"X"]) {
            if(canny < 3.0 && (r / 255) > 0.25f && (g / 255) < 2.0f) {
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

+ (NSArray *)detectFaceSampleBuffer:(CMSampleBufferRef)sampleBuffer {
  
  CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
  CVPixelBufferLockBaseAddress(imageBuffer, 0);
  
  void* bufferAddress;
  size_t width;
  size_t height;
  size_t bytesPerRow;
  
  bufferAddress = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
  width = CVPixelBufferGetWidthOfPlane(imageBuffer, 0);
  height = CVPixelBufferGetHeightOfPlane(imageBuffer, 0);
  bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0);
  unsigned char *pixel = (unsigned char *)CVPixelBufferGetBaseAddress(imageBuffer);
  
//  mBGR = cv::Mat((int)height, (int)width, CV_8UC3, bufferAddress, 0);
//  cv::cvtColor(mBGR, mBGR, cv::COLOR_BGR2RGB);
//  cv::Scalar bgr = cv::mean(mBGR);
  
//  float r = bgr.val[2],
//        g = bgr.val[1],
//        b = bgr.val[0];
  
  cv::Mat imgMat = cv::Mat((int)height, (int)width, CV_8UC4, pixel, CVPixelBufferGetBytesPerRow(imageBuffer));
  cv::cvtColor(imgMat, imgMat, cv::COLOR_BGR2RGB);
  cv::Scalar mRGB = cv::mean(imgMat);
  cv::rotate(imgMat, imgMat, cv::ROTATE_90_CLOCKWISE);

  float r = mRGB.val[0],
        g = mRGB.val[1],
        b = mRGB.val[2];

  CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
  
  NSMutableArray *rgb = [[NSMutableArray alloc] init];
  
  [rgb insertObject:[NSNumber numberWithFloat:r] atIndex:0];
  [rgb insertObject:[NSNumber numberWithFloat:g] atIndex:1];
  [rgb insertObject:[NSNumber numberWithFloat:b] atIndex:2];
  
  imgMat.release();
  
  return rgb;
}

+ (unsigned char *)detectChestSampleBuffer:(CMSampleBufferRef)sampleBuffer {
  
  CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
  CVPixelBufferLockBaseAddress(imageBuffer, 0);
  
  void* bufferAddress;
  size_t width;
  size_t height;
  size_t bytesPerRow;
  
  bufferAddress = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
  width = CVPixelBufferGetWidth(imageBuffer);
  height = CVPixelBufferGetHeight(imageBuffer);
  bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
  unsigned char *pixel = (unsigned char *)CVPixelBufferGetBaseAddress(imageBuffer);
  
  cv::Mat imgMat = cv::Mat((int)height, (int)width, CV_8UC4, pixel, bytesPerRow);
  cv::resize(imgMat, imgMat, cv::Size(32, 32));
  cv::cvtColor(imgMat, imgMat, cv::COLOR_RGBA2GRAY); // BGRA2GRAY -> RGBA2GRAY 차이가 큼
  cv::rotate(imgMat, imgMat, cv::ROTATE_90_CLOCKWISE);

  unsigned long size = height * width;
  
  uint8_t *buf = new uint8_t[size];

  memcpy(buf, imgMat.data, size);
  
  CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
  imgMat.release();
  
  return buf;
}

+ (UIImage *)convertingBuffer:(CMSampleBufferRef)sampleBuffer {
  
  CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
  CVPixelBufferLockBaseAddress(imageBuffer, 0);
  
  size_t width;
  size_t height;
  size_t bytesPerRow;
  
  width = CVPixelBufferGetWidth(imageBuffer);
  height = CVPixelBufferGetHeight(imageBuffer);
  bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
  unsigned char *pixel = (unsigned char *)CVPixelBufferGetBaseAddress(imageBuffer);
  
  cv::Mat imgMat = cv::Mat((int)height, (int)width, CV_8UC4, pixel, bytesPerRow);
  cv::cvtColor(imgMat, imgMat, cv::COLOR_BGR2RGB);
  cv::rotate(imgMat, imgMat, cv::ROTATE_90_CLOCKWISE);

  UIImage* outcome = MatToUIImage(imgMat);
  
  CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
  
  imgMat.release();
  
  return outcome;
}

@end
