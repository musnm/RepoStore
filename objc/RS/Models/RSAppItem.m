#import "RSAppItem.h"

@implementation RSAppItem

- (instancetype)init {
    if (self = [super init]) {
        _name = @"";
        _bundleIdentifier = @"";
        _version = @"";
        _downloadURL = @"";
        _desc = @"";
        _developer = @"";
        _category = @"";
        _size = 0;
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

static NSString *RSStr(id v) {
    if ([v isKindOfClass:[NSString class]]) return v;
    if ([v isKindOfClass:[NSNumber class]]) return [v stringValue];
    return nil;
}

+ (instancetype)itemFromDictionary:(NSDictionary *)d {
    if (![d isKindOfClass:[NSDictionary class]]) return nil;

    NSString *name = RSStr(d[@"name"]);
    if (name.length == 0) return nil;

    NSString *dl = RSStr(d[@"downloadURL"]) ?: RSStr(d[@"url"]);
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
    it.desc = RSStr(d[@"description"]) ?: RSStr(d[@"desc"]) ?: @"";
    it.developer = RSStr(d[@"developer"]) ?: RSStr(d[@"author"]) ?: @"";
    it.category = RSStr(d[@"category"]) ?: @"";

    id sz = d[@"size"];
    if ([sz isKindOfClass:[NSNumber class]]) {
        it.size = [sz longLongValue];
    } else if ([sz isKindOfClass:[NSString class]]) {
        it.size = [(NSString *)sz longLongValue];
    }
    return it;
}

@end
