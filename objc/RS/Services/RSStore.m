#import "RSStore.h"
#import "RSUnlockService.h"
#import "RSDeobfuscator.h"
#import "RSAptParser.h"
#import <UIKit/UIKit.h>
#import <zlib.h>

/// 伪装成 Sileo 的 User-Agent：越狱源常据此返回完整包列表
static NSString *RSRepoSileoUserAgent(void) {
    return @"Sileo/2.5 (iPhone; iOS 16.1.2; Scale/3.00)";
}

static NSString *const kSaveKey = @"repostore.repos.v2";
NSString *const RSDownloadsChangedNotification = @"RSDownloadsChanged";

@implementation RSDownloadRecord
@end

@interface RSStore ()
@property (nonatomic, strong) NSMutableArray<RSRepo *> *mutableRepos;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *progressMap;
/// task 标识 → 条目 id，供 delegate 回调定位进度
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSString *> *taskKeyMap;
/// 条目 id → 服务器声明的总字节数（用于进度分母和完成时校验）
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *expectedSizeMap;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSURL *> *finishedMap;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, void (^)(double)> *progressObservers;
// taskIdentifier → itemId，KVO 进度回调靠它把进度写回 progressMap
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSString *> *taskItemMap;
@property (nonatomic, strong) NSMutableArray<RSDownloadRecord *> *records;
@end

@implementation RSStore

+ (instancetype)shared {
    static RSStore *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[RSStore alloc] init]; });
    return s;
}

- (instancetype)init {
    if (self = [super init]) {
        _mutableRepos = [NSMutableArray array];
        _progressMap = [NSMutableDictionary dictionary];
        _taskKeyMap = [NSMutableDictionary dictionary];
        _expectedSizeMap = [NSMutableDictionary dictionary];
        _finishedMap = [NSMutableDictionary dictionary];
        _progressObservers = [NSMutableDictionary dictionary];
        _taskItemMap = [NSMutableDictionary dictionary];
        _records = [NSMutableArray array];

        NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
        cfg.timeoutIntervalForRequest = 30;
        cfg.timeoutIntervalForResource = 300;
        _session = [NSURLSession sessionWithConfiguration:cfg];

        [self load];
        [self loadRecords];
    }
    return self;
}

- (NSArray<RSRepo *> *)repos {
    return [self.mutableRepos copy];
}

#pragma mark - 持久化

- (void)load {
    NSData *data = [[NSUserDefaults standardUserDefaults] dataForKey:kSaveKey];
    if (!data) return;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![obj isKindOfClass:[NSArray class]]) return;
    for (id d in (NSArray *)obj) {
        RSRepo *r = [RSRepo fromDictionary:d];
        if (r) [self.mutableRepos addObject:r];
    }
}

- (void)save {
    NSMutableArray *arr = [NSMutableArray array];
    for (RSRepo *r in self.mutableRepos) {
        [arr addObject:[r toDictionary]];
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:arr options:0 error:nil];
    if (data) [[NSUserDefaults standardUserDefaults] setObject:data forKey:kSaveKey];
}

#pragma mark - 源管理

- (nullable RSRepo *)repoWithUID:(NSString *)uid {
    for (RSRepo *r in self.mutableRepos) {
        if ([r.uid isEqualToString:uid]) return r;
    }
    return nil;
}

