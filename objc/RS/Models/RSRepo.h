#import <Foundation/Foundation.h>
#import "RSAppItem.h"

NS_ASSUME_NONNULL_BEGIN

/// 一个软件源 —— 字段对齐轻松签/全能签名（Source.json）
@interface RSRepo : NSObject

@property (nonatomic, copy) NSString *uid;
/// 用户填写的源地址
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *identifier;
/// 真实字段 sourceURL（源自己声明的地址）
@property (nonatomic, copy, nullable) NSString *sourceURL;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy, nullable) NSString *iconURL;
@property (nonatomic, copy) NSString *tintColor;
@property (nonatomic, assign) BOOL requiresUnlock;
@property (nonatomic, copy, nullable) NSString *unlockURL;
@property (nonatomic, strong) NSMutableArray<RSAppItem *> *apps;
@property (nonatomic, assign) BOOL isUnlocked;
@property (nonatomic, copy, nullable) NSString *unlockToken;
/// 上次刷新时间
@property (nonatomic, strong, nullable) NSDate *lastUpdated;
/// 上次刷新失败原因（用于界面提示）
@property (nonatomic, copy, nullable) NSString *lastError;

- (instancetype)initWithURL:(NSString *)url;

/// 用服务器返回的 JSON 更新自身；返回识别到的应用数
- (NSInteger)applyJSON:(NSDictionary *)json;

- (NSDictionary *)toDictionary;
+ (nullable instancetype)fromDictionary:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
