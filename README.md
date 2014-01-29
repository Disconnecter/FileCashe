FileCashe
=========

Manage files cash from URLs

You can use default cash with static method 

```objectivec
+ (SZFileCashe *)DefaultFileCashe;
```
You recive 20mb of space for files in NSCachesDirectory/default

If You want make Your own cash, You can init it with 
```objectivec
- (id)initWithDir:(NSString *)dirName maxSize:(NSUInteger)size;
```
note: size in bytes. For recive 20Mb You need set size 20*1024*1024;

Put files in cash
```objectivec
- (void)cashedDataFor:(NSURL *)url withDelegate:(id <SZFileCasheDelegate>)cashDelegate;
```

Recive it delegate in methods
```objectivec
@protocol SZFileCasheDelegate <NSObject>

- (void)fileCash:(SZFileCashe *)cash didLoadData:(NSData *)fileData fromUrl:(NSURL *)url;
- (void)fileCash:(SZFileCashe *)cash didFailWithError:(NSError *)error fromUrl:(NSURL *)url;

@end
```
