#import "RSStore.h"
#import "RSUnlockService.h"
#import "RSDeobfuscator.h"
#import <UIKit/UIKit.h>

static NSString *const kSaveKey = @"repostore.repos.v2";

@interface RSStore ()
@property (nonatomic, strong) NSMutableArray<RSRepo *> *mutableRepos;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *progressMap;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSURL *> *finishedMap;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, void (^)(double)> *progressObservers;
- (NSString *)cacheDir;
@end

@implementation RSStore

+ (instancetype)shared {
    static RSStore *inst = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [[RSStore alloc] init]; });
    return inst;
}

- (instancetype)init {
    if (self = [super init]) {
        _mutableRepos = [NSMutableArray array];
        _progressMap = [NSMutableDictionary dictionary];
        _finishedMap = [NSMutableDictionary dictionary];
        _progressObservers = [NSMutableDictionary dictionary];
        NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
        cfg.timeoutIntervalForRequest = 25;
        cfg.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        _session = [NSURLSession sessionWithConfiguration:cfg];
        [self load];
    }
    return self;
}

- (NSArray<RSRepo *> *)repos {
    return [self.mutableRepos copy];
}

#pragma mark - 持久化

- (NSURL *)storeFileURL {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *dir = [[fm URLsForDirectory:NSApplicationSupportDirectory
                             inDomains:NSUserDomainMask] firstObject];
    [fm createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return [dir URLByAppendingPathComponent:@"repos.json"];
}

- (void)load {
    NSData *data = [NSData dataWithContentsOfURL:[self storeFileURL]];
    if (!data) {
        data = [[NSUserDefaults standardUserDefaults] objectForKey:kSaveKey];
    }
    if (!data) return;

    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![obj isKindOfClass:[NSArray class]]) return;

    [self.mutableRepos removeAllObjects];
    for (id d in (NSArray *)obj) {
        if (![d isKindOfClass:[NSDictionary class]]) continue;
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
    if (!data) return;
    [data writeToURL:[self storeFileURL] atomically:YES];
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:kSaveKey];
}

#pragma mark - 源管理

- (RSRepo *)addRepoWithURL:(NSString *)url {
    NSString *u = [url stringByTrimmingCharactersInSet:
                   [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (u.length == 0) return nil;
    if (![u.lowercaseString hasPrefix:@"http"]) {
        u = [@"https://" stringByAppendingString:u];
    }
    for (RSRepo *r in self.mutableRepos) {
        if ([r.url isEqualToString:u]) {
            return r;
        }
    }
    RSRepo *repo = [[RSRepo alloc] initWithURL:u];
    [self.mutableRepos addObject:repo];
    [self save];
    return repo;
}

- (void)addRepoWithURL:(NSString *)url autoRefresh:(BOOL)refresh {
    RSRepo *repo = [self addRepoWithURL:url];
    if (!repo) return;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RSReposChanged" object:nil];
    if (refresh) {
        [self refreshRepo:repo completion:^(BOOL ok, NSString *err) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"RSReposChanged" object:nil];
        }];
    }
}

- (void)removeRepo:(RSRepo *)repo {
    if (!repo) return;
    [self.mutableRepos removeObject:repo];
    [self save];
}

- (RSRepo *)repoWithUID:(NSString *)uid {
    for (RSRepo *r in self.mutableRepos) {
        if ([r.uid isEqualToString:uid]) return r;
    }
    return nil;
}

#pragma mark - 刷新

