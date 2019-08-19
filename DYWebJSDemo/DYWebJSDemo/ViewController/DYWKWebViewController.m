//
//  DYWKWebViewController.m
//  DYWebJSDemo
//
//  Created by Coder_Hedy on 2019/8/16.
//  Copyright © 2019 Coder_Hedy. All rights reserved.
//

#import "DYWKWebViewController.h"
#import "NSHTTPCookie+Utils.h"
#import "Config.h"
#import <WebKit/WebKit.h>
#import <ContactsUI/ContactsUI.h>

#define iPhoneX ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(1125, 2436), [[UIScreen mainScreen] currentMode].size) : NO)

#define StatusBarAndNavigationBarHeight (iPhoneX ? 88.f : 64.f)

// WKWebView 内存不释放的问题解决
@interface WeakWebViewScriptMessageDelegate : NSObject<WKScriptMessageHandler>

//WKScriptMessageHandler 这个协议类专门用来处理JavaScript调用原生OC的方法
@property (nonatomic, weak) id<WKScriptMessageHandler> scriptDelegate;

- (instancetype)initWithDelegate:(id<WKScriptMessageHandler>)scriptDelegate;

@end
@implementation WeakWebViewScriptMessageDelegate

- (instancetype)initWithDelegate:(id<WKScriptMessageHandler>)scriptDelegate {
    self = [super init];
    if (self) {
        _scriptDelegate = scriptDelegate;
    }
    return self;
}

#pragma mark - WKScriptMessageHandler
//遵循WKScriptMessageHandler协议，必须实现如下方法，然后把方法向外传递
//通过接收JS传出消息的name进行捕捉的回调方法
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    
    if ([self.scriptDelegate respondsToSelector:@selector(userContentController:didReceiveScriptMessage:)]) {
        [self.scriptDelegate userContentController:userContentController didReceiveScriptMessage:message];
    }
}

@end


@interface DYWKWebViewController ()<
WKUIDelegate,
WKNavigationDelegate,
WKScriptMessageHandler,
CNContactPickerDelegate
>

@property (strong, nonatomic) WKWebView *webView;

@property (nonatomic, copy) void (^completion)(NSString *name, NSString *phone);
//网页加载进度视图
@property (nonatomic, strong) UIProgressView * progressView;
@end

@implementation DYWKWebViewController



#pragma mark - WKNavigationDelegate 方法按调用前后顺序排序

//针对一次action来决定是否允许跳转，允许与否都需要调用decisionHandler，比如decisionHandler(WKNavigationActionPolicyCancel);
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    //可以通过navigationAction.navigationType获取跳转类型，如新链接、后退等
    NSURL *URL = navigationAction.request.URL;
    //判断URL是否符合自定义的URL Scheme
    if ([URL.scheme isEqualToString:DAWebViewDemoScheme]) {
        //根据不同的业务，来执行对应的操作，且获取参数
        if ([URL.host isEqualToString:DAWebViewDemoHostSmsLogin]) {
            NSString *param = URL.query;
            NSLog(@"短信验证码登录, 参数为%@", param);
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        }
    }
    
#warning important 这里很重要
    //解决Cookie丢失问题
    NSURLRequest *originalRequest = navigationAction.request;
    [self fixRequest:originalRequest];
    //如果originalRequest就是NSMutableURLRequest, originalRequest中已添加必要的Cookie，可以跳转
    //允许跳转
    decisionHandler(WKNavigationActionPolicyAllow);
    
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

//根据response来决定，是否允许跳转，允许与否都需要调用decisionHandler，如decisionHandler(WKNavigationResponsePolicyAllow);
- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    decisionHandler(WKNavigationResponsePolicyAllow);
}

//提交了一个跳转，早于 didStartProvisionalNavigation
- (void)webView:(WKWebView *)webView didCommitNavigation:(null_unspecified WKNavigation *)navigation
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

//开始加载，对应UIWebView的- (void)webViewDidStartLoad:(UIWebView *)webView;
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(null_unspecified WKNavigation *)navigation
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

