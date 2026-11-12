#import <Foundation/Foundation.h>
#import "RSAppItem.h"

NS_ASSUME_NONNULL_BEGIN

/// 一个软件源
@interface RSRepo : NSObject

@property (nonatomic, copy) NSString *uid;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy, nullable) NSString *iconURL;
@property (nonatomic, assign) BOOL requiresUnlock;
@property (nonatomic, copy, nullable) NSString *unlockURL;
@property (nonatomic, strong) NSMutableArray<RSAppItem *> *apps;
@property (nonatomic, assign) BOOL isUnlocked;
@property (nonatomic, copy, nullable) NSString *unlockToken;

- (instancetype)initWithURL:(NSString *)url;

/// 用服务器返回的 JSON 更新自身
- (void)applyJSON:(NSDictionary *)json;

/// 序列化 / 反序列化（本地缓存）
- (NSDictionary *)toDictionary;
+ (nullable instancetype)fromDictionary:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