- (void)refreshRepo:(RSRepo *)repo completion:(void (^)(BOOL ok, NSString * _Nullable err))completion {
    if (!repo) { if (completion) completion(NO, @"源不存在"); return; }

    NSURL *u = [NSURL URLWithString:repo.url];
    if (!u) { if (completion) completion(NO, @"源地址无效"); return; }

    // 内联/本地源：直接读文件
    if (u.isFileURL) {
        NSData *body = [NSData dataWithContentsOfURL:u];
        NSDictionary *parsed = [self parseSourceBody:body repo:repo];
        if (!parsed) {
            repo.lastError = @"本地源解析失败";
            if (completion) completion(NO, repo.lastError);
            return;
        }
        NSInteger n = [repo applyJSON:parsed];
        repo.lastUpdated = [NSDate date];
        repo.lastError = nil;
        [self save];
        if (completion) completion(YES, n > 0 ? nil : @"源里没有应用");
        return;
    }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:u];
    [req setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 16_1_2 like Mac OS X) AppleWebKit/605.1.15 RepoStore/1.0"
        forHTTPHeaderField:@"User-Agent"];
    [req setValue:@"application/json, text/plain, */*" forHTTPHeaderField:@"Accept"];
    if (repo.unlockToken.length) {
        [req setValue:repo.unlockToken forHTTPHeaderField:@"X-Unlock-Token"];
        [req setValue:repo.unlockToken forHTTPHeaderField:@"Authorization"];
    }

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:req
                                                completionHandler:^(NSData *data,
                                                                    NSURLResponse *resp,
                                                                    NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (err) {
                repo.lastError = err.localizedDescription;
                if (completion) completion(NO, err.localizedDescription);
                return;
            }
            NSHTTPURLResponse *http = (NSHTTPURLResponse *)resp;
            if ([http isKindOfClass:[NSHTTPURLResponse class]]) {
                if (http.statusCode == 401 || http.statusCode == 403) {
                    repo.requiresUnlock = YES;
                    repo.isUnlocked = NO;
                    [self save];
                    if (completion) completion(NO, @"该源需要解锁码");
                    return;
                }
                if (http.statusCode < 200 || http.statusCode >= 300) {
                    NSString *m = [NSString stringWithFormat:@"服务器返回 %ld",
                                   (long)http.statusCode];
                    repo.lastError = m;
                    if (completion) completion(NO, m);
                    return;
                }
            }

            NSData *body = data ?: [NSData data];

            // ① 先按普通 JSON 解析
            NSDictionary *parsed = [self parseSourceBody:body repo:repo];

            // ② 失败则尝试解 ESign/Base64 加密源
            if (!parsed) {
                NSString *text = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
                NSArray<NSString *> *lines = text.length ? [RSDeobfuscator decodeSource:text] : nil;
                for (NSString *line in lines) {
                    NSString *t = [line stringByTrimmingCharactersInSet:
                                   [NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    if (t.length < 2) continue;
                    NSData *d = [t dataUsingEncoding:NSUTF8StringEncoding];
                    NSDictionary *p = [self parseSourceBody:d repo:repo];
                    if (p) { parsed = p; break; }
                }
            }

            if (!parsed) {
                NSString *preview = [[NSString alloc] initWithData:
                                     [body subdataWithRange:NSMakeRange(0, MIN((NSUInteger)80, body.length))]
                                                          encoding:NSUTF8StringEncoding];
                NSString *m = preview.length
                    ? @"不是有效的 JSON 源（可能是不支持的加密格式）"
                    : @"内容为空或格式不支持";
                repo.lastError = m;
                if (completion) completion(NO, m);
                return;
            }

            NSInteger n = [repo applyJSON:parsed];
            repo.lastUpdated = [NSDate date];
            repo.lastError = nil;
            [self save];
            if (completion) completion(YES, n > 0 ? nil : @"源里没有应用");
        });
    }];
    [task resume];
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

- (NSString *)cacheDir {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *c = [[fm URLsForDirectory:NSCachesDirectory
                           inDomains:NSUserDomainMask] firstObject];
    NSURL *dir = [c URLByAppendingPathComponent:@"Downloads" isDirectory:YES];
    [fm createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir.path;
}

/// 反查某个条目属于哪个源（用于带上该源的解锁令牌）
- (nullable RSRepo *)repoContainingItem:(RSAppItem *)item {
    if (!item) return nil;
    NSString *iid = item.itemId;
    for (RSRepo *r in self.mutableRepos) {
        for (RSAppItem *a in r.apps) {
            if ([a.itemId isEqualToString:iid]) return r;
            // 兜底：同下载地址
            if (a.downloadURL.length && [a.downloadURL isEqualToString:item.downloadURL]) return r;
        }
    }
    return nil;
}

- (void)downloadItem:(RSAppItem *)item {
    if (!item) return;
    NSString *key = item.itemId;

    NSURL *u = [NSURL URLWithString:item.downloadURL];
    if (!u) {
        self.lastError = @"下载地址无效";
        return;
    }

    [self.progressMap setObject:@(0) forKey:key];
    self.lastError = nil;

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:u];
    [req setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 16_1_2 like Mac OS X) AppleWebKit/605.1.15"
        forHTTPHeaderField:@"User-Agent"];

    // 解锁令牌：与刷新源保持一致，让源服务器自行决定是否放行
    RSRepo *owner = [self repoContainingItem:item];
    if (owner.unlockToken.length) {
        [req setValue:owner.unlockToken forHTTPHeaderField:@"X-Unlock-Token"];
        [req setValue:owner.unlockToken forHTTPHeaderField:@"Authorization"];
    }

    NSURLSessionDownloadTask *task =
    [self.session downloadTaskWithRequest:req
                        completionHandler:^(NSURL *location, NSURLResponse *resp, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (err || !location) {
                [self.progressMap removeObjectForKey:key];
                self.lastError = err.localizedDescription ?: @"下载失败";
                [[NSNotificationCenter defaultCenter] postNotificationName:@"RSDownloadFailed"
                                                                    object:key];
                return;
            }
            NSString *name = item.name.length ? item.name : @"app";
            name = [name stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
            NSString *fn = [NSString stringWithFormat:@"%@_%@.ipa", name,
                            item.version.length ? item.version : @"1.0"];
            NSString *dest = [[self cacheDir] stringByAppendingPathComponent:fn];
            NSURL *destURL = [NSURL fileURLWithPath:dest];
            [[NSFileManager defaultManager] removeItemAtURL:destURL error:nil];
            NSError *mvErr = nil;
            [[NSFileManager defaultManager] moveItemAtURL:location toURL:destURL error:&mvErr];
            if (mvErr) {
                [self.progressMap removeObjectForKey:key];
                self.lastError = mvErr.localizedDescription;
                [[NSNotificationCenter defaultCenter] postNotificationName:@"RSDownloadFailed"
                                                                    object:key];
                return;
            }
            [self.progressMap removeObjectForKey:key];
            [self.finishedMap setObject:destURL forKey:key];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"RSDownloadFinished"
                                                                object:key];
        });
    }];
    [task resume];
}