//加载成功，对应UIWebView的- (void)webViewDidFinishLoad:(UIWebView *)webView;
- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation
{
    self.navigationItem.title = [self.title stringByAppendingString:webView.title];  //其实可以kvo来实现动态切换title
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    //    self.webView.scrollView.frame = CGRectMake(0, 64, self.webView.scrollView.frame.size.width, self.webView.scrollView.frame.size.height);
    //    self.webView.scrollView.contentOffset = CGPointMake(0, -64);
    
    //    [self.webView evaluateJavaScript:@"document.title" completionHandler:^(id _Nullable result, NSError * _Nullable error) {
    //
    //    }];
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

//页面加载失败或者跳转失败，对应UIWebView的- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error;
- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    NSLog(@"%@\nerror：%@", NSStringFromSelector(_cmd), error);
}

//页面加载数据时报错
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    NSLog(@"%@\nerror：%@", NSStringFromSelector(_cmd), error);
}

#pragma mark - WKUIDelegate

- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures
{
#warning important 这里也很重要
    //这里不打开新窗口
    [self.webView loadRequest:[self fixRequest:navigationAction.request]];
    return nil;
}

- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(nonnull void (^)(void))completionHandler
{
    //js 里面的alert实现，如果不实现，网页的alert函数无效
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:message message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        completionHandler();
    }]];
    [self presentViewController:alertController animated:YES completion:^{}];
}

- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))completionHandler {
    //  js 里面的alert实现，如果不实现，网页的alert函数无效  ,
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:message message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action){
        completionHandler(NO);
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        completionHandler(YES);
    }]];
    [self presentViewController:alertController animated:YES completion:^{}];
}

- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString *))completionHandler
{
    //用于和JS交互，弹出输入框
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:prompt message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action){
        completionHandler(nil);
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UITextField *textField = alertController.textFields.firstObject;
        completionHandler(textField.text);
    }]];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.text = defaultText;
    }];
    [self presentViewController:alertController animated:YES completion:NULL];
}

#pragma mark - WKScriptMessageHandler  js -> oc

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
    if ([message.name isEqualToString:@"share"]) {
        id body = message.body;
        NSLog(@"share分享的内容为：%@", body);
    }
    else if ([message.name isEqualToString:@"shareNew"] || [message.name isEqualToString:@"nativeShare"]) {
        NSDictionary *shareData = message.body;
        NSLog(@"%@分享的数据为： %@", message.name, shareData);
        //模拟异步回调
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            //读取js function的字符串
            NSString *jsFunctionString = shareData[@"result"];
            //拼接调用该方法的js字符串
            NSString *callbackJs = [NSString stringWithFormat:@"(%@)(%d);", jsFunctionString, NO];    //后面的参数NO为模拟分享失败
            //执行回调
            [self.webView evaluateJavaScript:callbackJs completionHandler:^(id _Nullable result, NSError * _Nullable error) {
                if (!error) {
                    NSLog(@"模拟回调，分享失败");
                }
            }];
        });
    }
    else if ([message.name isEqualToString:@"currentCookies"]) {
        NSString *cookiesStr = message.body;
        NSLog(@"当前的cookie为： %@", cookiesStr);
    }
    else if ([message.name isEqualToString:@"imageDidClick"]) {
        //点击了html上的图片
        NSLog(@"点击了html上的图片，参数为%@", message.body);
        /*
         会log
         
         点击了html上的图片，参数为{
         height = 168;
         imgUrl = "http://cc.cocimg.com/api/uploads/170425/b2d6e7ea5b3172e6c39120b7bfd662fb.jpg";
         imgUrls =     (
         "http://cc.cocimg.com/api/uploads/170425/b2d6e7ea5b3172e6c39120b7bfd662fb.jpg"
         );
         index = 0;
         width = 252;
         x = 8;
         y = 8;
         }
         
         注意这里的x，y是不包含自定义scrollView的contentInset的，如果要获取图片在屏幕上的位置：
         x = x + contentInset.left;
         y = y + contentInset.top;
         */
        NSDictionary *dict = message.body;
        NSString *selectedImageUrl = dict[@"imgUrl"];
        CGFloat x = [dict[@"x"] floatValue] + + self.webView.scrollView.contentInset.left;
        CGFloat y = [dict[@"y"] floatValue] + self.webView.scrollView.contentInset.top;
        CGFloat width = [dict[@"width"] floatValue];
        CGFloat height = [dict[@"height"] floatValue];
        CGRect frame = CGRectMake(x, y, width, height);
        NSUInteger index = [dict[@"index"] integerValue];
        NSLog(@"点击了第%@个图片，\n链接为%@，\n在Screen中的绝对frame为%@，\n所有的图片数组为%@", @(index), selectedImageUrl, NSStringFromCGRect(frame), dict[@"imgUrls"]);
        
    }
    //选择联系人
    else if ([message.name isEqualToString:@"choosePhoneContact"]) {
        NSLog(@"正在选择联系人");
        
        [self selectContactCompletion:^(NSString *name, NSString *phone) {
            NSLog(@"选择完成");
            //读取js function的字符串
            NSString *jsFunctionString = message.body[@"completion"];
            //拼接调用该方法的js字符串
            NSString *callbackJs = [NSString stringWithFormat:@"(%@)({name: '%@', mobile: '%@'});", jsFunctionString, name, phone];
            //执行回调
            [self.webView evaluateJavaScript:callbackJs completionHandler:^(id _Nullable result, NSError * _Nullable error) {
                
            }];
        }];
        
    }
}

