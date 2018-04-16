//
//  JKDownloadManager.m
//  DownloadDemo
//
//  Created by lixy on 2018/4/12.
//  Copyright © 2018年 ky. All rights reserved.
//

#import "JKDownloadManager.h"
#import <objc/runtime.h>
#import "NSString+JKDownload.h"
#import <YTKKeyValueStore/YTKKeyValueStore.h>
#import <AFNetworking/AFNetworking.h>

#define DownloadTableName @"downloadTable"
#define DownloadInfoChanged @"DownloadInfoChanged"

NSString *const JKDownloadStateKey = @"JKDownloadStateKey";
NSString *const JKDownloadProgressKey = @"JKDownloadProgressKey";
NSString *const JKDownloadDownloadTaskKey = @"JKDownloadDownloadTaskKey";

@interface NSURL(JKDownload)
@property (nonatomic, strong, readonly) NSString *savePath;
@property (nonatomic, strong, readonly) NSString *md5Key;
@end

@interface NSURLSessionTask (JKDownload)
@property (nonatomic, strong) NSURL *URL;
@property (nonatomic, strong, readonly) NSString *savePath;
@property (nonatomic, strong, readonly) NSString *md5Key;
@property (nonatomic, weak, readonly) JKDownloadTask *task;
@end

@interface JKDownloadTask()

@property (nonatomic, strong, readwrite) NSURL *url;
@property (nonatomic, assign, readwrite) JKDownloadTaskState state;
@property (nonatomic, assign, readwrite) NSUInteger totalLength;
@property (nonatomic, assign, readwrite) NSUInteger currentLength;
@property (nonatomic, strong, readwrite) NSURLSessionDownloadTask *task;
@property (nonatomic, strong) NSDictionary *downloadInfo;

+ (instancetype)taskWithURLString:(NSString *)urlString;

@end

@interface JKDownloadManager ()<NSURLSessionDownloadDelegate>
@property (nonatomic, strong) NSURLSession *sessionManager;
@property (nonatomic, strong) NSURLSessionConfiguration *sessionConfiguration;
@property (nonatomic, strong) NSMutableArray<NSURLSessionDownloadTask*> *downloadTasks;
@property (nonatomic, strong) NSMutableArray<JKDownloadTask*> *jkDownloadTasks;
@property (nonatomic, strong) YTKKeyValueStore *store;
@property (nonatomic, assign) NSInteger downloadingNumber;
- (void)startDownloadTask:(JKDownloadTask *)task;
- (void)stopDownloadTask:(JKDownloadTask *)task;
@end

@implementation NSURL (JKDownload)

- (NSString *)savePath
{
    NSString *path = [NSString pathForLibrary:self.md5Key inDir:@"jkdownload"];
    return path;
}

- (NSString *)md5Key
{
    NSString *md5Key = [self.absoluteString md5String];
    return md5Key;
}

@end

@implementation NSURLSessionTask (JKDownload)

- (NSString *)savePath
{
    return self.URL.savePath;
}

- (NSString *)md5Key
{
    return self.URL.md5Key;
}

- (JKDownloadTask *)task
{
    JKDownloadTask *task = objc_getAssociatedObject(self, _cmd);
    return task;
}

- (void)setTask:(JKDownloadTask *)task
{
    objc_setAssociatedObject(self, @selector(task), task, OBJC_ASSOCIATION_ASSIGN);
}

- (NSURL *)URL
{
    NSURL *url = objc_getAssociatedObject(self, _cmd);
    if (!url) {
        url = self.originalRequest.URL;
        if (!url) {
            objc_setAssociatedObject(self, @selector(URL), url, OBJC_ASSOCIATION_RETAIN);
        }
    }
    return url;
}

- (void)setURL:(NSURL *)URL
{
    objc_setAssociatedObject(self, @selector(URL), URL, OBJC_ASSOCIATION_RETAIN);
}

@end

@implementation JKDownloadTask

+ (instancetype)taskWithURLString:(NSString *)urlString
{
    return [[self alloc] initWithURLString:urlString];
}

- (instancetype)initWithURLString:(NSString *)urlString
{
    self = [super init];
    if (self) {
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadInfoChanged:) name:DownloadInfoChanged object:nil];
        
        self.url = [NSURL URLWithString:urlString];
        NSDictionary *dic = [[JKDownloadManager shared].store getObjectById:self.md5Key fromTable:DownloadTableName];
        if (dic) {
            self.downloadInfo = dic;
            if (self.state == JKDownloadTaskStateDownloading) {
                self.state = JKDownloadTaskStateResum;
            }
            if (self.state == JKDownloadTaskStateDone) {
                self.currentLength = self.totalLength;
            }
        } else {
            self.state = JKDownloadTaskStateReady;
        }
    }
    return self;
}