- (nullable RSRepo *)addRepoWithURL:(NSString *)url {
    NSString *u = [url stringByTrimmingCharactersInSet:
                   [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (u.length == 0) { self.lastError = @"地址不能为空"; return nil; }
    if (![u.lowercaseString hasPrefix:@"http://"] &&
        ![u.lowercaseString hasPrefix:@"https://"]) {
        u = [@"https://" stringByAppendingString:u];
    }
    for (RSRepo *r in self.mutableRepos) {
        if ([r.url isEqualToString:u]) {
            self.lastError = @"该源已存在";
            return r;
        }
    }
    RSRepo *repo = [[RSRepo alloc] initWithURL:u];
    [self.mutableRepos addObject:repo];
    return repo;
}

- (void)addRepoWithURL:(NSString *)url autoRefresh:(BOOL)refresh {
    RSRepo *r = [self addRepoWithURL:url];
    if (!r) return;
    [self save];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RSReposChanged" object:nil];
    if (refresh) {
        [self refreshRepo:r completion:nil];
    }
}

- (void)removeRepo:(RSRepo *)repo {
    if (!repo) return;
    [self.mutableRepos removeObject:repo];
    [self save];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RSReposChanged" object:nil];
}

#pragma mark - 请求

- (NSMutableURLRequest *)requestForURL:(NSURL *)url repo:(RSRepo *)repo {
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    [req setValue:RSRepoSileoUserAgent() forHTTPHeaderField:@"User-Agent"];
    // 注意：**不要**手动设置 Accept-Encoding。
    // 一旦手动设了，NSURLSession 就不再自动解压响应体，
    // 而服务器（GitHub Pages 等）会因此返回 gzip 原始字节，
    // 后续当 UTF-8 文本解析就会整源中文乱码。
    // 交给系统自动协商与解压即可。
    [req setValue:@"text/html,application/json,*/*" forHTTPHeaderField:@"Accept"];
    if (repo.unlockToken.length) {
        [req setValue:repo.unlockToken forHTTPHeaderField:@"X-Unlock-Token"];
    }
    return req;
}

#pragma mark - 刷新

- (void)refreshRepo:(RSRepo *)repo
         completion:(void (^)(BOOL, NSString * _Nullable))completion {
    if (!repo) {
        if (completion) completion(NO, @"源不存在");
        return;
    }

    NSString *root = [self repoRootFor:repo];
    NSString *u = repo.url.length ? repo.url : root;

    // 依次尝试：用户填的地址 → Packages → Packages.bz2 → Release
    NSMutableArray<NSString *> *candidates = [NSMutableArray array];
    [candidates addObject:u];
    void (^addIfNew)(NSString *) = ^(NSString *c) {
        if (![candidates containsObject:c]) [candidates addObject:c];
    };
    addIfNew([root stringByAppendingString:@"Packages"]);
    addIfNew([root stringByAppendingString:@"Packages.gz"]);
    addIfNew([root stringByAppendingString:@"Packages.bz2"]);
    addIfNew([root stringByAppendingString:@"Release"]);

    __block NSString *lastError = nil;

    void (^tryOne)(NSInteger) = nil;
    __weak RSStore *weakSelf = self;

    void (^tryIndex)(NSInteger) = nil;
    tryIndex = ^(NSInteger idx) {
        RSStore *sself = weakSelf;
        if (!sself) return;
        if (idx >= (NSInteger)candidates.count) {
            dispatch_async(dispatch_get_main_queue(), ^{
                repo.lastError = lastError ?: @"无法识别的源";
                if (completion) completion(NO, repo.lastError);
            });
            return;
        }
        NSString *cur = candidates[idx];
        NSURL *curl = [NSURL URLWithString:cur];
        if (!curl) { tryIndex(idx + 1); return; }

        NSMutableURLRequest *req = [sself requestForURL:curl repo:repo];
        NSURLSessionDataTask *task = [sself.session dataTaskWithRequest:req
                                                    completionHandler:^(NSData *body,
                                                                        NSURLResponse *resp,
                                                                        NSError *err) {
            if (err || body.length == 0) {
                lastError = err.localizedDescription ?: @"网络请求失败";
                tryIndex(idx + 1);
                return;
            }

            // 解压 bzip2 / gzip 的 Packages（部分源只提供压缩版）
            NSData *plain = [sself decompressedIfNeeded:body url:curl];
            if (!plain || plain.length == 0) {
                lastError = @"无法解压源内容";
                tryIndex(idx + 1);
                return;
            }
            NSString *asText = [sself tolerantStringFromData:plain];

            // ① APT Packages 清单
            if ([RSAptParser looksLikePackages:asText]) {
                NSArray<RSAppItem *> *items =
                    [RSAptParser itemsFromPackagesText:asText
                                           repoBaseURL:[sself repoRootFor:repo]];
                dispatch_async(dispatch_get_main_queue(), ^{
                    // 清单里的条数可能很多，但真正能下载的才算数
                    NSInteger n = [repo applyAPTItems:items];
                    repo.lastUpdated = [NSDate date];
                    repo.lastError = nil;
                    [sself fillNameForRepo:repo];
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"RSReposChanged" object:nil];
                    [sself save];
                    // Packages 里不含源名，后台再取一次 Release 补上
                    [sself fetchReleaseNameForRepo:repo];
                    if (completion) completion(YES, n > 0 ? nil : @"源里没有可下载的插件");
                });
                return;
            }

            // ② Release 文件：只用来取源名，没有包列表
            if ([RSAptParser looksLikeRelease:asText]) {
                NSString *nm = [RSAptParser nameFromReleaseText:asText];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (nm.length) repo.name = nm;
                    repo.lastUpdated = [NSDate date];
                    repo.lastError = @"这是索引文件，缺少 Packages 列表";
                    [sself save];
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"RSReposChanged" object:nil];
                });
                lastError = @"这是索引文件，源需要提供 Packages 列表";
                tryIndex(idx + 1);
                return;
            }

            // ③ 网页首页：地址填错时的常见情况
            if ([RSAptParser looksLikeHTML:asText]) {
                lastError = @"该地址是网页而非源地址";
                tryIndex(idx + 1);
                return;
            }

            // ④ 普通 JSON 源
            NSDictionary *parsed = [sself parseSourceBody:body repo:repo];
            if (parsed) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSInteger n = [repo applyJSON:parsed];
                    repo.lastUpdated = [NSDate date];
                    repo.lastError = nil;
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"RSReposChanged" object:nil];
                    [sself save];
                    if (completion) completion(YES, n > 0 ? nil : @"源里没有应用");
                });
                return;
            }

            // ⑤ ESign / Base64 加密源
            NSArray<NSString *> *lines = asText.length ? [RSDeobfuscator decodeSource:asText] : nil;
            for (NSString *line in lines) {
                NSString *t = [line stringByTrimmingCharactersInSet:
                               [NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (t.length < 2) continue;
                NSData *d = [t dataUsingEncoding:NSUTF8StringEncoding];
                NSDictionary *p = [sself parseSourceBody:d repo:repo];
                if (p) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSInteger n = [repo applyJSON:p];
                        repo.lastUpdated = [NSDate date];
                        repo.lastError = nil;
                        [[NSNotificationCenter defaultCenter] postNotificationName:@"RSReposChanged" object:nil];
                        [sself save];
                        if (completion) completion(YES, n > 0 ? nil : @"源里没有应用");
                    });
                    return;
                }
            }

            lastError = @"不是有效的源（既不是 JSON 也不是 Packages 列表）";
            tryIndex(idx + 1);
        }];
        [task resume];
    };

    tryIndex(0);
}

