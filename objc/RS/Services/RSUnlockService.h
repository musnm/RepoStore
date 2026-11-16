#import <Foundation/Foundation.h>
#import "RSRepo.h"

NS_ASSUME_NONNULL_BEGIN

@interface RSUnlockService : NSObject

/// 校验解锁码，成功时回传 token
+ (void)verifyCode:(NSString *)code
           forRepo:(RSRepo *)repo
        completion:(void (^)(BOOL ok, NSString * _Nullable token, NSString * _Nullable msg))completion;

@end

NS_ASSUME_NONNULL_END
