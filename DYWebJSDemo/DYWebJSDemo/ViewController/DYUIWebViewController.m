//
//  DYUIWebViewController.m
//  DYWebJSDemo
//
//  Created by Coder_Hedy on 2019/8/16.
//  Copyright © 2019 Coder_Hedy. All rights reserved.
//

#import "DYUIWebViewController.h"
#import <JavaScriptCore/JavaScriptCore.h>
#import "Config.h"

@interface DYUIWebViewController ()<UIWebViewDelegate>

@property (nonatomic, strong)UIWebView *webView;

@property (nonatomic, strong)UIView *bottomView;

@property (nonatomic, strong) JSContext *context;

@end

@implementation DYUIWebViewController

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    //标准的URL包含scheme、host、port、path、query、fragment等
    NSURL *URL = request.URL;
    if ([URL.scheme isEqualToString:DAWebViewDemoScheme]) {
        if ([URL.host isEqualToString:DAWebViewDemoHostSmsLogin]) {
            NSLog(@"短信验证码登录，参数为 %@", URL.query);
            return NO;
        }
    }
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
//    self.title = [self.title stringByAppendingString:[webView stringByEvaluatingJavaScriptFromString:@"document.title"]];
    //获取该UIWebView的javascript上下文
    JSContext *context = [self.webView valueForKeyPath:@"documentView.webView.mainFrame.javaScriptContext"];
    
    //这也是一种获取标题的方法。
    JSValue *value = [context evaluateScript:@"document.title"];
    //更新标题
    self.title = value.toString;
    
    [self convertJSToOCMethod];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    
}

#pragma mark - 将JS的函数转换成OC的方法

- (void)convertJSToOCMethod
{
    //获取该UIWebview的javascript上下文
    //self持有context
    //@property (nonatomic, strong) context *context;
    self.context = [self.webView valueForKeyPath:@"documentView.webView.mainFrame.javaScriptContext"];
    
    //context oc调用js
    //JSValue *value = [self.context evaluateScript:@"document.title"];
    
    //js调用oc
    //其中share就是js的方法名称，赋给是一个block，block中是oc代码
    //此方法最终将打印出所有接收到的参数，js参数是不固定的
    self.context[@"share"] = ^() {
        //获取到share方法里的所有参数array
        NSArray *array = [JSContext currentArguments];
        //array中的元素JSValue对象转换为OC对象
        NSMutableArray *messages = [NSMutableArray array];
        for (JSValue *value in array) {
            [messages addObject:[value toObject]];
        }
        NSLog(@"点击分享按钮js传回的参数如下：\n%@", messages);
    };
    
    /*
     //两数相加
     self.context[@"testAddMethod"] = ^NSInteger(NSInteger a, NSInteger b) {
     return a + b;
     };
     */
    
    /*
     //两数相乘
     self.context[@"testAddMethod"] = ^NSInteger(NSInteger a, NSInteger b) {
     return a * b;
     };
     */
    
    //调用方法的本来实现，给原结果乘以10
    JSValue *value = self.context[@"testAddMethod"];
    self.context[@"testAddMethod"] = ^NSInteger(NSInteger a, NSInteger b) {
        JSValue *resultValue = [value callWithArguments:[JSContext currentArguments]];
        return resultValue.toInt32 * 10;
    };
    
    //异步回调
    self.context[@"shareNew"] = ^(JSValue *shareData) {
        NSLog(@"%@", [shareData toObject]);
        JSValue *resultFunction = [shareData valueForProperty:@"result"];
        //回调block
        void (^result)(BOOL) = ^(BOOL isSuccess) {
            [resultFunction callWithArguments:@[@(isSuccess)]];
        };
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSLog(@"回调分享成功");
            result(YES);
        });
    };
    
    //先注入给图片添加点击事件的js
    //防止频繁IO操作，造成性能影响
    static NSString *jsSource;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        jsSource = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"ImageClickEvent" ofType:@"js"] encoding:NSUTF8StringEncoding error:nil];
    });
    [self.context evaluateScript:jsSource];
    //替换回调方法
    self.context[@"h5ImageDidClick"] = ^(NSDictionary *imgInfo) {
        NSLog(@"UIWebView点击了html上的图片，信息是：%@", imgInfo);
    };
}


- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view addSubview:self.webView];
//    [self.view addSubview:self.bottomView];
    self.title = @"UIWebView";
    self.view.backgroundColor = [UIColor whiteColor];
    
//    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://www.LynkCo.com"]];
//    [request addValue:@"customCookieName=8769387458sc34;" forHTTPHeaderField:@"Set-Cookie"];
//    [self.webView loadRequest:request];
    
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"test" ofType:@"html"]]]];

}

- (UIWebView *)webView {
    if (!_webView) {
        _webView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
        _webView.delegate = self;
        
    }
    return _webView;
}

- (UIView *)bottomView {
    if (!_bottomView) {
        _bottomView = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - 100, self.view.frame.size.width, 100)];
        _bottomView.backgroundColor = [UIColor whiteColor];
        UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(50, 0, 100, 50)];
        button.backgroundColor = [UIColor yellowColor];
        [button.titleLabel setTextColor:[UIColor redColor]];
        [button.titleLabel setText:@"返回"];
        [button addTarget:self.webView action:@selector(goBack) forControlEvents:UIControlEventTouchUpInside];

        [_bottomView addSubview:button];
    }
    return _bottomView;
}

@end
