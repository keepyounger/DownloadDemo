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

#define DownloadTableName @"downloadTable"

@interface NSURLSessionTask (Download)
@property (nonatomic, weak) JKDownloadTask *task;
@end

@implementation NSURLSessionTask (Download)

- (void)setTask:(JKDownloadTask *)task
{
    objc_setAssociatedObject(self, @selector(task), task, OBJC_ASSOCIATION_ASSIGN);
}

- (JKDownloadTask *)task
{
    return objc_getAssociatedObject(self, _cmd);
}

@end

@interface JKDownloadTask()

@property (nonatomic, strong, readwrite) NSURL *url;
@property (nonatomic, assign, readwrite) JKDownloadTaskState state;
@property (nonatomic, strong, readwrite) NSString *savePath;
@property (nonatomic, strong, readwrite) NSString *md5Key;
@property (nonatomic, assign, readwrite) NSUInteger resumLength;
@property (nonatomic, assign, readwrite) NSUInteger totalLength;
@property (nonatomic, assign, readwrite) NSUInteger currentLength;
@property (nonatomic, strong, readwrite) NSURLSessionDataTask *task;

@property (nonatomic, strong) NSOutputStream *stream;

@property (nonatomic, strong) NSDictionary *downloadInfo;

@end

@interface JKDownloadManager ()<NSURLSessionDataDelegate>
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong, readwrite) NSMutableSet<JKDownloadTask*> *tasks;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSURLSessionDataTask *> *dataTasks;
@property (nonatomic, strong) YTKKeyValueStore *store;
@property (nonatomic, assign) NSInteger downloadingNumber;
- (NSURLSessionDataTask *)addDownloadTask:(JKDownloadTask *)task;
- (void)startDownloadTask:(JKDownloadTask *)task;
- (void)stopDownloadTask:(JKDownloadTask *)task;
@end

@implementation JKDownloadTask

- (NSOutputStream *)stream
{
    if (!_stream) {
        _stream = [NSOutputStream outputStreamToFileAtPath:self.savePath append:YES];
    }
    return _stream;
}

+ (instancetype)taskWithURLString:(NSString *)urlString
{
    return [[self alloc] initWithURLString:urlString];
}

- (instancetype)initWithURLString:(NSString *)urlString
{
    self = [super init];
    if (self) {
        self.url = [NSURL URLWithString:urlString];
        self.md5Key = [urlString md5String];
        self.savePath = [NSString pathForLibrary:self.md5Key inDir:@"jkdownload"];
        NSDictionary *dic = [[JKDownloadManager shared].store getObjectById:self.md5Key fromTable:DownloadTableName];
        if (dic) {
            self.downloadInfo = dic;
            if (self.state == JKDownloadTaskStateDownloading) {
                self.state = JKDownloadTaskStateResum;
            }
            self.resumLength = self.currentLength;
        } else {
            self.state = JKDownloadTaskStateReady;
        }
    }
    return self;
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
    return @{@"state": @(self.state), @"resumLength": @(self.resumLength), @"totalLength": @(self.totalLength), @"currentLength": @(self.currentLength)};
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

- (NSURLSession *)session
{
    if (!_session) {
        _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[[NSOperationQueue alloc] init]];
    }
    return _session;
}

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

+ (instancetype)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[JKDownloadManager alloc] init];
        _shared.maxNumberOfTasks = 3;
        _shared.tasks = [NSMutableSet set];
        _shared.dataTasks = [NSMutableDictionary dictionary];
    });
    return _shared;
}

- (void)setDownloadingNumber:(NSInteger)downloadingNumber
{
    _downloadingNumber = MAX(0, downloadingNumber);
}

- (NSURLSessionDataTask *)dataTaskWithDownloadTask:(JKDownloadTask *)task
{
    NSURLSessionDataTask *dataTask = self.dataTasks[task.md5Key];
    if (!dataTask) {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:task.url];
        if (task.state == JKDownloadTaskStateResum) {
            // 设置请求头
            // Range : bytes=xxx-xxx，从已经下载的长度开始到文件总长度的最后都要下载
            NSString *range = [NSString stringWithFormat:@"bytes=%zd-",  task.resumLength];
            [request setValue:range forHTTPHeaderField:@"Range"];
            
            // 创建一个Data任务
            dataTask = [self.session dataTaskWithRequest:request];
        } else {
            // 创建一个Data任务
            dataTask = [self.session dataTaskWithRequest:request];
        }
        self.dataTasks[task.md5Key] = dataTask;
        task.task = dataTask;
        dataTask.task = task;
    }
    return dataTask;
}

