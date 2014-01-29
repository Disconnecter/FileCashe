//
//  SZFileCash.m
//  newinstagram
//
//  Created by Zabolotnyy Sergey on 1/17/14.
//  Copyright (c) 2014 Zabolotnyy Sergey. All rights reserved.
//

#import "SZFileCashe.h"

#define kCashedFilesKey @"kSZCashedFilesKey"
#define kCashedFilesSizeKey @"kSZCashedFilesSizeKey"

@implementation SZFileCashe
{
    NSString*            fCasheDir;
    NSString*            fCasheInfoFile;
    NSUInteger           fMaxSize;
    NSUInteger           fCasheSize;
    NSOperationQueue*    fOprationQueue;
    NSMutableArray*      fCasheFiles;
}

static SZFileCashe *sharedCash = nil;

+ (SZFileCashe *)DefaultFileCashe
{
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        if (!sharedCash)
        {
            sharedCash = [[SZFileCashe alloc] initWithDir:@"default" maxSize:20 * 1024 * 1024];
        }
    });
    
    return sharedCash;
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (id)init
{
    return [SZFileCashe DefaultFileCashe];
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (id)initWithDir:(NSString *)dirName maxSize:(NSUInteger)size
{
    self = [super init];
    
    if (self)
    {
        fCasheDir =  [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)objectAtIndex:0] stringByAppendingPathComponent:dirName];
        fCasheInfoFile = [fCasheDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.cf",dirName]];
        fMaxSize = size;
        fOprationQueue = [NSOperationQueue new];
        [fOprationQueue setMaxConcurrentOperationCount:2];
        
        [self initCasheDir];
        [self initCasheInfo];
    }

    return self;
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)initCasheDir
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:fCasheDir])
    {
        [[NSFileManager defaultManager] createDirectoryAtPath:fCasheDir
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)initCasheInfo
{
    if ([[NSFileManager defaultManager] fileExistsAtPath:fCasheInfoFile])
    {
        NSDictionary* cashInfo = [[NSDictionary alloc] initWithContentsOfFile:fCasheInfoFile];
        
        fCasheFiles = [cashInfo objectForKey:kCashedFilesKey];
        fCasheSize = ((NSNumber*)[cashInfo objectForKey:kCashedFilesSizeKey]).unsignedIntegerValue;
    }
    else
    {
        fCasheFiles = [NSMutableArray new];
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)saveCasheInfo
{
    NSMutableDictionary* cashInfo = [NSMutableDictionary new];
    [cashInfo setValue:fCasheFiles forKey:kCashedFilesKey];
    [cashInfo setValue:[NSNumber numberWithUnsignedInteger:fCasheSize] forKey:kCashedFilesSizeKey];
    
    [cashInfo writeToFile:fCasheInfoFile atomically:YES];
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)dealloc
{
    [self saveCasheInfo];
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSString *)filenameForUrl:(NSURL *)url
{
    NSString* stringUrl = [[url absoluteString] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    return [stringUrl stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
}

- (void)cashedDataFor:(NSURL *)url withDelegate:(id <SZFileCasheDelegate>)cashDelegate
{
    __block NSString* filePath = [fCasheDir stringByAppendingPathComponent:[self filenameForUrl:url]];
    
    if ([fCasheFiles indexOfObject:filePath] != NSNotFound)
    {
        if ([cashDelegate respondsToSelector:@selector(fileCash:didLoadData:fromUrl:)])
        {
            NSData* fileData = [NSData dataWithContentsOfFile:filePath];
            [cashDelegate fileCash:self didLoadData:fileData fromUrl:url];
        }
    }
    else
    {
        [fOprationQueue addOperationWithBlock:^
        {
            NSURLRequest* urlRequest = [NSURLRequest requestWithURL:url cachePolicy:0 timeoutInterval:60];
            NSError* error;
            NSData* requestResponseData = [NSURLConnection sendSynchronousRequest:urlRequest
                                                                returningResponse:nil
                                                                            error:&error];
            
            if (error)
            {
                if ([cashDelegate respondsToSelector:@selector(fileCash:didFailWithError:fromUrl:)])
                {
                    dispatch_async(dispatch_get_main_queue(), ^
                    {
                        [cashDelegate fileCash:self didFailWithError:error fromUrl:url];
                    });
                }
            }
            else
            {
                if ([cashDelegate respondsToSelector:@selector(fileCash:didLoadData:fromUrl:)])
                {
                    dispatch_async(dispatch_get_main_queue(), ^
                    {
                        [cashDelegate fileCash:self didLoadData:requestResponseData fromUrl:url];
                    });
                }
                
                if ([requestResponseData length] < fMaxSize)
                {
                    [requestResponseData writeToFile:filePath atomically:YES];
                    fCasheSize += [requestResponseData length];

                    dispatch_async(dispatch_get_main_queue(), ^
                    {
                        [fCasheFiles addObject:filePath];
                        [self saveCasheInfo];
                        [self checkCasheDir];
                    });
                }
            }
        }];
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)checkCasheDir
{
    BOOL needSaveInfo = (fCasheSize > fMaxSize);
    
    NSFileManager* fileManage = [NSFileManager defaultManager];
    NSMutableArray* filesForDelete = [NSMutableArray new];
    
    while (fCasheSize > fMaxSize)
    {
        if (fCasheFiles.count == 0)
        {
            return;
        }

        NSString* filePath = [fCasheFiles objectAtIndex:0];
        
        NSDictionary* fileAttributes = [fileManage attributesOfItemAtPath:filePath
                                                                    error:nil];

        NSUInteger fileSize = [[fileAttributes objectForKey:NSFileSize] unsignedIntegerValue];
        [filesForDelete addObject:[fCasheFiles objectAtIndex:0]];
        
        [fCasheFiles removeObjectAtIndex:0];
        fCasheSize -= fileSize;
    }
    
    if (needSaveInfo)
    {
        [self saveCasheInfo];
        [self deleteFilesFromCash:filesForDelete];
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)cleanCashe
{
    [self deleteFilesFromCash:fCasheFiles];
    [fCasheFiles removeAllObjects];
    fCasheSize = 0;
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)deleteFilesFromCash:(NSArray *)deletingFiles
{
    NSOperationQueue* deleteQue = [NSOperationQueue new];
    [deleteQue setMaxConcurrentOperationCount:2];
    
    __block __weak NSFileManager* fileManage = [NSFileManager defaultManager];
    
    for (__block __weak NSString* filePath in deletingFiles)
    {
        [deleteQue addOperationWithBlock:^
         {
             [fileManage removeItemAtPath:filePath error:nil];
         }];
    }
}

    

@end
