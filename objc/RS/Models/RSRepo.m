#import "RSRepo.h"

@implementation RSRepo

- (instancetype)initWithURL:(NSString *)url {
    if (self = [super init]) {
        _uid = [[NSUUID UUID] UUIDString];
        _url = [url copy];
        _name = @"";
        _identifier = @"";
        _subtitle = @"";
        _tintColor = @"";
        _apps = [NSMutableArray array];
        _requiresUnlock = NO;
        _isUnlocked = NO;
    }
    return self;
}

static NSString *RSStr3(id v) {
    if ([v isKindOfClass:[NSString class]]) return v;
    if ([v isKindOfClass:[NSNumber class]]) return [v stringValue];
    return nil;
}

- (NSInteger)applyJSON:(NSDictionary *)json {
    if (![json isKindOfClass:[NSDictionary class]]) return 0;

    NSString *n = RSStr3(json[@"name"]);
    if (n.length) self.name = n;

    NSString *ident = RSStr3(json[@"identifier"]);
    if (ident.length) self.identifier = ident;

    NSString *su = RSStr3(json[@"sourceURL"]);
    if (su.length) self.sourceURL = su;

    NSString *sub = RSStr3(json[@"subtitle"]) ?: RSStr3(json[@"description"]);
    if (sub.length) self.subtitle = sub;

    NSString *ico = RSStr3(json[@"iconURL"]) ?: RSStr3(json[@"icon"]);
    if (ico.length) self.iconURL = ico;

    NSString *tc = RSStr3(json[@"tintColor"]);
    if (tc.length) self.tintColor = tc;

    id ru = json[@"requiresUnlock"] ?: json[@"locked"];
    if ([ru isKindOfClass:[NSNumber class]]) self.requiresUnlock = [ru boolValue];
    else if ([ru isKindOfClass:[NSString class]])
        self.requiresUnlock = [(NSString *)ru boolValue];

    NSString *uu = RSStr3(json[@"unlockURL"]);
    if (uu.length) self.unlockURL = uu;

    if (self.name.length == 0) {
        NSURL *u = [NSURL URLWithString:self.url];
        self.name = u.host.length ? u.host : @"未命名源";
    }

    NSArray *rawApps = nil;
    for (NSString *k in @[@"apps", @"packages", @"items", @"list"]) {
        id v = json[k];
        if ([v isKindOfClass:[NSArray class]]) { rawApps = v; break; }
    }
    if (!rawApps) rawApps = @[];

    NSMutableArray *list = [NSMutableArray array];
    for (id a in rawApps) {
        if (![a isKindOfClass:[NSDictionary class]]) continue;
        RSAppItem *it = [RSAppItem itemFromDictionary:a];
        if (it) [list addObject:it];
    }
    self.apps = list;
    return (NSInteger)list.count;
}

- (NSDictionary *)toDictionary {
    NSMutableArray *arr = [NSMutableArray array];
    for (RSAppItem *a in self.apps) {
        [arr addObject:[a toDictionary]];
    }
    return @{
        @"uid": self.uid ?: @"",
        @"url": self.url ?: @"",
        @"name": self.name ?: @"",
        @"identifier": self.identifier ?: @"",
        @"sourceURL": self.sourceURL ?: @"",
        @"subtitle": self.subtitle ?: @"",
        @"iconURL": self.iconURL ?: @"",
        @"tintColor": self.tintColor ?: @"",
        @"requiresUnlock": @(self.requiresUnlock),
        @"unlockURL": self.unlockURL ?: @"",
        @"isUnlocked": @(self.isUnlocked),
        @"unlockToken": self.unlockToken ?: @"",
        @"apps": arr,
    };
}

+ (instancetype)fromDictionary:(NSDictionary *)d {
    if (![d isKindOfClass:[NSDictionary class]]) return nil;
    NSString *url = RSStr3(d[@"url"]);
    if (url.length == 0) return nil;

    RSRepo *r = [[RSRepo alloc] initWithURL:url];
    NSString *uid = RSStr3(d[@"uid"]);
    if (uid.length) r.uid = uid;
    r.name = RSStr3(d[@"name"]) ?: @"";
    r.identifier = RSStr3(d[@"identifier"]) ?: @"";
    r.sourceURL = RSStr3(d[@"sourceURL"]);
    r.subtitle = RSStr3(d[@"subtitle"]) ?: @"";
    r.iconURL = RSStr3(d[@"iconURL"]);
    r.tintColor = RSStr3(d[@"tintColor"]) ?: @"";
    r.unlockURL = RSStr3(d[@"unlockURL"]);
    r.unlockToken = RSStr3(d[@"unlockToken"]);

    id ru = d[@"requiresUnlock"];
    if ([ru isKindOfClass:[NSNumber class]]) r.requiresUnlock = [ru boolValue];
    id iu = d[@"isUnlocked"];
    if ([iu isKindOfClass:[NSNumber class]]) r.isUnlocked = [iu boolValue];

    NSArray *arr = d[@"apps"];
    if ([arr isKindOfClass:[NSArray class]]) {
        for (id a in arr) {
            if (![a isKindOfClass:[NSDictionary class]]) continue;
            RSAppItem *it = [RSAppItem itemFromDictionary:a];
            if (it) [r.apps addObject:it];
        }
    }
    return r;
}

#pragma mark - APT 源

/// 把 Architecture 字段归一化成简短标识，用于去重与界面显示。
/// iphoneos-arm64 → arm64（无根越狱）
/// iphoneos-arm64e → arm64e（隐根越狱）
/// iphoneos-arm → arm（旧 32 位）
- (NSString *)normalizedArch:(NSString *)arch {
    NSString *a = arch.lowercaseString ?: @"";
    if (a.length == 0) return @"unknown";
    if ([a containsString:@"arm64e"]) return @"arm64e";
    if ([a containsString:@"arm64"]) return @"arm64";
    if ([a containsString:@"arm"]) return @"arm";
    return a;
}

