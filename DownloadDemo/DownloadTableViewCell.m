//
//  DownloadTableViewCell.m
//  DownloadDemo
//
//  Created by lixy on 2018/4/12.
//  Copyright © 2018年 ky. All rights reserved.
//

#import "DownloadTableViewCell.h"

@implementation DownloadTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
}

- (void)setTask:(JKDownloadTask *)task
{
    _task = task;
    
    if (task.totalLength) {
        self.progressView.progress = 1.0*task.currentLength/task.totalLength;
    } else {
        self.progressView.progress = 0;
    }
    __weak typeof(self) weakSelf = self;
    
    [self.task setProgressHandler:^(CGFloat progress) {
        weakSelf.progressView.progress = progress;
    }];
    
//    [self.task setCompletionHandler:^(NSError *error, NSString *filePath) {
//        if (error) {
//            [weakSelf.startButton setTitle:@"下载错误" forState:UIControlStateNormal];
//        } else {
//            [weakSelf.startButton setTitle:@"下载完成" forState:UIControlStateNormal];
//        }
//    }];
    
    [self.task setStateChangeHandler:^(JKDownloadTaskState state) {
        [weakSelf refreshState];
    }];
    
    [self refreshState];
}

- (void)refreshState
{
    JKDownloadTask *task = self.task;
    if (task.state == JKDownloadTaskStateDownloading) {
        [self.startButton setTitle:@"正在下载" forState:UIControlStateNormal];
    } else if (task.state == JKDownloadTaskStateReady) {
        [self.startButton setTitle:@"开始下载" forState:UIControlStateNormal];
    } else if (task.state == JKDownloadTaskStateResum) {
        [self.startButton setTitle:@"继续下载" forState:UIControlStateNormal];
    } else if (task.state == JKDownloadTaskStateDone) {
        [self.startButton setTitle:@"下载完成" forState:UIControlStateNormal];
    } else if (task.state == JKDownloadTaskStateError) {
        [self.startButton setTitle:@"下载错误" forState:UIControlStateNormal];
    } else if (task.state == JKDownloadTaskStateWait) {
        [self.startButton setTitle:@"等待下载" forState:UIControlStateNormal];
    }
}

- (IBAction)startClick:(UIButton *)sender
{
    if (self.task.state == JKDownloadTaskStateDownloading) {
        [self.task stop];
    } else {
        [self.task start];
    }
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.task.progressHandler = nil;
    self.task.completionHandler = nil;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
}

@end