#pragma mark - CNContactPickerDelegate

- (void)contactPickerDidCancel:(CNContactPickerViewController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)contactPicker:(CNContactPickerViewController *)picker didSelectContactProperty:(CNContactProperty *)contactProperty
{
    if (![contactProperty.key isEqualToString:CNContactPhoneNumbersKey]) {
        return;
    }
    CNContact *contact = contactProperty.contact;
    NSString *name = [CNContactFormatter stringFromContact:contact style:CNContactFormatterStyleFullName];
    
    CNPhoneNumber *phoneNumber = contactProperty.value;
    NSString *phone = phoneNumber.stringValue.length ? phoneNumber.stringValue : @"";
    //可以把-、+86、空格这些过滤掉
    NSString *phoneStr = [phone stringByReplacingOccurrencesOfString:@"-" withString:@""];
    phoneStr = [phoneStr stringByReplacingOccurrencesOfString:@"+86" withString:@""];
    phoneStr = [phoneStr stringByReplacingOccurrencesOfString:@" " withString:@""];
    phoneStr = [[phoneStr componentsSeparatedByCharactersInSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] invertedSet]] componentsJoinedByString:@""];
    
    //回调
    if (self.completion) {
        self.completion(name, phoneStr);
    }
    
    //dismiss
    [picker dismissViewControllerAnimated:YES completion:nil];
}
#pragma mark - Events

/**
 页面中的所有img标签添加点击事件
 */
- (void)imgAddClickEvent
{
    //防止频繁IO操作，造成性能影响
    static NSString *jsSource;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        jsSource = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"ImageClickEvent" ofType:@"js"] encoding:NSUTF8StringEncoding error:nil];
    });
    //添加自定义的脚本
    WKUserScript *js = [[WKUserScript alloc] initWithSource:jsSource injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:NO];
    [self.webView.configuration.userContentController addUserScript:js];
    //注册回调
    [self.webView.configuration.userContentController addScriptMessageHandler:self name:@"imageDidClick"];
}

/**
 添加native端的api
 */
- (void)addNativeApiToJS
{
    //防止频繁IO操作，造成性能影响
    static NSString *nativejsSource;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        nativejsSource = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"NativeApi" ofType:@"js"] encoding:NSUTF8StringEncoding error:nil];
    });
    //添加自定义的脚本
    WKUserScript *js = [[WKUserScript alloc] initWithSource:nativejsSource injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
    [self.webView.configuration.userContentController addUserScript:js];
    //注册回调
    [self.webView.configuration.userContentController addScriptMessageHandler:self name:@"nativeShare"];
    [self.webView.configuration.userContentController addScriptMessageHandler:self name:@"choosePhoneContact"];
}

/*!
 *  更新webView的cookie
 */