/// 当前设备是否偏好 arm64 架构的包。
/// 用指针宽度判断：64 位设备（arm64e / arm64）用 arm64 包，32 位用 arm 包。
- (BOOL)currentDevicePrefersArm64 {
    return sizeof(void *) == 8;
}

- (NSInteger)applyAPTItems:(NSArray<RSAppItem *> *)items {
    if (![items isKindOfClass:[NSArray class]] || items.count == 0) return 0;

    // 按 Package 名分组，组内按版本从新到旧，保持源里原有的包顺序
    NSMutableArray<NSString *> *order = [NSMutableArray array];
    NSMutableDictionary<NSString *, NSMutableArray<RSAppItem *> *> *groups =
        [NSMutableDictionary dictionary];

    NSInteger dropped = 0;
    for (RSAppItem *a in items) {
        if (![a isKindOfClass:[RSAppItem class]]) continue;

        // 保险：没有下载地址、或体积缺失/过小的条目一律不入库。
        // 这类多半是占位、公告或坏数据，留着只会让用户点了下载却拿到空文件。
        if (!a.isDownloadable) { dropped++; continue; }

        NSString *key = a.packageName.length ? a.packageName
                      : (a.bundleIdentifier.length ? a.bundleIdentifier : a.name);
        if (key.length == 0) continue;
        NSMutableArray *arr = groups[key];
        if (!arr) {
            arr = [NSMutableArray array];
            groups[key] = arr;
            [order addObject:key];
        }
        [arr addObject:a];
    }

    NSMutableArray<RSAppItem *> *result = [NSMutableArray array];


    for (NSString *key in order) {
        NSMutableArray<RSAppItem *> *arr = groups[key];

        // ① 去重键 = 版本 + 架构。
        // 注意：arm64（无根）与 arm64e（隐根）是**两种不同的包**，
        // 必须分别保留，合并会让用户分不清该装哪个。
        // 只有内容完全相同（同版本同架构、通常是重复推送）才合并。
        NSMutableDictionary<NSString *, RSAppItem *> *byVer = [NSMutableDictionary dictionary];
        NSMutableArray<NSString *> *verOrder = [NSMutableArray array];
        for (RSAppItem *a in arr) {
            NSString *v = [NSString stringWithFormat:@"%@|%@",
                           a.version.length ? a.version : @"0",
                           [self normalizedArch:a.architecture]];
            RSAppItem *exist = byVer[v];
            if (!exist) {
                byVer[v] = a;
                [verOrder addObject:v];
                continue;
            }
            // 完全同版本同架构：保留体积更明确的那条
            if (a.size > exist.size) byVer[v] = a;
        }

        // ② 按版本号从新到旧排序（key 形如 "1.2.3|arm64e"，比较时只看版本部分）
        NSArray<NSString *> *sorted = [verOrder sortedArrayUsingComparator:
            ^NSComparisonResult(NSString *x, NSString *y) {
                NSString *vx = [x componentsSeparatedByString:@"|"].firstObject;
                NSString *vy = [y componentsSeparatedByString:@"|"].firstObject;
                NSComparisonResult r = [vy compare:vx options:NSNumericSearch];
                if (r != NSOrderedSame) return r;
                // 版本相同则固定顺序，避免界面每次刷新跳动
                return [x compare:y];
            }];

        NSMutableArray<RSAppItem *> *uniq = [NSMutableArray array];
        for (NSString *v in sorted) {
            RSAppItem *it = byVer[v];
            if (it) [uniq addObject:it];
        }
        if (uniq.count == 0) continue;

        // ③ 最新版作为列表主项，其余版本挂到 versions
        RSAppItem *primary = uniq.firstObject;
        primary.versions = (uniq.count > 1) ? [uniq copy] : nil;
        [result addObject:primary];
    }

    self.apps = [result copy];
    if (self.name.length == 0) {
        NSString *host = [[NSURL URLWithString:self.url] host];
        if (host.length) self.name = host;
    }
    if (self.subtitle.length == 0) {
        self.subtitle = [NSString stringWithFormat:@"越狱源 · %@", [self countSummaryText]];
    }
    if (dropped > 0) {
        NSLog(@"[RSRepo] %@ 丢弃 %ld 个无效条目（无下载地址或体积缺失/过小）",
              self.name ?: @"源", (long)dropped);
    }

    return (NSInteger)result.count;
}

#pragma mark - 统计

- (NSInteger)pluginCount {
    NSInteger c = 0;
    for (RSAppItem *a in self.apps) {
        if (a.isPlugin) c++;
    }
    return c;
}

- (NSInteger)appOnlyCount {
    return (NSInteger)self.apps.count - [self pluginCount];
}

- (NSString *)countSummaryText {
    NSInteger total = (NSInteger)self.apps.count;
    if (total == 0) return @"0 个";

    NSInteger plugins = [self pluginCount];
    NSInteger apps = total - plugins;

    // 有插件也有应用时分别列出，避免把所有条目笼统叫"应用"
    if (plugins > 0 && apps > 0) {
        return [NSString stringWithFormat:@"%ld 个插件 · %ld 个应用",
                (long)plugins, (long)apps];
    }
    if (plugins > 0) {
        return [NSString stringWithFormat:@"%ld 个插件", (long)plugins];
    }
    return [NSString stringWithFormat:@"%ld 个应用", (long)total];
}

@end
