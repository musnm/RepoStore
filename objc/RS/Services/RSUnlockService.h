#import <Foundation/Foundation.h>
#import "RSRepo.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^RSUnlockCompletion)(BOOL ok, NSString * _Nullable token, NSString * _Nullable message);

/// 解锁校验 —— 完全交给源声明的 unlockURL，App 自身不校验任何卡密
/// （与轻松签行为一致：源解锁与客户端无关，成败由源服务器判定）
@interface RSUnlockService : NSObject

+ (void)verifyCode:(NSString *)code
           forRepo:(RSRepo *)repo
        completion:(RSUnlockCompletion)done;

@end

NS_ASSUME_NONNULL_END