- (void)downloadInfoChanged:(NSNotification *)noti
{
    NSURLSessionDownloadTask *task = noti.userInfo[JKDownloadDownloadTaskKey];
    NSString *url = task.URL.absoluteString;
    if ([url isEqualToString:self.url.absoluteString]) {
        
        self.task = task;

        NSNumber *state = noti.userInfo[JKDownloadStateKey];
        if (state) {
            self.state = [state unsignedIntegerValue];
        }
        
        self.currentLength = task.countOfBytesReceived;
        self.totalLength = task.countOfBytesExpectedToReceive;
        
        NSNumber *progress = noti.userInfo[JKDownloadProgressKey];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (progress && self.progressHandler) {
                self.progressHandler(progress.floatValue);
            }
        });
        
        if (self.state == JKDownloadTaskStateDone) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.progressHandler) {
                    self.progressHandler(1);
                }
            });
        }
        
        if (progress.floatValue == 1) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.completionHandler) {
                    self.completionHandler(task.error, task.savePath);
                }
            });
        }
    }
}

- (NSString *)savePath
{
    return self.url.savePath;
}

- (NSString *)md5Key
{
    return self.url.md5Key;
}

- (void)setState:(JKDownloadTaskState)state
{
    if (_state != state) {
        _state = state;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.stateChangeHandler) {
                self.stateChangeHandler(state);
            }
        });
    }
}

- (void)start
{
    [[JKDownloadManager shared] startDownloadTask:self];
}

- (void)stop
{
    [[JKDownloadManager shared] stopDownloadTask:self];
}

- (NSDictionary *)downloadInfo
{
    return @{@"state": @(self.state), @"totalLength": @(self.totalLength), @"currentLength": @(self.currentLength)};
}

- (void)setDownloadInfo:(NSDictionary *)downloadInfo
{
    [downloadInfo enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        [self setValue:obj forKey:key];
    }];
}

@end

@implementation JKDownloadManager

static JKDownloadManager *_shared = nil;

- (YTKKeyValueStore *)store
{
    if (!_store) {
        NSString *path = [NSString pathForLibrary:@"downloadInfo.db" inDir:@"jkdownload"];
        YTKKeyValueStore *store = [[YTKKeyValueStore alloc] initWithDBWithPath:path];
        [store createTableWithName:DownloadTableName];
        _store = store;
    }
    return _store;
}

- (NSURLSessionConfiguration *)sessionConfiguration
{
    if (!_sessionConfiguration) {
        _sessionConfiguration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:[NSBundle mainBundle].bundleIdentifier];
    }
    return _sessionConfiguration;
}

+ (instancetype)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[JKDownloadManager alloc] init];
    });
    return _shared;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.maxNumberOfTasks = 3;
        self.jkDownloadTasks = [NSMutableArray array];
        self.sessionManager = [NSURLSession sessionWithConfiguration:self.sessionConfiguration delegate:self delegateQueue:[NSOperationQueue new]];
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        [self.sessionManager getTasksWithCompletionHandler:^(NSArray<NSURLSessionDataTask *> * _Nonnull dataTasks, NSArray<NSURLSessionUploadTask *> * _Nonnull uploadTasks, NSArray<NSURLSessionDownloadTask *> * _Nonnull downloadTasks) {
            self.downloadTasks = [NSMutableArray arrayWithArray:downloadTasks];
            dispatch_semaphore_signal(semaphore);
        }];
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    }
    return self;
}

- (void)setDownloadingNumber:(NSInteger)downloadingNumber
{
    _downloadingNumber = MAX(0, downloadingNumber);
}

- (NSArray<JKDownloadTask *> *)tasks
{
    return self.jkDownloadTasks;
}

- (NSURLSessionDownloadTask *)dataTaskWithURL:(NSURL *)url
{
    NSURLSessionDownloadTask *dataTask = nil;
    for (NSURLSessionDownloadTask *task in self.downloadTasks) {
        if ([task.URL.absoluteString isEqualToString:url.absoluteString]) {
            dataTask = task;
            break;
        }
    }
    if (!dataTask || dataTask.state == NSURLSessionTaskStateCompleted) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:url.savePath]) {
            // 创建一个断点续传任务
            NSData *data = [NSData dataWithContentsOfFile:url.savePath];
            dataTask = [self.sessionManager downloadTaskWithResumeData:data];
        } else {
            // 创建一个普通任务
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
            dataTask = [self.sessionManager downloadTaskWithRequest:request];
        }
        dataTask.URL = url;
    }
    return dataTask;
}

- (void)startDownloadTask:(JKDownloadTask *)task
{
    if (task.state != JKDownloadTaskStateDone) {
        if (self.downloadingNumber < self.maxNumberOfTasks) {
            NSURLSessionDownloadTask *dataTask = task.task;
            if (!dataTask || dataTask.state == NSURLSessionTaskStateCompleted) {
                dataTask = [self dataTaskWithURL:task.url];
                task.task = dataTask;
                dataTask.task = task;
                [self.downloadTasks addObject:dataTask];
            }
            if (dataTask.state != NSURLSessionTaskStateRunning) {
                [dataTask resume];
                self.downloadingNumber += 1;
                task.state = JKDownloadTaskStateDownloading;
            }
        } else {
            task.state = JKDownloadTaskStateWait;
        }
    }
}

