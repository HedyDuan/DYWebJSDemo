//
//  NSHTTPCookie+Utils.m
//  DYWebJSDemo
//
//  Created by Coder_Hedy on 2019/8/17.
//  Copyright © 2019 Coder_Hedy. All rights reserved.
//

#import "NSHTTPCookie+Utils.h"

@implementation NSHTTPCookie (Utils)

- (NSString *)dy_javascriptString {
    NSString *string = [NSString stringWithFormat:@"%@=%@;domin=%@;path = %@",self.name,self.value,self.domain,self.path? :@"/"];
    if (self.secure) {
        string = [string stringByAppendingString:@";secure=ture"];
    }
    return string;
}

@end
