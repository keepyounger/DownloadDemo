//
//  DownloadTableViewCell.h
//  DownloadDemo
//
//  Created by lixy on 2018/4/12.
//  Copyright © 2018年 ky. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "JKDownloadManager.h"

@interface DownloadTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) IBOutlet UIButton *startButton;

@property (nonatomic, strong) JKDownloadTask *task;

@end
