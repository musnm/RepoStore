#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 源里的一个应用
@interface RSAppItem : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *bundleIdentifier;
@property (nonatomic, copy) NSString *version;
@property (nonatomic, assign) long long size;
@property (nonatomic, copy, nullable) NSString *iconURL;
@property (nonatomic, copy) NSString *downloadURL;
@property (nonatomic, copy) NSString *desc;
@property (nonatomic, copy) NSString *developer;
@property (nonatomic, copy) NSString *category;

/// 唯一 key = bundleid + version
@property (nonatomic, readonly) NSString *itemId;

/// 人类可读大小
@property (nonatomic, readonly) NSString *sizeText;

/// 从宽松字典解析
+ (nullable instancetype)itemFromDictionary:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
