#import <Foundation/Foundation.h>
#import "RSRepo.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^RSUnlockCompletion)(BOOL ok, NSString *_Nullable token, NSString *_Nullable message);

@interface RSUnlockService : NSObject

/// 校验解锁码：有 unlockURL 走远程，失败回落本地表
+ (void)verifyCode:(NSString *)code
           forRepo:(RSRepo *)repo
        completion:(RSUnlockCompletion)done;

@end

NS_ASSUME_NONNULL_END
