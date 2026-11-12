#import "RSInstallService.h"

@implementation RSInstallService

+ (BOOL)trollStoreInstall:(NSURL *)ipaURL {
    if (!ipaURL) return NO;
    NSString *raw = ipaURL.absoluteString;
    NSString *encoded = [raw stringByAddingPercentEncodingWithAllowedCharacters:
                         [NSCharacterSet URLQueryAllowedCharacterSet]];
    NSArray<NSString *> *schemes = @[
        [NSString stringWithFormat:@"apple-magnifier://install?url=%@", encoded],
        [NSString stringWithFormat:@"trollstore://install?url=%@", encoded],
    ];
    for (NSString *s in schemes) {
        NSURL *u = [NSURL URLWithString:s];
        if (u && [[UIApplication sharedApplication] canOpenURL:u]) {
            [[UIApplication sharedApplication] openURL:u options:@{} completionHandler:nil];
            return YES;
        }
    }
    return NO;
}

+ (void)shareFile:(NSURL *)fileURL from:(UIViewController *)vc {
    if (!fileURL || !vc) return;

    UIActivityViewController *act = [[UIActivityViewController alloc]
                                     initWithActivityItems:@[fileURL]
                                     applicationActivities:nil];

    // 关键修复：剔除「隔空投送」。
    // AirDrop 项会在后台线程调用 _applicationIconImageForFormat 渲染本机 App 图标，
    // 而 TrollStore 签名的 App 缺少标准图标缓存，LICreateIconForImage 拿到空图像后
    // 在 CoreImage GLContext 里段错误（见 021843/021041 崩溃日志第 18 帧
    // -[UIAirDropActivity _activityImage]）。
    NSMutableArray *excluded = [NSMutableArray array];
    #ifdef UIActivityTypeAirDrop
    [excluded addObject:UIActivityTypeAirDrop];
    #else
    [excluded addObject:@"com.apple.UIKit.activity.AirDrop"];
    #endif
    // 这两个也需要渲染联系人/书签图标，同样规避
    [excluded addObject:UIActivityTypeAssignToContact];
    [excluded addObject:UIActivityTypeAddToReadingList];
    act.excludedActivityTypes = excluded;

    if ([act respondsToSelector:@selector(popoverPresentationController)]) {
        act.popoverPresentationController.sourceView = vc.view;
        act.popoverPresentationController.sourceRect =
            CGRectMake(vc.view.bounds.size.width / 2, vc.view.bounds.size.height / 2, 1, 1);
        act.popoverPresentationController.permittedArrowDirections = 0;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [vc presentViewController:act animated:YES completion:nil];
    });
}

+ (void)toast:(NSString *)msg in:(UIViewController *)vc {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:nil
                                                              message:msg
                                                       preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [vc presentViewController:a animated:YES completion:nil];
}

@end