/// 源根地址：去掉可能带的 Packages / Release 后缀，用于补全 Filename 的相对路径
- (NSString *)repoRootFor:(RSRepo *)repo {
    NSString *u = repo.url ?: @"";
    NSString *lower = u.lowercaseString;
    for (NSString *suffix in @[@"/Packages.bz2", @"/Packages.gz", @"/Packages.xz",
                               @"/Packages", @"/Release"]) {
        if ([lower hasSuffix:suffix.lowercaseString]) {
            u = [u substringToIndex:u.length - suffix.length];
            break;
        }
    }
    if (![u hasSuffix:@"/"]) u = [u stringByAppendingString:@"/"];
    return u;
}

/// 后台取 Release 文件，把源的真实名称补上。
/// Packages 清单里没有源名，名字只存在于 Release 的 Origin/Label 字段。
- (void)fetchReleaseNameForRepo:(RSRepo *)repo {
    NSString *root = [self repoRootFor:repo];
    NSURL *u = [NSURL URLWithString:[root stringByAppendingString:@"Release"]];
    if (!u) return;

    NSMutableURLRequest *req = [self requestForURL:u repo:repo];
    NSURLSessionDataTask *t = [self.session dataTaskWithRequest:req
                                             completionHandler:^(NSData *data,
                                                                 NSURLResponse *resp,
                                                                 NSError *err) {
        if (err || data.length == 0) return;
        NSString *text = [self tolerantStringFromData:data];
        if (![RSAptParser looksLikeRelease:text]) return;
        NSString *nm = [RSAptParser nameFromReleaseText:text];
        if (nm.length == 0) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            repo.name = nm;
            [self save];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"RSReposChanged"
                                                                object:nil];
        });
    }];
    [t resume];
}

