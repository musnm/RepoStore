#import "RSAppItem.h"

@implementation RSAppItem

- (instancetype)init {
    if (self = [super init]) {
        _name = @"";
        _bundleIdentifier = @"";
        _developerName = @"";
        _version = @"";
        _versionDate = @"";
        _versionDescription = @"";
        _localizedDescription = @"";
        _downloadURL = @"";
        _tintColor = @"";
        _size = 0;
        _type = 1;
        _isLanZouCloud = 0;
    }
    return self;
}

- (NSString *)itemId {
    // 必须带上架构：arm64 与 arm64e 是同一个包名、同一个版本号，
    // 但下载地址和产物完全不同。少了这一段，两边的下载缓存会互相串用。
    NSString *arch = self.architecture.lowercaseString ?: @"";
    NSString *archKey = @"";
    if ([arch containsString:@"arm64e"]) archKey = @"-arm64e";
    else if ([arch containsString:@"arm64"]) archKey = @"-arm64";
    else if ([arch containsString:@"arm"]) archKey = @"-arm";

    return [NSString stringWithFormat:@"%@@%@%@",
            self.bundleIdentifier, self.version, archKey];
}

- (NSString *)sizeText {
    if (self.size <= 0) return @"";
    NSByteCountFormatter *f = [[NSByteCountFormatter alloc] init];
    f.countStyle = NSByteCountFormatterCountStyleFile;
    return [f stringFromByteCount:self.size];
}

/// 公告/通知/占位条目判定：没有有效下载地址、或体积不合理 —— 都不当作可下载应用。
/// 体积门槛是保险：真实安装包最小也在 1KB 以上（实测最小 1520 字节的有效 deb），
/// 所以低于 1KB 的必然不是可用文件，直接拒掉。
static const long long kMinValidSize = 1024;   // 1 KB

- (BOOL)isDownloadable {
    if (self.downloadURL.length == 0) return NO;
    NSString *s = [self.downloadURL lowercaseString];
    // 占位地址
    if ([s isEqualToString:@"#" ] || [s hasPrefix:@"javascript:"] ||
        [s hasPrefix:@"about:"] || [s hasPrefix:@"tel:"] || [s hasPrefix:@"mailto:"]) {
        return NO;
    }
    if (![s hasPrefix:@"http"]) return NO;

    // 体积必须已知且合理 —— 不知道大小就无法确认这是个真文件
    if (self.size <= 0) return NO;
    if (self.size < kMinValidSize) return NO;

    // 体积达标即放行，不区分来源格式（deb / ipa / zip / 存档都能下）
    return YES;
}

- (BOOL)isDirectIPA {
    NSString *s = [self.downloadURL lowercaseString];
    // 蓝奏云等中转链接不算直链
    if (self.isLanZouCloud) return NO;
    if ([s hasSuffix:@".ipa"]) return YES;
    if ([s containsString:@".ipa?"]) return YES;
    return NO;
}

- (NSString *)categoryName {
    // 从 localizedDescription 里找 "分类：xxx"
    NSString *d = self.localizedDescription;
    if (d.length == 0) return @"";
    NSArray<NSString *> *keys = @[@"分类：", @"分类:", @"类型：", @"类型:"];
    NSArray<NSString *> *lines = [d componentsSeparatedByCharactersInSet:
                                  [NSCharacterSet newlineCharacterSet]];
    for (NSString *line in lines) {
        for (NSString *k in keys) {
            NSRange r = [line rangeOfString:k];
            if (r.location != NSNotFound) {
                NSString *rest = [line substringFromIndex:r.location + r.length];
                return [rest stringByTrimmingCharactersInSet:
                        [NSCharacterSet whitespaceCharacterSet]];
            }
        }
    }
    return @"";
}

static NSString *RSStr(id v) {
    if ([v isKindOfClass:[NSString class]]) return v;
    if ([v isKindOfClass:[NSNumber class]]) return [v stringValue];
    return nil;
}

static NSInteger RSInt(id v) {
    if ([v isKindOfClass:[NSNumber class]]) return [v integerValue];
    if ([v isKindOfClass:[NSString class]]) return [(NSString *)v integerValue];
    return 0;
}