- (void)downloadItem:(RSAppItem *)item
            progress:(void (^)(double))progress
          completion:(void (^)(NSURL *, NSString *))completion {
    if (!item) {
        if (completion) completion(nil, @"条目无效");
        return;
    }
    NSString *key = item.itemId;
    NSURL *u = [NSURL URLWithString:item.downloadURL];
    if (!u) {
        if (completion) completion(nil, @"下载地址无效");
        return;
    }

    [self.progressMap setObject:@(0) forKey:key];
    self.lastError = nil;

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:u];
    [req setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 16_1_2 like Mac OS X) AppleWebKit/605.1.15"
        forHTTPHeaderField:@"User-Agent"];

    // 解锁令牌：与刷新源保持一致，让源服务器自行决定是否放行
    RSRepo *owner = [self repoContainingItem:item];
    if (owner.unlockToken.length) {
        [req setValue:owner.unlockToken forHTTPHeaderField:@"X-Unlock-Token"];
        [req setValue:owner.unlockToken forHTTPHeaderField:@"Authorization"];
    }

    NSURLSessionDownloadTask *task =
    [self.session downloadTaskWithRequest:req
                        completionHandler:^(NSURL *location, NSURLResponse *resp, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (err || !location) {
                [self.progressMap removeObjectForKey:key];
                NSString *m = err.localizedDescription ?: @"下载失败";
                self.lastError = m;
                [[NSNotificationCenter defaultCenter] postNotificationName:@"RSDownloadFailed"
                                                                    object:key];
                if (completion) completion(nil, m);
                return;
            }
            NSString *name = item.name.length ? item.name : @"app";
            name = [name stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
            NSString *fn = [NSString stringWithFormat:@"%@_%@.ipa", name,
                            item.version.length ? item.version : @"1.0"];
            NSString *dest = [[self cacheDir] stringByAppendingPathComponent:fn];
            NSURL *destURL = [NSURL fileURLWithPath:dest];
            [[NSFileManager defaultManager] removeItemAtURL:destURL error:nil];
            NSError *mvErr = nil;
            [[NSFileManager defaultManager] moveItemAtURL:location toURL:destURL error:&mvErr];
            if (mvErr) {
                [self.progressMap removeObjectForKey:key];
                self.lastError = mvErr.localizedDescription;
                [[NSNotificationCenter defaultCenter] postNotificationName:@"RSDownloadFailed"
                                                                    object:key];
                if (completion) completion(nil, mvErr.localizedDescription);
                return;
            }
            [self.progressMap removeObjectForKey:key];
            [self.finishedMap setObject:destURL forKey:key];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"RSDownloadFinished"
                                                                object:key];
            if (completion) completion(destURL, nil);
        });
    }];

    // 进度：用 KVO 观察 task 的 countOfBytesReceived
    if (progress) {
        [task addObserver:self forKeyPath:@"countOfBytesReceived"
                  options:NSKeyValueObservingOptionNew context:nil];
        [self.progressObservers setObject:progress forKey:@(task.taskIdentifier)];
    }

    [task resume];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if (![object isKindOfClass:[NSURLSessionTask class]]) return;
    NSURLSessionTask *t = (NSURLSessionTask *)object;
    void (^cb)(double) = [self.progressObservers objectForKey:@(t.taskIdentifier)];
    if (!cb) return;
    double total = (double)t.countOfBytesExpectedToReceive;
    double got = (double)t.countOfBytesReceived;
    if (total > 0) {
        double p = got / total;
        if (p < 0) p = 0;
        if (p > 1) p = 1;
        dispatch_async(dispatch_get_main_queue(), ^{ cb(p); });
    }
    if (t.state == NSURLSessionTaskStateCompleted) {
        @try { [t removeObserver:self forKeyPath:@"countOfBytesReceived"]; } @catch (id e) {}
        [self.progressObservers removeObjectForKey:@(t.taskIdentifier)];
    }
}

- (double)progressForItem:(RSAppItem *)item {
    NSNumber *n = [self.progressMap objectForKey:item.itemId];
    return n ? n.doubleValue : -1;
}

- (NSURL *)finishedFileForItem:(RSAppItem *)item {
    return [self.finishedMap objectForKey:item.itemId];
}

@end
