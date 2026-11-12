#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface RSInstallService : NSObject

/// 尝试用 TrollStore 安装
+ (BOOL)trollStoreInstall:(NSURL *)ipaURL;

/// 弹出系统分享面板
+ (void)shareFile:(NSURL *)fileURL from:(UIViewController *)vc;

/// 简单提示
+ (void)toast:(NSString *)msg in:(UIViewController *)vc;

@end

NS_ASSUME_NONNULL_END
