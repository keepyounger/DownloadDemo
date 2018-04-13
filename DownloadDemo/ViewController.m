//
//  ViewController.m
//  DownloadDemo
//
//  Created by lixy on 2018/4/12.
//  Copyright © 2018年 ky. All rights reserved.
//

#import "ViewController.h"
#import "DownloadTableViewCell.h"

@interface ViewController ()<UITableViewDelegate, UITableViewDataSource>
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *tasks;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tasks = [NSMutableArray array];
    
    [self.tableView registerNib:[UINib nibWithNibName:@"DownloadTableViewCell" bundle:nil] forCellReuseIdentifier:@"cell"];
    self.tableView.rowHeight = 88;
    
    //https://www.yidiudiu.org/heikiz/video/se002/05mansu.wav
    for (int i=0; i<15; i++) {
        NSString *url = [NSString stringWithFormat:@"https://www.yidiudiu.org/heikiz/video/se0%.2d/05mansu.wav", i+1];
        JKDownloadTask *task = [JKDownloadTask taskWithURLString:url];
        [self.tasks addObject:task];
        [[JKDownloadManager shared] addDownloadTask:task];
    }
    
}

- (IBAction)startAll:(UIBarButtonItem *)sender {
    [[JKDownloadManager shared] startAllTasks];
}

- (IBAction)stopAll:(UIBarButtonItem *)sender {
    [[JKDownloadManager shared] stopAllTasks];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.tasks.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    DownloadTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    cell.task = self.tasks[indexPath.row];
    return cell;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
