//
//  RSAptParser.m
//  RepoStore — APT Packages 解析
//

#import "RSAptParser.h"
#import "RSAppItem.h"

@implementation RSAptParser

+ (BOOL)looksLikePackages:(NSString *)text {
    if (text.length < 10) return NO;
    // 头部可能带 BOM 或注释，取前 4KB 判断
    NSUInteger n = MIN((NSUInteger)4096, text.length);
    NSString *head = [text substringToIndex:n];
    // 有 "Package:" 且有 "Version:" 基本可以确定是 APT 清单
    return ([head rangeOfString:@"Package:"].location != NSNotFound &&
            [head rangeOfString:@"Version:"].location != NSNotFound);
}

+ (BOOL)looksLikeRelease:(NSString *)text {
    if (text.length < 5) return NO;
    NSUInteger n = MIN((NSUInteger)4096, text.length);
    NSString *head = [text substringToIndex:n];
    // Release 是典型的 Debian 控制段：Origin/Label/Suite/Architectures 之类的键值对
    return ([head rangeOfString:@"Origin:"].location != NSNotFound ||
            [head rangeOfString:@"Label:"].location != NSNotFound ||
            [head rangeOfString:@"Suite:"].location != NSNotFound) &&
            [head rangeOfString:@"<html"].location == NSNotFound;
}

+ (BOOL)looksLikeHTML:(NSString *)text {
    if (text.length < 5) return NO;
    NSUInteger n = MIN((NSUInteger)2048, text.length);
    NSString *head = [[text substringToIndex:n] lowercaseString];
    return [head rangeOfString:@"<!doctype html"].location != NSNotFound ||
           [head rangeOfString:@"<html"].location != NSNotFound;
}

