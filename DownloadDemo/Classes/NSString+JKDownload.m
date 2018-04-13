//
//  NSString+JKDownload.m
//  DownloadDemo
//
//  Created by lixy on 2018/4/12.
//  Copyright © 2018年 ky. All rights reserved.
//

#import "NSString+JKDownload.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSString (JKDownload)

+ (NSString *)homePath
{
    return NSHomeDirectory();
}

+ (NSString *)documentPath
{
    NSArray *Paths=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path=[Paths objectAtIndex:0];
    return path;
}

+ (NSString *)cachePath
{
    NSArray *Paths=NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *path=[Paths objectAtIndex:0];
    return path;
}

+ (NSString *)libraryPath
{
    NSArray *Paths=NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *path=[Paths objectAtIndex:0];
    return path;
}

+ (NSString *)tmpPath
{
    return NSTemporaryDirectory();
}

+ (NSString *)directoryForDocuments:(NSString *)dir
{
    NSError* error;
    NSString* path = [[self documentPath] stringByAppendingPathComponent:dir];
    if(![[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error])
    {
        NSLog(@"create dir error: %@",error.localizedDescription);
    }
    return path;
}

+ (NSString *)directoryForCaches:(NSString *)dir
{
    NSError* error;
    NSString* path = [[self cachePath] stringByAppendingPathComponent:dir];
    
    if(![[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error])
    {
        NSLog(@"create dir error: %@",error.localizedDescription);
    }
    return path;
}

+ (NSString *)directoryForLibrary:(NSString *)dir
{
    NSError* error;
    NSString* path = [[self libraryPath] stringByAppendingPathComponent:dir];
    
    if(![[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error])
    {
        NSLog(@"create dir error: %@",error.localizedDescription);
    }
    return path;
}

#pragma mark- 获取文件路径
+ (NSString *)pathForResource:(NSString *)name
{
    return [[NSBundle mainBundle].resourcePath stringByAppendingPathComponent:name];
}

+ (NSString *)pathForResource:(NSString *)name inDir:(NSString *)dir
{
    return [[[NSBundle mainBundle].resourcePath stringByAppendingPathComponent:dir] stringByAppendingPathComponent:name];
}

+ (NSString *)pathForDocuments:(NSString *)filename
{
    return [[self documentPath] stringByAppendingPathComponent:filename];
}

+ (NSString *)pathForDocuments:(NSString *)filename inDir:(NSString *)dir
{
    return [[self directoryForDocuments:dir] stringByAppendingPathComponent:filename];
}

+ (NSString *)pathForLibrary:(NSString *)filename
{
    return [[self libraryPath] stringByAppendingPathComponent:filename];
}

+ (NSString *)pathForLibrary:(NSString *)filename inDir:(NSString *)dir
{
    return [[self directoryForLibrary:dir] stringByAppendingPathComponent:filename];
}

+ (NSString *)pathForCaches:(NSString *)filename
{
    return [[self cachePath] stringByAppendingPathComponent:filename];
}

+ (NSString *)pathForCaches:(NSString *)filename inDir:(NSString *)dir
{
    return [[self directoryForCaches:dir] stringByAppendingPathComponent:filename];
}

- (NSString *)md5String
{
    const char *value = [self UTF8String];
    
    unsigned char outputBuffer[CC_MD5_DIGEST_LENGTH];
    CC_MD5(value, (CC_LONG)strlen(value), outputBuffer);
    
    NSMutableString *outputString = [[NSMutableString alloc] initWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(NSInteger count = 0; count < CC_MD5_DIGEST_LENGTH; count++){
        [outputString appendFormat:@"%02x",outputBuffer[count]];
    }
    
    return outputString;
}
@end