- (void)startAllTasks
{
    for (JKDownloadTask *task in self.tasks) {
        [self startDownloadTask:task];
    }
}

- (void)startAllWaitTasks
{
    for (JKDownloadTask *task in self.tasks) {
        if (task.state == JKDownloadTaskStateWait && self.downloadingNumber < self.maxNumberOfTasks) {
            [self startDownloadTask:task];
        }
        if (self.downloadingNumber == self.maxNumberOfTasks) {
            break;
        }
    }
}

- (void)stopDownloadTask:(JKDownloadTask *)task
{
    if ((task.task.state != NSURLSessionTaskStateRunning || task.state != JKDownloadTaskStateDownloading) && task.state != JKDownloadTaskStateWait) {
        return;
    }
    
    NSURLSessionDownloadTask *dataTask = task.task;
    
    if (dataTask.state == NSURLSessionTaskStateRunning) {
        self.downloadingNumber -= 1;
        [dataTask suspend];
//        [dataTask cancel];
        [dataTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
//            NSString *savePath = dataTask.savePath;
//            [[NSFileManager defaultManager] removeItemAtPath:savePath error:nil];
//            [resumeData writeToFile:savePath atomically:YES];
        }];

    }
    
    task.state = JKDownloadTaskStateResum;
    
}

- (void)stopAllTasks
{
    for (JKDownloadTask *task in self.tasks) {
        [self stopDownloadTask:task];
    }
}

- (void)deleteAllTasks
{
    NSString *path = [NSString pathForLibrary:@"" inDir:@"jkdownload"];
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    [self.sessionManager invalidateAndCancel];
}

- (JKDownloadTask *)addDownloadTaskWithUrlString:(NSString *)urlString
{
    JKDownloadTask *task = [JKDownloadTask taskWithURLString:urlString];
    [self.jkDownloadTasks addObject:task];
    return task;
}

#pragma mark - <NSURLSessionDownloadDelegate>
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    //通知
    float progress = 1.0 *  totalBytesWritten / totalBytesExpectedToWrite;
    NSDictionary *dic = @{JKDownloadDownloadTaskKey: downloadTask,
                          JKDownloadProgressKey: @(progress),
                          JKDownloadStateKey: @(JKDownloadTaskStateDownloading)};
    [[NSNotificationCenter defaultCenter] postNotificationName:DownloadInfoChanged object:nil userInfo:dic];
    
    //保存状态
    NSDictionary *info = @{@"state": @(JKDownloadTaskStateDownloading), @"totalLength": @(totalBytesExpectedToWrite), @"currentLength": @(totalBytesWritten)};
    [[JKDownloadManager shared].store putObject:info withId:downloadTask.md5Key intoTable:DownloadTableName];
    
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    NSString *path = [NSString pathForLibrary:downloadTask.md5Key inDir:@"jkdownload"];
    [[NSFileManager defaultManager] moveItemAtURL:location toURL:[NSURL fileURLWithPath:path] error:nil];
}

/**
 * 3.请求完毕（成功\失败）
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    JKDownloadTaskState state = JKDownloadTaskStateUnknown;
    
    if (error) {
        NSLog(@"%@ 错误或者取消", task);
        state = JKDownloadTaskStateError;
        NSData *data = error.userInfo[NSURLSessionDownloadTaskResumeData];
        if (data) {
            NSLog(@"%@ 断点续传", task);
            state = JKDownloadTaskStateResum;
            NSString *savePath = task.savePath;
            [[NSFileManager defaultManager] removeItemAtPath:savePath error:nil];
            [data writeToFile:savePath atomically:YES];
        }
    } else {
        NSLog(@"%@ 完成", task);
        state = JKDownloadTaskStateDone;
    }
    
    //通知
    NSDictionary *dic = @{JKDownloadDownloadTaskKey: task,
                          JKDownloadStateKey: @(state)};
    [[NSNotificationCenter defaultCenter] postNotificationName:DownloadInfoChanged object:nil userInfo:dic];
    
    //保存状态
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithDictionary:[[JKDownloadManager shared].store getObjectById:task.md5Key fromTable:DownloadTableName]];
    info[@"state"] = @(state);
    [[JKDownloadManager shared].store putObject:info withId:task.md5Key intoTable:DownloadTableName];
    
    self.downloadingNumber -= 1;

    [self startAllWaitTasks];
    
}

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.backgroundCompletionHandler) {
            self.backgroundCompletionHandler();
        }
    });
}

@end