- (void)startDownloadTask:(JKDownloadTask *)task
{
    NSURLSessionDataTask *dataTask = task.task;
    if (!dataTask) {
        dataTask = [[JKDownloadManager shared] addDownloadTask:task];
    }
    if (dataTask.state != NSURLSessionTaskStateRunning) {
        if (task.state != JKDownloadTaskStateDone) {
            if (self.downloadingNumber < self.maxNumberOfTasks) {
                [dataTask resume];
                self.downloadingNumber += 1;
                task.state = JKDownloadTaskStateDownloading;
            } else {
                task.state = JKDownloadTaskStateWait;
            }
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
    
    NSURLSessionDataTask *dataTask = task.task;
    
    if (!dataTask) {
        dataTask = [[JKDownloadManager shared] addDownloadTask:task];
    }
    
    if (dataTask.state == NSURLSessionTaskStateRunning) {
        self.downloadingNumber -= 1;
        [dataTask suspend];
    }
    
    task.state = JKDownloadTaskStateResum;
    
}

- (void)stopAllTasks
{
    for (JKDownloadTask *task in self.tasks) {
        [self stopDownloadTask:task];
    }
}

- (void)removeAllTasks
{
    self.downloadingNumber = 0;
    
    [self stopAllTasks];
    
    [self.tasks removeAllObjects];
    [self.dataTasks removeAllObjects];
}

- (NSURLSessionDataTask *)addDownloadTask:(JKDownloadTask *)task
{
    [self.tasks addObject:task];
    NSURLSessionDataTask *dataTask = [self dataTaskWithDownloadTask:task];
    return dataTask;
}

- (void)removeDownloadTask:(JKDownloadTask *)task
{
    [self stopDownloadTask:task];
    
    [self.tasks removeObject:task];
    [self.dataTasks removeObjectForKey:task.md5Key];
}

#pragma mark - <NSURLSessionDataDelegate>
/**
 * 1.接收到响应
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSHTTPURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    if (response.statusCode == 200) {
        dataTask.task.totalLength = dataTask.countOfBytesExpectedToReceive;
    } else if (response.statusCode == 206) {
        NSString *contentRange = [response.allHeaderFields valueForKey:@"Content-Range"];
        if ([contentRange hasPrefix:@"bytes"]) {
            //Content-Range: bytes 12367-200000/200000”说明了返回提供了请求资源所在的原始实体内的位置，还给出了整个资源的长度。
            NSArray *bytes = [contentRange componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" -/"]];
            if ([bytes count] == 4) {
                //self.totalCotentLength=200000;
                dataTask.task.totalLength = [[bytes objectAtIndex:3] longLongValue];
            } else {
                dataTask.task.totalLength = [response.allHeaderFields[@"Content-Length"] integerValue] +  dataTask.task.resumLength;
            }
        } else {
            dataTask.task.totalLength = [response.allHeaderFields[@"Content-Length"] integerValue] +  dataTask.task.resumLength;
        }
    } else if (response.statusCode == 416) {
        NSString *contentRange = [response.allHeaderFields valueForKey:@"Content-Range"];
        if ([contentRange hasPrefix:@"bytes"]) {
            NSArray *bytes = [contentRange componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" -/"]];
            if ([bytes count] == 3) {
                dataTask.task.totalLength = [[bytes objectAtIndex:2] longLongValue];
                if (dataTask.task.currentLength == dataTask.task.totalLength) {
                    //说明已下完
//                    dispatch_async(dispatch_get_main_queue(), ^{
//                        if (dataTask.task.completionHandler) {
//                            dataTask.task.completionHandler(nil, dataTask.task.savePath);
//                        }
//                    });
                }else{
                    //416 Requested Range Not Satisfiable
//                    NSError *error = [[NSError alloc] initWithDomain:[dataTask.task.url absoluteString] code:416 userInfo:response.allHeaderFields];
//                    dispatch_async(dispatch_get_main_queue(), ^{
//                        if (dataTask.task.completionHandler) {
//                            dataTask.task.completionHandler(error, nil);
//                        }
//                    });
                    //不能下载
                    completionHandler(NSURLSessionResponseCancel);
                    return;
                }
            } else {
                dataTask.task.totalLength = [response.allHeaderFields[@"Content-Length"] integerValue] +  dataTask.task.resumLength;
            }
        } else {
            dataTask.task.totalLength = [response.allHeaderFields[@"Content-Length"] integerValue] +  dataTask.task.resumLength;
        }
 
    } else {
        //不能下载
        completionHandler(NSURLSessionResponseCancel);
    }
    
    // 打开流
    [dataTask.task.stream open];
    
    //保存状态
    [self.store putObject:dataTask.task.downloadInfo withId:dataTask.task.md5Key intoTable:DownloadTableName];

    // 接收这个请求，允许接收服务器的数据
    completionHandler(NSURLSessionResponseAllow);
}

/**
 * 2.接收到服务器返回的数据（这个方法可能会被调用N次）
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    // 写入数据
    [dataTask.task.stream write:data.bytes maxLength:data.length];
    dataTask.task.currentLength += data.length;
    
    //保存状态
    [self.store putObject:dataTask.task.downloadInfo withId:dataTask.task.md5Key intoTable:DownloadTableName];
    
    float progress = 1.0 *  dataTask.task.currentLength / dataTask.task.totalLength;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (dataTask.task.progressHandler) {
            dataTask.task.progressHandler(progress);
        }
    });
}

/**
 * 3.请求完毕（成功\失败）
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    // 关闭流
    [task.task.stream close];
    
    [self removeDownloadTask:task.task];

    if (error) {
        task.task.state = JKDownloadTaskStateError;
    } else {
        task.task.state = JKDownloadTaskStateDone;
    }
    
    //保存状态
    [self.store putObject:task.task.downloadInfo withId:task.task.md5Key intoTable:DownloadTableName];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (task.task.completionHandler) {
            task.task.completionHandler(error, task.task.savePath);
        }
    });
    
    self.downloadingNumber -= 1;

    [self startAllWaitTasks];
}

@end