+ (NSString *)nameFromReleaseText:(NSString *)text {
    if (text.length == 0) return nil;
    NSString *src = [text stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];

    NSString *origin = nil, *label = nil;
    for (NSString *raw in [src componentsSeparatedByString:@"\n"]) {
        if (raw.length == 0) break;          // Release 只有一段
        NSRange c = [raw rangeOfString:@":"];
        if (c.location == NSNotFound) continue;
        NSString *k = [[raw substringToIndex:c.location]
                       stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSString *v = [raw substringFromIndex:c.location + 1];
        if ([v hasPrefix:@" "]) v = [v substringFromIndex:1];
        v = [v stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (v.length == 0) continue;

        if ([k caseInsensitiveCompare:@"Origin"] == NSOrderedSame) origin = v;
        else if ([k caseInsensitiveCompare:@"Label"] == NSOrderedSame) label = v;
    }
    // 源名优先 Origin，其次 Label
    NSString *name = origin.length ? origin : label;
    if (name.length == 0) return nil;

    // 有的源用连续的不可见空白做"排版"，去掉多余空白
    name = [name stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    while ([name containsString:@"  "]) {
        name = [name stringByReplacingOccurrencesOfString:@"  " withString:@" "];
    }
    return name.length ? name : nil;
}

+ (NSArray<RSAppItem *> *)itemsFromPackagesText:(NSString *)text
                                    repoBaseURL:(NSString *)repoBaseURL {
    if (text.length == 0) return @[];

    // 统一换行
    NSString *src = [text stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
    src = [src stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];

    NSArray<NSString *> *lines = [src componentsSeparatedByString:@"\n"];

    NSMutableArray<RSAppItem *> *out = [NSMutableArray array];
    NSMutableDictionary<NSString *, NSString *> *cur = [NSMutableDictionary dictionary];
    __block NSString *lastKey = nil;

    // 一条记录结束：转成 RSAppItem 并加入结果
    void (^flush)(void) = ^{
        if (cur.count == 0) { lastKey = nil; return; }

        NSString *pkg = cur[@"Package"];
        NSString *filename = cur[@"Filename"];

        // 没有 Package 名或没有下载地址的条目直接丢弃
        if (pkg.length > 0 && filename.length > 0) {
            RSAppItem *it = [self itemFromRecord:cur repoBaseURL:repoBaseURL];
            if (it) [out addObject:it];
        }
        [cur removeAllObjects];
        lastKey = nil;
    };

    for (NSString *raw in lines) {
        // 空行 = 记录分隔
        if (raw.length == 0) {
            flush();
            continue;
        }
        // 注释行
        if ([raw hasPrefix:@"#"]) continue;

        // 续行：以空格或制表符开头，且上一条是 Description 之类可多行的字段
        if (([raw hasPrefix:@" "] || [raw hasPrefix:@"\t"]) && lastKey.length > 0) {
            NSString *prev = cur[lastKey] ?: @"";
            NSString *cont = [raw stringByTrimmingCharactersInSet:
                              [NSCharacterSet whitespaceCharacterSet]];
            // 只有描述类字段保留多行；其余字段忽略续行
            if ([lastKey isEqualToString:@"Description"] ||
                [lastKey isEqualToString:@"Homepage"]) {
                cur[lastKey] = prev.length ? [prev stringByAppendingFormat:@"\n%@", cont] : cont;
            }
            continue;
        }

        NSRange colon = [raw rangeOfString:@":"];
        if (colon.location == NSNotFound || colon.location == 0) continue;

        NSString *key = [raw substringToIndex:colon.location];
        NSString *val = [raw substringFromIndex:colon.location + 1];
        // 去掉值前面多余的一个空格
        if ([val hasPrefix:@" "]) val = [val substringFromIndex:1];

        key = [key stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (key.length == 0) continue;

        // 同名键（多行字段重复出现）用换行拼接
        NSString *exist = cur[key];
        if (exist.length) {
            cur[key] = [exist stringByAppendingFormat:@"\n%@", val];
        } else {
            cur[key] = val;
        }
        lastKey = key;
    }
    flush();

    return out;
}

/// 把一条 APT 记录转成 RSAppItem
+ (nullable RSAppItem *)itemFromRecord:(NSDictionary<NSString *, NSString *> *)r
                           repoBaseURL:(NSString *)base {
    NSString *pkg = r[@"Package"];
    NSString *filename = r[@"Filename"];
    if (pkg.length == 0 || filename.length == 0) return nil;

    RSAppItem *it = [[RSAppItem alloc] init];

    // ── 显示名：优先 Name，其次 Package
    NSString *name = r[@"Name"];
    if (name.length == 0) name = r[@"Package"];
    it.name = [self clean:name];

    // ── 包标识
    it.bundleIdentifier = pkg;
    it.packageName = pkg;
    it.fromAPT = YES;

    // ── 版本
    NSString *ver = r[@"Version"];
    it.version = ver.length ? [self clean:ver] : @"1.0";

    // ── 架构：同版本常有 arm / arm64 两条记录
    NSString *arch = [self clean:r[@"Architecture"]];
    if (arch.length) it.architecture = arch;

    // ── 下载地址：Filename 可能是相对路径
    it.downloadURL = [self absoluteURL:[self clean:filename] base:base];
    if (it.downloadURL.length == 0) return nil;

    // ── 类型：deb 视为插件，其余压缩包/ipa 视为应用类资源
    NSString *lowPath = it.downloadURL.lowercaseString;
    it.isPlugin = [lowPath containsString:@".deb"];

    // ── 图标：Icon 可能是相对路径
    NSString *icon = r[@"Icon"];
    if (icon.length) {
        it.iconURL = [self absoluteURL:[self clean:icon] base:base];
    }

    // ── 大小
    NSString *sizeStr = r[@"Size"];
    it.size = sizeStr.length ? (long long)sizeStr.longLongValue : 0;

    // ── 简介
    NSString *desc = r[@"Description"];
    if (desc.length == 0) desc = r[@"Summary"];
    it.localizedDescription = [self clean:desc] ?: @"";

    // ── 作者：Author 形如 "Name <mail@example.com>"，只留名字
    NSString *author = r[@"Author"];
    if (author.length == 0) author = r[@"Maintainer"];
    if (author.length == 0) author = r[@"Depot"];
    if (author.length) {
        it.developerName = [self cleanAuthor:author];
    }

    // ── 分类：categoryName 是只读属性（由描述推导），这里把 Section 补进描述
    NSString *section = [self clean:r[@"Section"]];
    if (section.length) {
        NSString *base = it.localizedDescription ?: @"";
        if ([base rangeOfString:@"分类："].location == NSNotFound) {
            it.localizedDescription = base.length
                ? [NSString stringWithFormat:@"%@\n分类：%@", base, section]
                : [NSString stringWithFormat:@"分类：%@", section];
        }
    }

    // ── 版本日期（APT 里是 ISO 串，转成 xxxx-xx-xx）
    NSString *date = r[@"Date"];
    if (date.length >= 10) {
        it.versionDate = [date substringToIndex:10];
    }

    return it;
}

#pragma mark - 工具

+ (NSString *)clean:(NSString *)s {
    if (![s isKindOfClass:[NSString class]]) return @"";
    NSString *t = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    // 有些源把换行写成字面 "\n"（反斜杠+n），显示前还原
    if ([t containsString:@"\\n"]) {
        t = [t stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"];
    }
    // 极少数源残留 \r
    t = [t stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    return t;
}

/// "Name <mail@x.com>" → "Name"
+ (NSString *)cleanAuthor:(NSString *)s {
    NSString *t = [self clean:s];
    NSRange lt = [t rangeOfString:@"<"];
    if (lt.location != NSNotFound) {
        t = [[t substringToIndex:lt.location]
             stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }
    return t;
}

/// 把相对路径补成绝对 URL。
/// Filename 常见形态："./debs/x.deb"、"debs/x.deb"、"x.deb"、以及已经完整的 "https://..."
+ (NSString *)absoluteURL:(NSString *)path base:(NSString *)base {
    if (path.length == 0) return @"";

    // 已是完整 URL
    if ([path hasPrefix:@"http://"] || [path hasPrefix:@"https://"]) return path;
    // 协议相对
    if ([path hasPrefix:@"//"]) {
        return [@"https:" stringByAppendingString:path];
    }

    if (base.length == 0) return path;

    NSMutableString *root = [base mutableCopy];
    if (![root hasSuffix:@"/"]) [root appendString:@"/"];

    NSString *rel = path;
    // 去掉前导 "./" 和多余的 "/"
    while ([rel hasPrefix:@"./"]) {
        rel = [rel substringFromIndex:2];
    }
    while ([rel hasPrefix:@"/"]) {
        rel = [rel substringFromIndex:1];
    }

    return [root stringByAppendingString:rel];
}

@end
