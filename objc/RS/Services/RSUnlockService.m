#import "RSUnlockService.h"
#import <UIKit/UIKit.h>
#import <sys/sysctl.h>
#import <stdlib.h>

@implementation RSUnlockService

+ (NSString *)deviceModel {
    @try {
        size_t size = 0;
        sysctlbyname("hw.machine", NULL, &size, NULL, 0);
        if (size == 0) return @"iPhone";
        char *machine = malloc(size);
        if (!machine) return @"iPhone";
        sysctlbyname("hw.machine", machine, &size, NULL, 0);
        NSString *s = [NSString stringWithCString:machine encoding:NSUTF8StringEncoding];
        free(machine);
        return s.length ? s : @"iPhone";
    } @catch (NSException *e) {
        return @"iPhone";
    }
}

+ (void)verifyCode:(NSString *)code
           forRepo:(RSRepo *)repo
        completion:(RSUnlockCompletion)done {
    NSString *c = [code stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (c.length == 0) {
        done(NO, nil, @"请输入解锁码");
        return;
    }

    // 解锁完全由源声明的 unlockURL 决定，App 自身不校验任何卡密
    NSString *unlockURL = repo.unlockURL;
    if (unlockURL.length == 0) {
        done(NO, nil, @"该源未提供解锁地址");
        return;
    }

    NSURL *u = [NSURL URLWithString:unlockURL];
    if (!u) {
        done(NO, nil, @"源解锁地址错误，无法解锁");
        return;
    }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:u];
    req.HTTPMethod = @"POST";
    req.timeoutInterval = 15;
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:@"RepoStore/1.0 (iOS)" forHTTPHeaderField:@"User-Agent"];

    NSDictionary *body = @{
        @"code": c,
        @"repo": repo.url ?: @"",
        @"identifier": repo.identifier ?: @"",
        @"device": [self deviceModel],
        @"os": [[UIDevice currentDevice] systemVersion] ?: @"",
    };
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    NSURLSessionDataTask *task =
    [[NSURLSession sharedSession] dataTaskWithRequest:req
                                   completionHandler:^(NSData *data, NSURLResponse *resp, NSError *error) {
        NSInteger status = 200;
        if ([resp isKindOfClass:[NSHTTPURLResponse class]]) {
            status = [(NSHTTPURLResponse *)resp statusCode];
        }

        if (error) {
            // 网络失败：不解锁，交回提示。不做任何本地放行。
            dispatch_async(dispatch_get_main_queue(), ^{
                done(NO, nil, error.localizedDescription ?: @"无法连接解锁服务器");
            });
            return;
        }

        id json = nil;
        if (data.length > 0) {
            json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        }

        BOOL ok = NO;
        NSString *token = nil;
        NSString *msg = nil;

        if ([json isKindOfClass:[NSDictionary class]]) {
            NSDictionary *d = json;
            id v = d[@"ok"] ?: d[@"success"] ?: d[@"valid"];
            if ([v isKindOfClass:[NSNumber class]]) ok = [v boolValue];
            id t = d[@"token"] ?: d[@"key"];
            if ([t isKindOfClass:[NSString class]]) token = t;
            id m = d[@"message"] ?: d[@"error"];
            if ([m isKindOfClass:[NSString class]]) msg = m;
        } else if ([json isKindOfClass:[NSNumber class]]) {
            ok = [json boolValue];
        }

        if (status < 200 || status >= 300) ok = NO;
        if (!ok && !msg) msg = @"解锁码无效";

        dispatch_async(dispatch_get_main_queue(), ^{
            done(ok, token, msg);
        });
    }];
    [task resume];
}

@end
