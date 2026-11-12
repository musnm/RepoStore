#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 源里的一个应用 —— 字段对齐轻松签/全能签真实格式
@interface RSAppItem : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *bundleIdentifier;
@property (nonatomic, copy) NSString *developerName;      // 真实字段：developerName
@property (nonatomic, copy) NSString *version;
@property (nonatomic, copy) NSString *versionDate;
@property (nonatomic, copy) NSString *versionDescription;
@property (nonatomic, copy) NSString *localizedDescription; // 真实字段：localizedDescription
@property (nonatomic, copy) NSString *downloadURL;
@property (nonatomic, copy, nullable) NSString *iconURL;
@property (nonatomic, copy) NSString *tintColor;          // 形如 "4361ee"
@property (nonatomic, assign) long long size;
@property (nonatomic, assign) NSInteger type;             // 1 = 普通
@property (nonatomic, assign) NSInteger isLanZouCloud;    // 1 = 蓝奏云链接

@property (nonatomic, readonly) NSString *itemId;
@property (nonatomic, readonly) NSString *sizeText;
/// 下载地址是否是可直链的 IPA（.ipa 结尾）
@property (nonatomic, readonly) BOOL isDirectIPA;
/// 分类（从 localizedDescription 里 "分类：xxx" 提取）
@property (nonatomic, readonly) NSString *categoryName;

+ (nullable instancetype)itemFromDictionary:(NSDictionary *)dict;
- (NSDictionary *)toDictionary;

@end

NS_ASSUME_NONNULL_END