+ (instancetype)itemFromDictionary:(NSDictionary *)d {
    if (![d isKindOfClass:[NSDictionary class]]) return nil;

    NSString *name = RSStr(d[@"name"]);
    if (name.length == 0) return nil;

    // 主要字段 downloadURL；兼容 url / downloadUrl
    NSString *dl = RSStr(d[@"downloadURL"])
                ?: RSStr(d[@"downloadUrl"])
                ?: RSStr(d[@"url"]);
    if (dl.length == 0) return nil;

    RSAppItem *it = [[RSAppItem alloc] init];
    it.name = name;
    it.bundleIdentifier = RSStr(d[@"bundleIdentifier"])
                       ?: RSStr(d[@"bundleid"])
                       ?: RSStr(d[@"bundleID"])
                       ?: [NSString stringWithFormat:@"unknown.%@", name];
    it.version = RSStr(d[@"version"]) ?: @"1.0";
    it.downloadURL = dl;

    it.iconURL = RSStr(d[@"iconURL"]) ?: RSStr(d[@"icon"]);
    it.versionDate = RSStr(d[@"versionDate"]) ?: @"";
    it.versionDescription = RSStr(d[@"versionDescription"]) ?: @"";

    // 真实字段 localizedDescription；兼容 description / desc
    it.localizedDescription = RSStr(d[@"localizedDescription"])
                           ?: RSStr(d[@"description"])
                           ?: RSStr(d[@"desc"])
                           ?: @"";

    // 真实字段 developerName；兼容 developer / author
    it.developerName = RSStr(d[@"developerName"])
                    ?: RSStr(d[@"developer"])
                    ?: RSStr(d[@"author"])
                    ?: @"";

    NSString *tc = RSStr(d[@"tintColor"]);
    if (tc.length) it.tintColor = tc;

    it.size = (long long)RSInt(d[@"size"]);
    if (d[@"type"]) it.type = RSInt(d[@"type"]) ?: 1;
    if (d[@"isLanZouCloud"]) it.isLanZouCloud = RSInt(d[@"isLanZouCloud"]);

    // APT 来源标记及其附属字段，需从磁盘还原，否则重启后 apt 包会被误判为"公告"
    if (d[@"fromAPT"]) it.fromAPT = RSInt(d[@"fromAPT"]) != 0;
    if ([d[@"packageName"] isKindOfClass:[NSString class]]) it.packageName = d[@"packageName"];
    if ([d[@"architecture"] isKindOfClass:[NSString class]]) it.architecture = d[@"architecture"];

    if ([d[@"versions"] isKindOfClass:[NSArray class]]) {
        NSMutableArray *vs = [NSMutableArray array];
        for (id vd in d[@"versions"]) {
            RSAppItem *v = [RSAppItem itemFromDictionary:vd];
            if (v) [vs addObject:v];
        }
        if (vs.count) it.versions = vs;
    }

    return it;
}

- (NSString *)architectureDisplayName {
    NSString *a = self.architecture.lowercaseString ?: @"";
    if ([a containsString:@"arm64e"]) return @"隐根越狱 (arm64e)";
    if ([a containsString:@"arm64"]) return @"无根越狱 (arm64)";
    if ([a containsString:@"arm"]) return @"旧版 32 位 (arm)";
    if (a.length == 0) return @"架构未知";
    return self.architecture;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *d = [@{
        @"name": self.name ?: @"",
        @"bundleIdentifier": self.bundleIdentifier ?: @"",
        @"developerName": self.developerName ?: @"",
        @"version": self.version ?: @"",
        @"versionDate": self.versionDate ?: @"",
        @"versionDescription": self.versionDescription ?: @"",
        @"localizedDescription": self.localizedDescription ?: @"",
        @"downloadURL": self.downloadURL ?: @"",
        @"iconURL": self.iconURL ?: @"",
        @"tintColor": self.tintColor ?: @"",
        @"size": @(self.size),
        @"type": @(self.type),
        @"isLanZouCloud": @(self.isLanZouCloud),
        @"fromAPT": @(self.fromAPT),
    } mutableCopy];

    if (self.packageName.length) d[@"packageName"] = self.packageName;
    if (self.architecture.length) d[@"architecture"] = self.architecture;

    // 其它版本递归保存；每个版本自身不再挂 versions，避免无限嵌套
    if (self.versions.count) {
        NSMutableArray *vs = [NSMutableArray array];
        for (RSAppItem *v in self.versions) {
            NSArray<RSAppItem *> *saved = v.versions;
            v.versions = nil;
            [vs addObject:[v toDictionary]];
            v.versions = saved;
        }
        d[@"versions"] = vs;
    }
    return d;
}

@end
