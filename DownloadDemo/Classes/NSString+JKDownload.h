//
//  NSString+JKDownload.h
//  DownloadDemo
//
//  Created by lixy on 2018/4/12.
//  Copyright © 2018年 ky. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (JKDownload)

+ (NSString *)homePath;
+ (NSString *)documentPath;
+ (NSString *)cachePath;
+ (NSString *)libraryPath;
+ (NSString *)tmpPath;

+ (NSString*)pathForCaches:(NSString *)filename;
+ (NSString*)pathForCaches:(NSString *)filename inDir:(NSString*)dir;

+ (NSString*)pathForDocuments:(NSString*)filename;
+ (NSString*)pathForDocuments:(NSString *)filename inDir:(NSString*)dir;

+ (NSString*)pathForLibrary:(NSString*)filename;
+ (NSString*)pathForLibrary:(NSString *)filename inDir:(NSString*)dir;

+ (NSString*)pathForResource:(NSString *)name;
+ (NSString*)pathForResource:(NSString *)name inDir:(NSString*)dir;

- (NSString *)md5String;

@end
