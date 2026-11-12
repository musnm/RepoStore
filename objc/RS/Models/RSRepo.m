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

- (void)applyJSON:(NSDictionary *)json {
    if (![json isKindOfClass:[NSDictionary class]]) return;

    NSString *n = RSStr2(json[@"name"]);
    if (n.length) self.name = n;
    if (self.name.length == 0) {
        NSURL *u = [NSURL URLWithString:self.url];
        self.name = u.host ?: @"未命名源";
    }

    NSString *ident = RSStr2(json[@"identifier"]);
    if (ident.length) self.identifier = ident;

    NSString *sub = RSStr2(json[@"subtitle"]) ?: RSStr2(json[@"description"]);
    if (sub.length) self.subtitle = sub;

    NSString *ico = RSStr2(json[@"iconURL"]) ?: RSStr2(json[@"icon"]);
    if (ico.length) self.iconURL = ico;

    id ru = json[@"requiresUnlock"] ?: json[@"locked"];
    if ([ru isKindOfClass:[NSNumber class]]) self.requiresUnlock = [ru boolValue];

    NSString *uu = RSStr2(json[@"unlockURL"]);
    if (uu.length) self.unlockURL = uu;

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
}

- (NSDictionary *)toDictionary {
    NSMutableArray *arr = [NSMutableArray array];
    for (RSAppItem *a in self.apps) {
        [arr addObject:@{
            @"name": a.name ?: @"",
            @"bundleIdentifier": a.bundleIdentifier ?: @"",
            @"version": a.version ?: @"",
            @"size": @(a.size),
            @"iconURL": a.iconURL ?: @"",
            @"downloadURL": a.downloadURL ?: @"",
            @"description": a.desc ?: @"",
            @"developer": a.developer ?: @"",
            @"category": a.category ?: @"",
        }];
    }
    return @{
        @"uid": self.uid ?: @"",
        @"url": self.url ?: @"",
        @"name": self.name ?: @"",
        @"identifier": self.identifier ?: @"",
        @"subtitle": self.subtitle ?: @"",
        @"iconURL": self.iconURL ?: @"",
        @"requiresUnlock": @(self.requiresUnlock),
        @"unlockURL": self.unlockURL ?: @"",
        @"isUnlocked": @(self.isUnlocked),
        @"unlockToken": self.unlockToken ?: @"",
        @"apps": arr,
    };
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