- (void)updateWebViewCookie
{
    WKUserScript * cookieScript = [[WKUserScript alloc] initWithSource:[self cookieString] injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
    //添加Cookie
    [self.webView.configuration.userContentController addUserScript:cookieScript];
}

//比如你在登录成功时，保存Cookie
- (void)saveCookie
{
    /*
     //如果从已有的地方保存Cookie，比如登录成功
     NSArray *allCookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
     for (NSHTTPCookie *cookie in allCookies) {
     if ([cookie.name isEqualToString:DAServerSessionCookieName]) {
     NSDictionary *dict = [[NSUserDefaults standardUserDefaults] dictionaryForKey:DAUserDefaultsCookieStorageKey];
     if (dict) {
     NSHTTPCookie *localCookie = [NSHTTPCookie cookieWithProperties:dict];
     if (![cookie.value isEqual:localCookie.value]) {
     NSLog(@"本地Cookie有更新");
     }
     }
     [[NSUserDefaults standardUserDefaults] setObject:cookie.properties forKey:DAUserDefaultsCookieStorageKey];
     [[NSUserDefaults standardUserDefaults] synchronize];
     break;
     }
     }
     */
    
    NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:@{
                                                                NSHTTPCookieName: DAServerSessionCookieName,
                                                                NSHTTPCookieValue: @"1314521",
                                                                NSHTTPCookieDomain: @".baidu.com",
                                                                NSHTTPCookiePath: @"/"
                                                                }];
    [[NSUserDefaults standardUserDefaults] setObject:cookie.properties forKey:DAUserDefaultsCookieStorageKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}


/**
 解决首次加载页面Cookie带不上问题
 
 @param url 链接
 */
- (void)loadUrl:(NSString *)url
{
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    [self.webView loadRequest:[self fixRequest:request]];
}

/**
 修复打开链接Cookie丢失问题
 
 @param request 请求
 @return 一个fixedRequest
 */
- (NSURLRequest *)fixRequest:(NSURLRequest *)request
{
    NSMutableURLRequest *fixedRequest;
    if ([request isKindOfClass:[NSMutableURLRequest class]]) {
        fixedRequest = (NSMutableURLRequest *)request;
    } else {
        fixedRequest = request.mutableCopy;
    }
    //防止Cookie丢失
    NSDictionary *dict = [NSHTTPCookie requestHeaderFieldsWithCookies:[NSHTTPCookieStorage sharedHTTPCookieStorage].cookies];
    if (dict.count) {
        NSMutableDictionary *mDict = request.allHTTPHeaderFields.mutableCopy;
        [mDict setValuesForKeysWithDictionary:dict];
        fixedRequest.allHTTPHeaderFields = mDict;
    }
    return fixedRequest;
}

- (IBAction)refresh:(id)sender {
    //刷新
    [self.webView reload];
    /*
     //等同于
     [self.webView evaluateJavaScript:@"location.reload()" completionHandler:^(id _Nullable result, NSError * _Nullable error) {
     
     }];
     */
}

#pragma mark 选择联系人

- (void)selectContactCompletion:(void (^)(NSString *name, NSString *phone))completion
{
    self.completion = completion;
    CNContactPickerViewController *picker = [[CNContactPickerViewController alloc] init];
    picker.delegate = self;
    picker.displayedPropertyKeys = @[CNContactPhoneNumbersKey];
    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark oc -> js
/**
 测试evaluateJavaScript方法
 */
- (IBAction)testEvaluateJavaScript {
    
    [self.webView evaluateJavaScript:@"document.cookie" completionHandler:^(id _Nullable cookies, NSError * _Nullable error) {
        NSLog(@"调用evaluateJavaScript异步获取cookie：%@", cookies);
    }];
    
    // do not use dispatch_semaphore_t
    /*
     __block id cookies;
     dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
     [self.webView evaluateJavaScript:@"document.cookie" completionHandler:^(id _Nullable result, NSError * _Nullable error) {
     cookies = result;
     dispatch_semaphore_signal(semaphore);
     }];
     //等待三秒，接收参数
     dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC));
     //打印cookie，肯定为空，因为足足等了3s，dispatch_semaphore_signal没有起作用
     NSLog(@"cookie的值为：%@", cookies);
     
     //还是老实的接受异步回调吧，不要用信号来搞成同步，会卡死的，不信可以试试
     */
}

#pragma mark - Setters and Getters

- (NSString *)cookieString
{
    NSMutableString *script = [NSMutableString string];
    for (NSHTTPCookie *cookie in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]) {
        // Skip cookies that will break our script
        if ([cookie.value rangeOfString:@"'"].location != NSNotFound) {
            continue;
        }
        // Create a line that appends this cookie to the web view's document's cookies
        [script appendFormat:@"document.cookie='%@'; \n", cookie.dy_javascriptString];
    }
    return script;
}


- (UIProgressView *)progressView
{
    if (!_progressView){
        _progressView = [[UIProgressView alloc] initWithFrame:CGRectMake(0, StatusBarAndNavigationBarHeight + 1, self.view.frame.size.width, 2)];
        _progressView.tintColor = [UIColor blueColor];
        _progressView.trackTintColor = [UIColor clearColor];
    }
    return _progressView;
}

- (WKWebView *)webView{
    
    if(_webView == nil){
   
        
        //创建网页配置对象
        WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
        
        // 创建设置对象
        WKPreferences *preference = [[WKPreferences alloc]init];
        //最小字体大小 当将javaScriptEnabled属性设置为NO时，可以看到明显的效果
        preference.minimumFontSize = 0;
        //设置是否支持javaScript 默认是支持的
        preference.javaScriptEnabled = YES;
        // 在iOS上默认为NO，表示是否允许不经过用户交互由javaScript自动打开窗口
        preference.javaScriptCanOpenWindowsAutomatically = YES;
        config.preferences = preference;
        
        // 是使用h5的视频播放器在线播放, 还是使用原生播放器全屏播放
        config.allowsInlineMediaPlayback = YES;
        //设置视频是否需要用户手动播放  设置为NO则会允许自动播放
        config.requiresUserActionForMediaPlayback = YES;
        //设置是否允许画中画技术 在特定设备上有效
        config.allowsPictureInPictureMediaPlayback = YES;
        //设置请求的User-Agent信息中应用程序名称 iOS9后可用
        config.applicationNameForUserAgent = @"ChinaDailyForiPad";
        
        //自定义的WKScriptMessageHandler 是为了解决内存不释放的问题
        WeakWebViewScriptMessageDelegate *weakScriptMessageDelegate = [[WeakWebViewScriptMessageDelegate alloc] initWithDelegate:self];
        
        //这个类主要用来做native与JavaScript的交互管理
        WKUserContentController * wkUController = [[WKUserContentController alloc] init];
        //添加js全局变量
        WKUserScript *script = [[WKUserScript alloc] initWithSource:@"var interesting = 123;" injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
        //页面加载完成立刻回调，获取页面上的所有Cookie
        WKUserScript *cookieScript = [[WKUserScript alloc] initWithSource:@"                window.webkit.messageHandlers.currentCookies.postMessage(document.cookie);" injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:NO];
//        WKUserScript *userScript = [[WKUserScript alloc] initWithSource:@"                window.webkit.messageHandlers.choosePhoneContact.postMessage(document.userContact);" injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:NO];
        
        //alert Cookie
        //    WKUserScript *alertCookieScript = [[WKUserScript alloc] initWithSource:@"alert(document.cookie);" injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:NO];
        //添加自定义的cookie
        WKUserScript *newCookieScript = [[WKUserScript alloc] initWithSource:@"                document.cookie = 'LynkcoCookie=Lynkco;'" injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
        
        //添加脚本
        [wkUController addUserScript:script];
        [wkUController addUserScript:cookieScript];
//        [wkUController addUserScript:userScript];
        
        //    [controller addUserScript:alertCookieScript];
        [wkUController addUserScript:newCookieScript];
        //注册回调
        [wkUController addScriptMessageHandler:weakScriptMessageDelegate name:@"share"];
        [wkUController addScriptMessageHandler:weakScriptMessageDelegate name:@"currentCookies"];
        [wkUController addScriptMessageHandler:weakScriptMessageDelegate name:@"shareNew"];
        //注册一个name为jsToOcNoPrams的js方法 设置处理接收JS方法的对象
        [wkUController addScriptMessageHandler:weakScriptMessageDelegate  name:@"jsToOcNoPrams"];
        [wkUController addScriptMessageHandler:weakScriptMessageDelegate  name:@"jsToOcWithPrams"];
        
        config.userContentController = wkUController;
        
        //以下代码适配文本大小
        NSString *jSString = @"var meta = document.createElement('meta'); meta.setAttribute('name', 'viewport'); meta.setAttribute('content', 'width=device-width'); document.getElementsByTagName('head')[0].appendChild(meta);";
        //用于进行JavaScript注入
        WKUserScript *wkUScript = [[WKUserScript alloc] initWithSource:jSString injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
        [config.userContentController addUserScript:wkUScript];
        
        _webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height) configuration:config];
        // UI代理
        _webView.UIDelegate = self;
        // 导航代理
        _webView.navigationDelegate = self;
        // 是否允许手势左滑返回上一级, 类似导航控制的左滑返回
        _webView.allowsBackForwardNavigationGestures = YES;
        //可返回的页面列表, 存储已打开过的网页
        WKBackForwardList * backForwardList = [_webView backForwardList];
        
        //        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://www.chinadaily.com.cn"]];
        //        [request addValue:[self readCurrentCookieWithDomain:@"http://www.chinadaily.com.cn"] forHTTPHeaderField:@"Cookie"];
        //        [_webView loadRequest:request];
//        _webView.scrollView.contentInset = UIEdgeInsetsMake(64, 0, 49, 0);
//        [_webView setValue:[NSValue valueWithUIEdgeInsets:self.webView.scrollView.contentInset] forKey:@"_obscuredInsets"];

        NSString *path = [[NSBundle mainBundle] pathForResource:@"test.html" ofType:nil];
        NSString *htmlString = [[NSString alloc]initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        [_webView loadHTMLString:htmlString baseURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]]];
        
    }
    return _webView;
}
//解决第一次进入的cookie丢失问题
- (NSString *)readCurrentCookieWithDomain:(NSString *)domainStr{
    NSHTTPCookieStorage*cookieJar = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSMutableString * cookieString = [[NSMutableString alloc]init];
    for (NSHTTPCookie*cookie in [cookieJar cookies]) {
        [cookieString appendFormat:@"%@=%@;",cookie.name,cookie.value];
    }
    
    //删除最后一个“;”
    if ([cookieString hasSuffix:@";"]) {
        [cookieString deleteCharactersInRange:NSMakeRange(cookieString.length - 1, 1)];
    }
    
    return cookieString;
}

//解决 页面内跳转（a标签等）还是取不到cookie的问题
- (void)getCookie{
    
    //取出cookie
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    //js函数
    NSString *JSFuncString =
    @"function setCookie(name,value,expires)\
    {\
    var oDate=new Date();\
    oDate.setDate(oDate.getDate()+expires);\
    document.cookie=name+'='+value+';expires='+oDate+';path=/'\
    }\
    function getCookie(name)\
    {\
    var arr = document.cookie.match(new RegExp('(^| )'+name+'=([^;]*)(;|$)'));\
    if(arr != null) return unescape(arr[2]); return null;\
    }\
    function delCookie(name)\
    {\
    var exp = new Date();\
    exp.setTime(exp.getTime() - 1);\
    var cval=getCookie(name);\
    if(cval!=null) document.cookie= name + '='+cval+';expires='+exp.toGMTString();\
    }";
    
    //拼凑js字符串
    NSMutableString *JSCookieString = JSFuncString.mutableCopy;
    for (NSHTTPCookie *cookie in cookieStorage.cookies) {
        NSString *excuteJSString = [NSString stringWithFormat:@"setCookie('%@', '%@', 1);", cookie.name, cookie.value];
        [JSCookieString appendString:excuteJSString];
    }
    //执行js
    [_webView evaluateJavaScript:JSCookieString completionHandler:nil];
    
}

- (void)setupNavigationItem{
    // 后退按钮
    UIButton * goBackButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [goBackButton setImage:[UIImage imageNamed:@"backbutton"] forState:UIControlStateNormal];
    [goBackButton addTarget:self action:@selector(goback) forControlEvents:UIControlEventTouchUpInside];
    goBackButton.frame = CGRectMake(0, 0, 30, StatusBarAndNavigationBarHeight);
    UIBarButtonItem * goBackButtonItem = [[UIBarButtonItem alloc] initWithCustomView:goBackButton];
    UIBarButtonItem * goback = [[UIBarButtonItem alloc] initWithTitle:@"后退" style:UIBarButtonItemStyleDone target:self action:@selector(goBackAction:)];
    UIBarButtonItem * jstoOc = [[UIBarButtonItem alloc] initWithTitle:@"首页" style:UIBarButtonItemStyleDone target:self action:@selector(localHtmlClicked)];
    self.navigationItem.leftBarButtonItems = @[goBackButtonItem,goback,jstoOc];
    
    // 刷新按钮
    UIButton * refreshButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [refreshButton setImage:[UIImage imageNamed:@"webRefreshButton"] forState:UIControlStateNormal];
    [refreshButton addTarget:self action:@selector(refreshAction:) forControlEvents:UIControlEventTouchUpInside];
    refreshButton.frame = CGRectMake(0, 0, 30, StatusBarAndNavigationBarHeight);
    UIBarButtonItem * refreshButtonItem = [[UIBarButtonItem alloc] initWithCustomView:refreshButton];
    
    self.navigationItem.rightBarButtonItems = @[refreshButtonItem];
    
}
- (void)goback{
    [self.navigationController popViewControllerAnimated:YES];
}
//kvo 监听进度 必须实现此方法
-(void)observeValueForKeyPath:(NSString *)keyPath
                     ofObject:(id)object
                       change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                      context:(void *)context{
    
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(estimatedProgress))]
        && object == _webView) {
        
        NSLog(@"网页加载进度 = %f",_webView.estimatedProgress);
        self.progressView.progress = _webView.estimatedProgress;
        if (_webView.estimatedProgress >= 1.0f) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.progressView.progress = 0;
            });
        }
        
    }else if([keyPath isEqualToString:@"title"]
             && object == _webView){
        self.navigationItem.title = _webView.title;
    }else{
        [super observeValueForKeyPath:keyPath
                             ofObject:object
                               change:change
                              context:context];
    }
}

