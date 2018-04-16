//
//  JKDownloadManager.h
//  DownloadDemo
//
//  Created by lixy on 2018/4/12.
//  Copyright © 2018年 ky. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, JKDownloadTaskState) {
    JKDownloadTaskStateUnknown,         //初始状态
    JKDownloadTaskStateWait,            //按钮可以提示为 等待下载
    JKDownloadTaskStateReady,           //按钮可以提示为 开始下载
    JKDownloadTaskStateDownloading,     //按钮可以提示为 正在下载
    JKDownloadTaskStateResum,           //按钮可以提示为 继续下载
    JKDownloadTaskStateDone,            //按钮可以提示为 下载完成
    JKDownloadTaskStateError,           //按钮可以提示为 下载错误
};

typedef void(^JKDownloadProgressHandler)(CGFloat progress);
typedef void(^JKDownloadCompletionHandler)(NSError *error, NSString *filePath);
typedef void(^JKDownloadStateChangeHandler)(JKDownloadTaskState state);

@interface JKDownloadTask : NSObject

@property (nonatomic, strong, readonly) NSURL *url;
@property (nonatomic, assign, readonly) JKDownloadTaskState state;
@property (nonatomic, strong, readonly) NSString *savePath;
@property (nonatomic, strong, readonly) NSString *md5Key;

//总长度
@property (nonatomic, assign, readonly) NSUInteger totalLength;
//已经下载的长度
@property (nonatomic, assign, readonly) NSUInteger currentLength;

@property (nonatomic, strong, readonly) NSURLSessionDownloadTask *task;

@property (nonatomic, copy) JKDownloadProgressHandler progressHandler;
@property (nonatomic, copy) JKDownloadCompletionHandler completionHandler;
@property (nonatomic, copy) JKDownloadStateChangeHandler stateChangeHandler;

- (void)start;
- (void)stop;

@end

@interface JKDownloadManager : NSObject

+ (instancetype)shared;

//最大同时下载数 默认3
@property (nonatomic, assign) NSUInteger maxNumberOfTasks;

@property (nonatomic, strong, readonly) NSArray<JKDownloadTask*> *tasks;

- (JKDownloadTask *)addDownloadTaskWithUrlString:(NSString *)urlString;

- (void)startAllTasks;
- (void)stopAllTasks;
- (void)deleteAllTasks;

//在app delegate里面赋值
@property (nonatomic, copy) void (^backgroundCompletionHandler)(void);

@end
