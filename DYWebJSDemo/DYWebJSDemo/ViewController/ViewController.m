//
//  ViewController.m
//  DYWebJSDemo
//
//  Created by Coder_Hedy on 2019/8/16.
//  Copyright © 2019 Coder_Hedy. All rights reserved.
//

#import "ViewController.h"
#import "DYUIWebViewController.h"
#import "DYWKWebViewController.h"

@interface ViewController ()<UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *titleArray;

@end

@implementation ViewController

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    cell.textLabel.text = self.titleArray[indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 0) {
       DYUIWebViewController *vc = [[DYUIWebViewController alloc] init];
        [self.navigationController pushViewController:vc animated:YES];
    } else {
        DYWKWebViewController *vc = [[DYWKWebViewController alloc] init];
        [self.navigationController pushViewController:vc animated:YES];
    }
}
- (void)viewDidLoad {
    [super viewDidLoad];

    [self initUI];
    
}


- (void)initUI {
    self.title = @"JS交互";
    [self.view addSubview:self.tableView];
}

- (UITableView *)tableView {
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0,self.view.frame.size.width, self.view.frame.size.height) style:UITableViewStylePlain];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        
    }
    return _tableView;
}
- (NSMutableArray *)titleArray {
    if (!_titleArray) {
        _titleArray = [NSMutableArray arrayWithCapacity:0];
        [_titleArray addObject:@"UIWebView"];
        [_titleArray addObject:@"WKWebView"];
    }
    return _titleArray;
}

@end
