//
//  RSAptParser.h
//  RepoStore — APT (Debian) Packages 解析
//
//  越狱源的标准清单格式是 APT 的 Packages 文本：
//
//      Package: com.example.tweak
//      Name: 示例插件
//      Version: 1.2.3
//      Architecture: iphoneos-arm
//      Filename: ./debs/com.example.tweak_1.2.3_iphoneos-arm.deb
//      Size: 123456
//      Icon: https://.../icon.png
//      Description: 简介文字
//      Depot:  或 Author:  或 Maintainer:
//      Section: Tweaks
//      Depiction: https://...
//      SileoDepiction: https://...
//      <空行>   ← 包与包之间的分隔
//
//  解析要点：
//  - 条目之间用空行分隔
//  - 字段名后跟 ": "（冒号是可选的，宽松处理）
//  - Description 是唯一可跨行的字段（续行以空格开头）
//  - 同一个 Package 名可能出现多条记录（不同版本），这里保留全部，由上层按名分组
//

#import <Foundation/Foundation.h>
@class RSAppItem;

NS_ASSUME_NONNULL_BEGIN

@interface RSAptParser : NSObject

/// 解析 Packages 文本，返回 RSAppItem 数组。
/// @param text        Packages 原文（已按 UTF-8 解码）
/// @param repoBaseURL 源根地址，用于把 Filename 的相对路径补成完整 URL，如 https://byg.iosios.net/
+ (NSArray<RSAppItem *> *)itemsFromPackagesText:(NSString *)text
                                    repoBaseURL:(NSString *)repoBaseURL;

/// 从 APT 的 Release 文件里取源名（Origin 或 Label 字段）。
/// 越狱源的仓库根目录通常没有首页，只有 Release 声明元信息，
/// 源名要从这里拿，否则界面上只能显示"未命名源"。
+ (nullable NSString *)nameFromReleaseText:(NSString *)text;

/// 判断一段文本看起来像不像 APT Release 文件
+ (BOOL)looksLikeRelease:(NSString *)text;

/// 判断文本是否为 HTML（网页首页），用于识别"地址填错了但服务器返回 200"的情况
+ (BOOL)looksLikeHTML:(NSString *)text;

/// 判断一段文本看起来是不是 APT Packages（而非 JSON / ESign 加密源）
+ (BOOL)looksLikePackages:(NSString *)text;

@end

NS_ASSUME_NONNULL_END
