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

@end
