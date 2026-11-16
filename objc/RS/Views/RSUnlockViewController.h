#import <UIKit/UIKit.h>
#import "RSRepo.h"

NS_ASSUME_NONNULL_BEGIN

@interface RSUnlockViewController : UIViewController
@property (nonatomic, strong) RSRepo *repo;
/// 解锁成功后的回调（可选）：用于成功后自动进入源
@property (nonatomic, copy, nullable) void (^onUnlocked)(void);
@end

NS_ASSUME_NONNULL_END
