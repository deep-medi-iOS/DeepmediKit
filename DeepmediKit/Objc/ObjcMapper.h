//
//  ObjcMapper.h
//  Pods
//
//  Created by Demian on 2023/02/09.
//

#import <UIKit/UIKit.h>
#import <CommonCrypto/CommonHMAC.h>

@interface ObjcMapper:NSObject

/**
 SHA256 인코딩
 */
+ (NSString *)hmacSHA256:(NSString *)key message:(NSString *)data;
@end