/// 源还没名字时，用域名兜底，避免列表里显示"未命名源"
- (void)fillNameForRepo:(RSRepo *)repo {
    NSString *nm = [repo.name stringByTrimmingCharactersInSet:
                    [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (nm.length > 0 && ![nm isEqualToString:@"未命名源"]) return;
    NSString *host = [NSURL URLWithString:repo.url].host;
    if (host.length) repo.name = host;
}

/// 容错解码：源文件里常有零星非法字节（例如某个汉字被截断），
/// 而 initWithData:encoding:NSUTF8StringEncoding 遇到一个坏字节就整份返回 nil。
///
/// 关键点：不能因为几个坏字节就整份改用 GB18030/Latin-1 ——
/// 那会让整份文件的中文全部变成乱码。
/// 正确做法是保留 UTF-8，只把非法字节替换成 '?'，其余文字原样保留。
- (NSString *)tolerantStringFromData:(NSData *)data {
    if (data.length == 0) return @"";

    // ① 防御：万一拿到的是未解压的 gzip，先解压
    if (data.length >= 2) {
        const unsigned char *p0 = data.bytes;
        if (p0[0] == 0x1F && p0[1] == 0x8B) {
            NSData *un = [self gunzipData:data];
            if (un.length) data = un;
        }
    }

    // ② 纯 UTF-8（大多数源走这条）
    NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (s) return s;

    // ③ 少数非法字节 → 逐字节清洗，但**保持 UTF-8 语义**，不做整份换码
    NSMutableData *clean = [NSMutableData dataWithCapacity:data.length];
    const uint8_t *p = data.bytes;
    NSUInteger i = 0;
    while (i < data.length) {
        uint8_t b = p[i];
        if (b < 0x80) { [clean appendBytes:&b length:1]; i++; continue; }
        // 尝试按 UTF-8 多字节序列整体拷贝
        NSUInteger need = 0;
        if ((b & 0xE0) == 0xC0) need = 1;
        else if ((b & 0xF0) == 0xE0) need = 2;
        else if ((b & 0xF8) == 0xF0) need = 3;
        BOOL ok = (need > 0 && i + need < data.length);
        if (ok) {
            for (NSUInteger k = 1; k <= need; k++) {
                if ((p[i + k] & 0xC0) != 0x80) { ok = NO; break; }
            }
        }
        if (ok) {
            [clean appendBytes:&p[i] length:need + 1];
            i += need + 1;
        } else {
            uint8_t q = '?';
            [clean appendBytes:&q length:1];
            i++;
        }
    }
    return [[NSString alloc] initWithData:clean encoding:NSUTF8StringEncoding] ?: @"";
}

- (NSData *)decompressedIfNeeded:(NSData *)data url:(NSURL *)url {
    if (data.length < 3) return data;
    const unsigned char *b = data.bytes;
    // gzip: 1F 8B
    if (b[0] == 0x1F && b[1] == 0x8B) {
        NSData *out = [self gunzipData:data];
        if (out.length) return out;
        // 解压失败：返回 nil 让上层报「无法解压」，绝不把压缩字节当文本用
        return nil;
    }
    // bzip2: 'BZh'（用系统 bunzip 太重，这里显式报不支持，避免误当文本）
    if (b[0] == 'B' && b[1] == 'Z' && b[2] == 'h') {
        return nil;
    }
    return data;
}

/// 简单的 gzip 解压（走 zlib）
- (nullable NSData *)gunzipData:(NSData *)data {
    if (data.length == 0) return nil;
    z_stream zs;
    memset(&zs, 0, sizeof(zs));
    if (inflateInit2(&zs, 15 + 32) != Z_OK) return nil;   // 15+32: 自动识别 gzip/zlib

    zs.next_in = (Bytef *)data.bytes;
    zs.avail_in = (uInt)data.length;

    NSMutableData *out = [NSMutableData data];
    unsigned char buf[16384];
    int ret = Z_OK;
    while (ret != Z_STREAM_END) {
        zs.next_out = buf;
        zs.avail_out = sizeof(buf);
        ret = inflate(&zs, Z_NO_FLUSH);
        if (ret != Z_OK && ret != Z_STREAM_END) break;
        NSUInteger have = sizeof(buf) - zs.avail_out;
        if (have) [out appendBytes:buf length:have];
        if (ret == Z_OK && zs.avail_in == 0 && have == 0) break;
    }
    inflateEnd(&zs);
    return (ret == Z_STREAM_END) ? out : nil;
}

/// 把 body 解析成源字典；自动处理 UTF-8 BOM
- (nullable NSDictionary *)parseSourceBody:(NSData *)body repo:(RSRepo *)repo {
    if (!body || body.length == 0) return nil;
    NSData *b = body;
    if (b.length >= 3) {
        const unsigned char *p = b.bytes;
        if (p[0] == 0xEF && p[1] == 0xBB && p[2] == 0xBF) {
            b = [b subdataWithRange:NSMakeRange(3, b.length - 3)];
        }
    }
    id obj = [NSJSONSerialization JSONObjectWithData:b options:0 error:nil];
    if ([obj isKindOfClass:[NSDictionary class]]) return (NSDictionary *)obj;
    return nil;
}

- (void)refreshRepoByUID:(NSString *)uid
              completion:(void (^)(BOOL, NSString * _Nullable))completion {
    RSRepo *r = [self repoWithUID:uid];
    [self refreshRepo:r completion:completion];
}

- (void)refreshAll:(void (^)(void))completion {
    NSArray<RSRepo *> *snapshot = [self.mutableRepos copy];
    if (snapshot.count == 0) { if (completion) completion(); return; }
    __block NSInteger remain = snapshot.count;
    for (RSRepo *r in snapshot) {
        [self refreshRepo:r completion:^(BOOL ok, NSString *err) {
            remain--;
            if (remain <= 0 && completion) completion();
        }];
    }
}

#pragma mark - 解锁

- (void)unlockRepo:(RSRepo *)repo
              code:(NSString *)code
        completion:(void (^)(BOOL, NSString * _Nullable))completion {
    if (!repo) { if (completion) completion(NO, @"源不存在"); return; }
    [RSUnlockService verifyCode:code forRepo:repo completion:^(BOOL ok, NSString *token, NSString *msg) {
        if (ok) {
            repo.isUnlocked = YES;
            repo.unlockToken = token.length ? token : code;
            [self save];
            [self refreshRepo:repo completion:^(BOOL r, NSString *e) {
                if (completion) completion(YES, nil);
            }];
        } else {
            if (completion) completion(NO, msg ?: @"解锁码无效");
        }
    }];
}

- (void)lockRepo:(RSRepo *)repo {
    if (!repo) return;
    repo.isUnlocked = NO;
    repo.unlockToken = nil;
    [self save];
}

#pragma mark - 下载

/// 下载目录：Documents/Downloads（不会被系统自动清理）
- (NSString *)downloadsDir {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *d = [[fm URLsForDirectory:NSDocumentDirectory
                           inDomains:NSUserDomainMask] firstObject];
    NSURL *dir = [d URLByAppendingPathComponent:@"Downloads" isDirectory:YES];
    [fm createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir.path;
}

/// 兼容旧版缓存目录
- (NSString *)cacheDir {
    return [self downloadsDir];
}

- (NSURL *)recordsFileURL {
    NSURL *dir = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                        inDomains:NSUserDomainMask].firstObject;
    [[NSFileManager defaultManager] createDirectoryAtURL:dir
                             withIntermediateDirectories:YES attributes:nil error:nil];
    return [dir URLByAppendingPathComponent:@"downloads.json"];
}

- (void)loadRecords {
    NSData *data = [NSData dataWithContentsOfURL:[self recordsFileURL]];
    if (!data) return;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![obj isKindOfClass:[NSArray class]]) return;
    self.records = [NSMutableArray array];
    for (id d in (NSArray *)obj) {
        if (![d isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *x = (NSDictionary *)d;
        RSDownloadRecord *r = [RSDownloadRecord new];
        r.itemId    = x[@"itemId"] ?: @"";
        r.name      = x[@"name"] ?: @"";
        r.version   = x[@"version"] ?: @"";
        r.sizeText  = x[@"sizeText"] ?: @"";
        r.iconURL   = x[@"iconURL"] ?: @"";
        r.fileName  = x[@"fileName"] ?: @"";
        r.filePath  = x[@"filePath"] ?: @"";
        r.finished  = [x[@"finished"] boolValue];
        if (x[@"finishedAt"]) {
            r.finishedAt = [NSDate dateWithTimeIntervalSince1970:[x[@"finishedAt"] doubleValue]];
        }
        // 文件已不存在则标记为未完成（避免展示死链）
        if (r.finished && r.filePath.length &&
            ![[NSFileManager defaultManager] fileExistsAtPath:r.filePath]) {
            r.finished = NO;
        }
        if (r.itemId.length) [self.records addObject:r];
    }
}

- (void)saveRecords {
    NSMutableArray *arr = [NSMutableArray array];
    for (RSDownloadRecord *r in self.records) {
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        d[@"itemId"]   = r.itemId ?: @"";
        d[@"name"]     = r.name ?: @"";
        d[@"version"]  = r.version ?: @"";
        d[@"sizeText"] = r.sizeText ?: @"";
        d[@"iconURL"]  = r.iconURL ?: @"";
        d[@"fileName"] = r.fileName ?: @"";
        d[@"filePath"] = r.filePath ?: @"";
        d[@"finished"] = @(r.finished);
        if (r.finishedAt) d[@"finishedAt"] = @(r.finishedAt.timeIntervalSince1970);
        [arr addObject:d];
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:arr options:0 error:nil];
    if (data) [data writeToURL:[self recordsFileURL] atomically:YES];
}

- (nullable RSDownloadRecord *)recordForItemId:(NSString *)itemId {
    for (RSDownloadRecord *r in self.records) {
        if ([r.itemId isEqualToString:itemId]) return r;
    }
    return nil;
}

- (NSArray<RSDownloadRecord *> *)downloadRecords {
    return [self.records copy];
}

- (BOOL)isDownloadingItemId:(NSString *)itemId {
    if (itemId.length == 0) return NO;
    NSNumber *p = self.progressMap[itemId];
    return p && p.doubleValue > 0.0 && p.doubleValue < 1.0;
}

- (double)currentProgressForItemId:(NSString *)itemId {
    NSNumber *p = self.progressMap[itemId];
    return p ? p.doubleValue : 0.0;
}

- (double)progressForItem:(RSAppItem *)item {
    if (!item) return 0;
    return [self currentProgressForItemId:item.itemId];
}

- (nullable NSURL *)finishedURLForItem:(RSAppItem *)item {
    NSURL *u = [self.finishedMap objectForKey:item.itemId];
    if (u) return u;
    // 兼容旧版本记录：早期 itemId 不含架构后缀（"包名@版本"）。
    // 只在该条目唯一的格式匹配时回退，避免 arm64/arm64e 互相串用。
    NSString *legacy = [NSString stringWithFormat:@"%@@%@",
                        item.bundleIdentifier, item.version];
    if ([legacy isEqualToString:item.itemId]) return nil;

    // 若这个旧键对应多条（多种架构），放弃回退
    NSInteger sameLegacy = 0;
    for (RSAppItem *a in item.versions ?: @[]) {
        NSString *k = [NSString stringWithFormat:@"%@@%@", a.bundleIdentifier, a.version];
        if ([k isEqualToString:legacy]) sameLegacy++;
    }
    if (sameLegacy > 1) return nil;
    return [self.finishedMap objectForKey:legacy];
}

- (void)downloadItem:(RSAppItem *)item {
    [self downloadItem:item progress:nil completion:nil];
}

/// 真正执行下载：先建记录、再起任务，进度写回 progressMap
- (void)downloadItem:(RSAppItem *)item
            progress:(void (^)(double))progress
          completion:(void (^)(NSURL * _Nullable, NSString * _Nullable))completion {
    if (!item || item.downloadURL.length == 0) {
        if (completion) completion(nil, @"没有下载地址");
        return;
    }
    NSURL *url = [NSURL URLWithString:item.downloadURL];
    if (!url) {
        if (completion) completion(nil, @"下载地址无效");
        return;
    }

    // 已下载过且文件还在，直接返回
    NSURL *done = [self finishedURLForItem:item];
    if (done) {
        if (completion) completion(done, nil);
        return;
    }

    NSString *itemId = item.itemId;
    self.progressMap[itemId] = @(0.0);

    // 建立/更新下载记录
    RSDownloadRecord *rec = [self recordForItemId:itemId];
    if (!rec) {
        rec = [RSDownloadRecord new];
        rec.itemId = itemId;
        [self.records insertObject:rec atIndex:0];
    }
    rec.name = item.name ?: @"";
    rec.version = item.version ?: @"";
    rec.sizeText = item.sizeText ?: @"";
    rec.iconURL = item.iconURL ?: @"";
    rec.finished = NO;
    rec.finishedAt = nil;

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    [req setValue:RSRepoSileoUserAgent() forHTTPHeaderField:@"User-Agent"];

    __weak RSStore *weakSelf = self;
    NSURLSessionDownloadTask *task =
        [self.session downloadTaskWithRequest:req
                            completionHandler:^(NSURL *location, NSURLResponse *resp, NSError *err) {
        RSStore *sself = weakSelf;
        if (!sself) return;

        if (err || !location) {
            NSInteger code = [(NSHTTPURLResponse *)resp statusCode];
            NSString *m = err.localizedDescription ?: @"下载失败";
            if (code == 403) m = @"没有下载权限，可能需要购买或解锁";
            else if (code == 404) m = @"文件不存在（404）";
            else if (code > 0) m = [NSString stringWithFormat:@"服务器返回 %ld", (long)code];

            [sself.progressMap removeObjectForKey:itemId];
            RSDownloadRecord *r = [sself recordForItemId:itemId];
            if (r) { [sself.records removeObject:r]; }
            [sself saveRecords];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:RSDownloadsChangedNotification object:nil];
                if (completion) completion(nil, m);
            });
            return;
        }

        // 落盘到 Downloads 目录
        NSString *dir = [sself downloadsDir];
        NSString *name = url.lastPathComponent.length ? url.lastPathComponent : @"download";
        // 防御：文件名里可能带解码后仍非法的字符
        name = [name stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
        NSString *dest = [dir stringByAppendingPathComponent:name];

        NSFileManager *fm = [NSFileManager defaultManager];
        if ([fm fileExistsAtPath:dest]) [fm removeItemAtPath:dest error:nil];
        NSError *moveErr = nil;
        [fm moveItemAtURL:location toURL:[NSURL fileURLWithPath:dest] error:&moveErr];

        if (moveErr) {
            [sself.progressMap removeObjectForKey:itemId];
            if (completion) completion(nil, moveErr.localizedDescription ?: @"保存文件失败");
            return;
        }

        sself.finishedMap[itemId] = [NSURL fileURLWithPath:dest];
        sself.progressMap[itemId] = @(1.0);

        RSDownloadRecord *r = [sself recordForItemId:itemId];
        if (!r) {
            r = [RSDownloadRecord new];
            r.itemId = itemId;
            [sself.records insertObject:r atIndex:0];
        }
        r.fileName = name;
        r.filePath = dest;
        r.finished = YES;
        r.finishedAt = [NSDate date];
        r.sizeText = item.sizeText ?: r.sizeText;
        [sself saveRecords];

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:RSDownloadsChangedNotification object:nil];
            if (completion) completion([NSURL fileURLWithPath:dest], nil);
        });
    }];

    [self.progressObservers setObject:[^(double p){
        if (progress) progress(p);
    } copy] forKey:@(task.taskIdentifier)];
    // 简单轮询进度：较真实且不依赖 delegate
    __block NSUInteger pollId = 0;
    __weak NSURLSessionDownloadTask *weakTask = task;
    void (^poll)(void) = nil;
    __block void (^blockPoll)(void) = nil;
    blockPoll = ^{
        NSURLSessionDownloadTask *t = weakTask;
        if (!t) return;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            NSURLSessionDownloadTask *tt = weakTask;
            if (!tt || tt.state == NSURLSessionTaskStateCompleted) return;
            double total = (double)tt.countOfBytesExpectedToReceive;
            double recv = (double)tt.countOfBytesReceived;
            if (total > 0) {
                double p = recv / total;
                if (p < 0) p = 0; if (p > 1) p = 1;
                sself.progressMap[itemId] = @(p);
                if (progress) progress(p);
            }
            blockPoll();
        });
    };
    blockPoll();
    (void)pollId; (void)poll;

    [task resume];
    [self saveRecords];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:RSDownloadsChangedNotification object:nil];
    });
}

