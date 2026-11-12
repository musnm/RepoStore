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
    return [NSString stringWithFormat:@"%@@%@", self.bundleIdentifier, self.version];
}

- (NSString *)sizeText {
    if (self.size <= 0) return @"";
    NSByteCountFormatter *f = [[NSByteCountFormatter alloc] init];
    f.countStyle = NSByteCountFormatterCountStyleFile;
    return [f stringFromByteCount:self.size];
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

    return it;
}

- (NSDictionary *)toDictionary {
    return @{
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
    };
}

@end
