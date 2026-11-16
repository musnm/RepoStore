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

/// 来自 APT 越狱源（Packages 文件）。仅作来源标记，
/// 下载资格仍与其他源一致：必须有有效地址，且体积必须已知且在合理范围内。
@property (nonatomic, assign) BOOL fromAPT;

/// APT 包名（Package: 字段），与 bundleIdentifier 可能不同
@property (nonatomic, copy, nullable) NSString *packageName;

/// 同一插件的其它版本（含当前版本本身，按版本从新到旧）。
/// 仅 APT 源且存在多版本时有值，供详情页做版本选择。
@property (nonatomic, copy, nullable) NSArray<RSAppItem *> *versions;

/// 是否为插件（deb 包）。用于在界面上区分"插件"与"应用"数量。
@property (nonatomic, assign) BOOL isPlugin;

/// 架构的中文说明，用于界面区分：
/// arm64 = 无根越狱(rootless)，arm64e = 隐根越狱(rootHide)，arm = 旧 32 位
- (NSString *)architectureDisplayName;

/// APT 包架构（Architecture: 字段），如 iphoneos-arm / iphoneos-arm64。
/// 同一版本常有 arm / arm64 两条记录。
@property (nonatomic, copy, nullable) NSString *architecture;

@property (nonatomic, readonly) NSString *itemId;
@property (nonatomic, readonly) NSString *sizeText;
/// 下载地址是否是可直链的 IPa（.ipa 结尾）
@property (nonatomic, readonly) BOOL isDirectIPA;
/// 是否是可下载的应用（有下载地址 + 有体积，否则视为公告/通知/占位条目）
@property (nonatomic, readonly) BOOL isDownloadable;
/// 分类（从 localizedDescription 里 "分类：xxx" 提取）
@property (nonatomic, readonly) NSString *categoryName;

+ (nullable instancetype)itemFromDictionary:(NSDictionary *)dict;
- (NSDictionary *)toDictionary;

@end

NS_ASSUME_NONNULL_END