- (void)removeDownloadRecord:(RSDownloadRecord *)record {
    if (!record) return;
    if (record.filePath.length) {
        [[NSFileManager defaultManager] removeItemAtPath:record.filePath error:nil];
    }
    [self.finishedMap removeObjectForKey:record.itemId];
    [self.progressMap removeObjectForKey:record.itemId];
    [self.records removeObject:record];
    [self saveRecords];
    [[NSNotificationCenter defaultCenter] postNotificationName:RSDownloadsChangedNotification object:nil];
}

- (void)cancelDownloadForItemId:(NSString *)itemId {
    if (itemId.length == 0) return;
    [self.progressMap removeObjectForKey:itemId];
    RSDownloadRecord *r = [self recordForItemId:itemId];
    if (r) {
        if (r.filePath.length) [[NSFileManager defaultManager] removeItemAtPath:r.filePath error:nil];
        [self.records removeObject:r];
    }
    [self saveRecords];
    [[NSNotificationCenter defaultCenter] postNotificationName:RSDownloadsChangedNotification object:nil];
}

- (void)pauseDownloadForItemId:(NSString *)itemId {
    // 简化实现：暂停即取消（不保留断点续传状态）
    [self cancelDownloadForItemId:itemId];
}

- (void)resumeDownloadForItemId:(NSString *)itemId {
    // 简化实现：续传即重新下载
}

- (BOOL)isPausedItemId:(NSString *)itemId {
    return NO;
}

@end
