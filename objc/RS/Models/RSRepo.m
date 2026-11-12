#import "RSRepo.h"

@implementation RSRepo

- (instancetype)initWithURL:(NSString *)url {
    if (self = [super init]) {
        _uid = [[NSUUID UUID] UUIDString];
        _url = [url copy];
        _name = @"";
        _identifier = @"";
        _subtitle = @"";
        _apps = [NSMutableArray array];
        _requiresUnlock = NO;
        _isUnlocked = NO;
    }
    return self;
}

static NSString *RSStr2(id v) {
    if ([v isKindOfClass:[NSString class]]) return v;
    if ([v isKindOfClass:[NSNumber class]]) return [v stringValue];
    return nil;
}

- (NSInteger)applyJSON:(NSDictionary *)json {
    if (![json isKindOfClass:[NSDictionary class]]) return 0;

    NSString *n = RSStr2(json[@"name"]);
    if (n.length) self.name = n;
    if (self.name.length == 0) {
        NSURL *u = [NSURL URLWithString:self.url];
        self.name = u.host ?: @"未命名源";
    }

    NSString *ident = RSStr2(json[@"identifier"]);
    if (ident.length) self.identifier = ident;

    NSString *sub = RSStr2(json[@"subtitle"])
                 ?: RSStr2(json[@"description"])
                 ?: RSStr2(json[@"desc"]);
    if (sub.length) self.subtitle = sub;

    NSString *ico = RSStr2(json[@"iconURL"]) ?: RSStr2(json[@"icon"]);
    if (ico.length) self.iconURL = ico;

    // 真实字段 sourceURL
    NSString *src = RSStr2(json[@"sourceURL"]);
    if (src.length) self.sourceURL = src;

    NSString *tc = RSStr2(json[@"tintColor"]);
    if (tc.length) self.tintColor = tc;

    // 解锁相关：requiresUnlock / locked
    id ru = json[@"requiresUnlock"] ?: json[@"locked"];
    if ([ru isKindOfClass:[NSNumber class]]) self.requiresUnlock = [ru boolValue];
    if ([ru isKindOfClass:[NSString class]]) self.requiresUnlock = [(NSString *)ru boolValue];

    NSString *uu = RSStr2(json[@"unlockURL"]);
    if (uu.length) self.unlockURL = uu;

    // 应用列表：apps / packages / items
    NSArray *rawApps = nil;
    for (NSString *k in @[@"apps", @"packages", @"items"]) {
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
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"uid"] = self.uid ?: @"";
    d[@"url"] = self.url ?: @"";
    d[@"name"] = self.name ?: @"";
    d[@"identifier"] = self.identifier ?: @"";
    d[@"subtitle"] = self.subtitle ?: @"";
    if (self.sourceURL) d[@"sourceURL"] = self.sourceURL;
    if (self.iconURL) d[@"iconURL"] = self.iconURL;
    if (self.tintColor) d[@"tintColor"] = self.tintColor;
    d[@"requiresUnlock"] = @(self.requiresUnlock);
    if (self.unlockURL) d[@"unlockURL"] = self.unlockURL;
    d[@"isUnlocked"] = @(self.isUnlocked);
    if (self.unlockToken) d[@"unlockToken"] = self.unlockToken;
    d[@"apps"] = arr;
    return d;
}

+ (instancetype)fromDictionary:(NSDictionary *)d {
    if (![d isKindOfClass:[NSDictionary class]]) return nil;
    NSString *url = RSStr2(d[@"url"]);
    if (url.length == 0) return nil;

    RSRepo *r = [[RSRepo alloc] initWithURL:url];
    NSString *uid = RSStr2(d[@"uid"]);
    if (uid.length) r.uid = uid;
    r.name = RSStr2(d[@"name"]) ?: @"";
    r.identifier = RSStr2(d[@"identifier"]) ?: @"";
    r.subtitle = RSStr2(d[@"subtitle"]) ?: @"";
    r.iconURL = RSStr2(d[@"iconURL"]);
    r.sourceURL = RSStr2(d[@"sourceURL"]);
    r.tintColor = RSStr2(d[@"tintColor"]);
    r.unlockURL = RSStr2(d[@"unlockURL"]);
    r.unlockToken = RSStr2(d[@"unlockToken"]);

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

@end
