#import "RSAppDelegate.h"
#import "RSRepoListViewController.h"
#import "RSStore.h"
#import "RSTheme.h"

@implementation RSAppDelegate

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [RSTheme bg];

    RSRepoListViewController *list = [RSRepoListViewController new];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:list];
    nav.navigationBar.prefersLargeTitles = YES;
    nav.navigationBar.tintColor = [UIColor whiteColor];

    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];

    // 全局深色
    if (@available(iOS 13.0, *)) {
        self.window.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    }

    return YES;
}

@end
