//
//  SZFileCash.h
//  newinstagram
//
//  Created by Zabolotnyy Sergey on 1/17/14.
//  Copyright (c) 2014 Zabolotnyy Sergey. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SZFileCasheDelegate;

@interface SZFileCashe : NSObject

+ (SZFileCashe *)DefaultFileCashe;
- (id)initWithDir:(NSString *)dirName maxSize:(NSUInteger)size;
- (void)cashedDataFor:(NSURL *)url withDelegate:(id <SZFileCasheDelegate>)cashDelegate;

@end

@protocol SZFileCasheDelegate <NSObject>

- (void)fileCash:(SZFileCashe *)cash didLoadData:(NSData *)fileData fromUrl:(NSURL *)url;
- (void)fileCash:(SZFileCashe *)cash didFailWithError:(NSError *)error fromUrl:(NSURL *)url;

@end