#pragma mark -- Event Handle

- (void)goBackAction:(id)sender{
    [_webView goBack];
}

- (void)localHtmlClicked{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"test.html" ofType:nil];
    NSString *htmlString = [[NSString alloc]initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    [_webView loadHTMLString:htmlString baseURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]]];
}

- (void)refreshAction:(id)sender{
    [_webView reload];
}
#pragma mark -- life cycle

- (void)viewDidLoad {
    [super viewDidLoad];
  
    [self setupNavigationItem];
    [self.view addSubview:self.webView];
    [self.view addSubview:self.progressView];
    //更新webView的cookie
    [self updateWebViewCookie];
    //图片添加点击事件
    [self imgAddClickEvent];
    //添加NativeApi
    [self addNativeApiToJS];
    
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"test" ofType:@"html"]]]];
    //可以测试百度还是test
    //    [self loadUrl:@"http://m.baidu.com/"];
    //添加监测网页加载进度的观察者
    [self.webView addObserver:self
                   forKeyPath:NSStringFromSelector(@selector(estimatedProgress))
                      options:0
                      context:nil];
    [self.webView addObserver:self
                   forKeyPath:@"title"
                      options:NSKeyValueObservingOptionNew
                      context:nil];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        //比如我在这个时候保存了Cookie
        [self saveCookie];
    }
    return self;
}

- (void)dealloc
{
    //记得移除
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:@"share"];
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:@"currentCookies"];
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:@"shareNew"];
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:@"imageDidClick"];
    //NativeApi相关
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:@"nativeShare"];
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:@"choosePhoneContact"];
    //移除观察者
    [_webView removeObserver:self
                  forKeyPath:NSStringFromSelector(@selector(estimatedProgress))];
    [_webView removeObserver:self
                  forKeyPath:NSStringFromSelector(@selector(title))];
}

@end
