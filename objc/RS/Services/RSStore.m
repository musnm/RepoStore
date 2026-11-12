#import "RSStore.h"
#import "RSDeobfuscator.h"
#import "RSUnlockService.h"

NSString *const RSDownloadsChangedNotification = @"RSDownloadsChangedNotification";

@implementation RSDownloadRecord
@end

@interface RSStore ()
@property (nonatomic, strong) NSMutableArray<RSRepo *> *mutableRepos;
@property (nonatomic, strong) NSMutableArray<RSDownloadRecord *> *records;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *progressMap;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSURL *> *finishedMap;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSURLSessionDownloadTask *> *taskMap;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, void (^)(double)> *progressObservers;
// taskIdentifier → itemId
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSString *> *taskItemMap;
// 暂停：itemId → resumeData
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSData *> *resumeDataMap;
@property (nonatomic, strong) NSMutableSet<NSString *> *pausedSet;
@property (nonatomic, strong) NSURLSession *session;
@end

@implementation RSStore

+ (instancetype)shared {
    static RSStore *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [RSStore new]; });
    return s;
}

- (instancetype)init {
    if ((self = [super init])) {
        _mutableRepos = [NSMutableArray array];
        _records = [NSMutableArray array];
        _progressMap = [NSMutableDictionary dictionary];
        _finishedMap = [NSMutableDictionary dictionary];
        _taskMap = [NSMutableDictionary dictionary];
        _progressObservers = [NSMutableDictionary dictionary];
        _taskItemMap = [NSMutableDictionary dictionary];
        _resumeDataMap = [NSMutableDictionary dictionary];
        _pausedSet = [NSMutableSet set];

        NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
        cfg.timeoutIntervalForRequest = 30;
        cfg.timeoutIntervalForResource = 600;
        cfg.HTTPMaximumConnectionsPerHost = 4;
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

- (NSURL *)storeURL {
    NSURL *dir = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                        inDomains:NSUserDomainMask].firstObject;
    [[NSFileManager defaultManager] createDirectoryAtURL:dir
                             withIntermediateDirectories:YES attributes:nil error:nil];
    return [dir URLByAppendingPathComponent:@"repos.json"];
}

- (void)load {
    NSData *data = [NSData dataWithContentsOfURL:[self storeURL]];
    if (!data) return;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![obj isKindOfClass:[NSArray class]]) return;
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
    if (data) [data writeToURL:[self storeURL] atomically:YES];
}

#pragma mark - 源管理

- (RSRepo *)repoWithUID:(NSString *)uid {
    for (RSRepo *r in self.mutableRepos) {
        if ([r.uid isEqualToString:uid]) return r;
    }
    return nil;
}

- (RSRepo *)addRepoWithURL:(NSString *)url {
    NSString *u = [url stringByTrimmingCharactersInSet:
                   [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (u.length == 0) return nil;

    for (RSRepo *r in self.mutableRepos) {
        if ([r.url isEqualToString:u]) return r;
    }

    RSRepo *repo = [[RSRepo alloc] initWithURL:u];
    [self.mutableRepos insertObject:repo atIndex:0];
    [self save];
    return repo;
}

- (void)addRepoWithURL:(NSString *)url autoRefresh:(BOOL)refresh {
    RSRepo *r = [self addRepoWithURL:url];
    if (r && refresh) {
        [self refreshRepo:r completion:nil];
    }
}

- (void)removeRepo:(RSRepo *)repo {
    if (!repo) return;
    // 清理属主是该源的所有下载中任务 / 记录
    NSMutableArray *ids = [NSMutableArray array];
    for (RSAppItem *a in repo.apps) {
        if (a.itemId.length) [ids addObject:a.itemId];
    }
    for (NSString *iid in ids) {
        [self cancelDownloadForItemId:iid];
    }
    [self.mutableRepos removeObject:repo];
    [self save];
}

#pragma mark - 刷新

- (void)refreshRepo:(RSRepo *)repo
         completion:(void (^)(BOOL, NSString * _Nullable))completion {
    if (!repo || repo.url.length == 0) {
        if (completion) completion(NO, @"源地址为空");
        return;
    }
    NSURL *u = [NSURL URLWithString:repo.url];
    if (!u) {
        if (completion) completion(NO, @"源地址无效");
        return;
    }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:u];
    req.timeoutInterval = 25;
    [req setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 16_1_2 like Mac OS X) AppleWebKit/605.1.15"
        forHTTPHeaderField:@"User-Agent"];
    if (repo.unlockToken.length) {
        [req setValue:repo.unlockToken forHTTPHeaderField:@"X-Unlock-Token"];
        [req setValue:repo.unlockToken forHTTPHeaderField:@"Authorization"];
    }

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task =
    [self.session dataTaskWithRequest:req
                    completionHandler:^(NSData *data,
                                        NSURLResponse *resp,
                                        NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
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
            // 处理 UTF-8 BOM
            if (body.length >= 3) {
                const unsigned char *b = body.bytes;
                if (b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) {
                    body = [body subdataWithRange:NSMakeRange(3, body.length - 3)];
                }
            }

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

            id obj = parsed;

            NSInteger n = [repo applyJSON:(NSDictionary *)obj];
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
    // 下载中在前，其次按完成时间倒序
    NSMutableArray *downloading = [NSMutableArray array];
    NSMutableArray *done = [NSMutableArray array];
    for (RSDownloadRecord *r in self.records) {
        if (r.finished) [done addObject:r];
        else [downloading addObject:r];
    }
    [done sortUsingComparator:^NSComparisonResult(RSDownloadRecord *a, RSDownloadRecord *b) {
        return [b.finishedAt ?: [NSDate distantPast] compare:a.finishedAt ?: [NSDate distantPast]];
    }];
    NSMutableArray *out = [NSMutableArray arrayWithArray:downloading];
    [out addObjectsFromArray:done];
    return out;
}

- (double)currentProgressForItemId:(NSString *)itemId {
    if (!itemId) return -1;
    NSNumber *n = nil;
    @synchronized (self.progressMap) {
        n = [self.progressMap objectForKey:itemId];
    }
    return n ? n.doubleValue : -1;
}

- (BOOL)isDownloadingItemId:(NSString *)itemId {
    return [self.progressMap objectForKey:itemId] != nil;
}

- (void)removeDownloadRecord:(RSDownloadRecord *)record {
    if (!record) return;
    if (record.filePath.length) {
        [[NSFileManager defaultManager] removeItemAtPath:record.filePath error:nil];
    }
    [self.records removeObject:record];
    [self.finishedMap removeObjectForKey:record.itemId];
    [self saveRecords];
    [[NSNotificationCenter defaultCenter] postNotificationName:RSDownloadsChangedNotification object:nil];
}

/// 反查某个条目属于哪个源（用于带上该源的解锁令牌）
- (nullable RSRepo *)repoContainingItem:(RSAppItem *)item {
    if (!item) return nil;
    NSString *iid = item.itemId;
    for (RSRepo *r in self.mutableRepos) {
        for (RSAppItem *a in r.apps) {
            if ([a.itemId isEqualToString:iid]) return r;
            // 兜底：同 bundleID + 同下载地址
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

    // 进度回调
    [self.session getTasksWithCompletionHandler:^(NSArray *d, NSArray *u, NSArray *dl) {}];

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

    // 先落一条"下载中"记录，让下载页立刻能看到
    RSDownloadRecord *rec = [self recordForItemId:key];
    if (!rec) {
        rec = [RSDownloadRecord new];
        rec.itemId = key;
        [self.records addObject:rec];
    }
    rec.name      = item.name ?: @"";
    rec.version   = item.version ?: @"";
    rec.sizeText  = item.sizeText ?: @"";
    rec.iconURL   = item.iconURL ?: @"";
    rec.finished  = NO;
    rec.finishedAt = nil;
    [self saveRecords];
    [[NSNotificationCenter defaultCenter] postNotificationName:RSDownloadsChangedNotification object:nil];

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
            NSString *dest = [[self downloadsDir] stringByAppendingPathComponent:fn];
            NSURL *destURL = [NSURL fileURLWithPath:dest];
            [[NSFileManager defaultManager] removeItemAtURL:destURL error:nil];
            NSError *mvErr = nil;
            [[NSFileManager defaultManager] moveItemAtURL:location toURL:destURL error:&mvErr];
            if (mvErr) {
                [self.progressMap removeObjectForKey:key];
                self.lastError = mvErr.localizedDescription;
                [[NSNotificationCenter defaultCenter] postNotificationName:@"RSDownloadFailed"
                                                                    object:key];
                [[NSNotificationCenter defaultCenter] postNotificationName:RSDownloadsChangedNotification
                                                                    object:nil];
                if (completion) completion(nil, mvErr.localizedDescription);
                return;
            }
            [self.progressMap removeObjectForKey:key];
            [self.taskMap removeObjectForKey:key];
            [self.finishedMap setObject:destURL forKey:key];

            // 写入持久化下载记录
            RSDownloadRecord *rec = [self recordForItemId:key];
            if (!rec) {
                rec = [RSDownloadRecord new];
                rec.itemId = key;
                [self.records addObject:rec];
            }
            rec.name      = item.name ?: @"";
            rec.version   = item.version ?: @"";
            rec.sizeText  = item.sizeText ?: @"";
            rec.iconURL   = item.iconURL ?: @"";
            rec.fileName  = fn;
            rec.filePath  = dest;
            rec.finished  = YES;
            rec.finishedAt = [NSDate date];
            [self saveRecords];

            [[NSNotificationCenter defaultCenter] postNotificationName:@"RSDownloadFinished"
                                                                object:key];
            [[NSNotificationCenter defaultCenter] postNotificationName:RSDownloadsChangedNotification
                                                                object:nil];
            if (completion) completion(destURL, nil);
        });
    }];

    // 进度：用 KVO 观察 task 的 countOfBytesReceived
    if (progress) {
        [task addObserver:self forKeyPath:@"countOfBytesReceived"
                  options:NSKeyValueObservingOptionNew context:nil];
        [self.progressObservers setObject:progress forKey:@(task.taskIdentifier)];
    }
    // 记录 task → itemId，KVO 回调里靠它把进度写回 progressMap
    [self.taskItemMap setObject:key forKey:@(task.taskIdentifier)];

    [self.taskMap setObject:task forKey:key];
    [task resume];
}

#pragma mark - 取消下载

/// 取消某个条目的下载，并彻底清除它产生的所有痕迹
- (void)cancelDownloadForItemId:(NSString *)itemId {
    if (itemId.length == 0) return;

    NSURLSessionDownloadTask *task = [self.taskMap objectForKey:itemId];
    if (task) {
        // 先摘掉观察者，避免 cancel 时 KVO 回调引发问题
        [self.progressObservers removeObjectForKey:@(task.taskIdentifier)];
        @try {
            [task removeObserver:self forKeyPath:@"countOfBytesReceived"];
        } @catch (NSException *e) { /* 忽略未注册的情况 */ }
        [task cancel];
        [self.taskMap removeObjectForKey:itemId];
    }

    [self.progressMap removeObjectForKey:itemId];
    [self.finishedMap removeObjectForKey:itemId];
    [self.resumeDataMap removeObjectForKey:itemId];
    [self.pausedSet removeObject:itemId];

    // 删除该条目在下载目录里的所有残留文件
    [self purgeFilesForItemId:itemId];
    // 删除下载记录
    for (RSDownloadRecord *r in [self.records copy]) {
        if ([r.itemId isEqualToString:itemId]) {
            [self.records removeObject:r];
        }
    }
    [self saveRecords];

    // 清理临时目录里可能残留的下载碎片
    [self purgeTempFragments];

    [[NSNotificationCenter defaultCenter] postNotificationName:RSDownloadsChangedNotification object:nil];
}

/// 删除某条目在下载目录内的所有文件（含同名不同后缀、.download 临时文件）
- (void)purgeFilesForItemId:(NSString *)itemId {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = [self downloadsDir];

    // 1. 按记录里的文件名删
    for (RSDownloadRecord *r in self.records) {
        if ([r.itemId isEqualToString:itemId] && r.filePath.length) {
            [fm removeItemAtPath:r.filePath error:nil];
        }
    }

    // 2. 按 itemId 前缀清理（缓存文件名里包含 itemId 的一部分）
    NSArray<NSString *> *files = [fm contentsOfDirectoryAtPath:dir error:nil];
    for (NSString *f in files) {
        if ([f containsString:itemId] ||
            [f hasSuffix:@".download"] || [f hasSuffix:@".tmp"]) {
            // 只删能对上 itemId 的，避免误删其它下载
            if ([f containsString:itemId]) {
                [fm removeItemAtPath:[dir stringByAppendingPathComponent:f] error:nil];
            }
        }
    }
}

#pragma mark - 暂停 / 继续

- (BOOL)isPausedItemId:(NSString *)itemId {
    return itemId.length && [self.pausedSet containsObject:itemId];
}

- (void)pauseDownloadForItemId:(NSString *)itemId {
    if (itemId.length == 0) return;
    NSURLSessionDownloadTask *task = [self.taskMap objectForKey:itemId];
    if (!task) return;

    [self.pausedSet addObject:itemId];
    // 保存当前进度百分比，续传后从该点继续显示
    NSNumber *cur = [self.progressMap objectForKey:itemId];
    if (cur) [self.resumeDataMap setObject:(NSData *)cur forKey:itemId];

    [self.progressObservers removeObjectForKey:@(task.taskIdentifier)];
    @try {
        [task removeObserver:self forKeyPath:@"countOfBytesReceived"];
    } @catch (NSException *e) {}

    __weak typeof(self) weakSelf = self;
    [task cancelByProducingResumeData:^(NSData *resumeData) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            if (resumeData) {
                [self.resumeDataMap setObject:resumeData forKey:itemId];
            }
            // 保留进度但标记为暂停：progressMap 里放 -2 表示暂停
            [self.progressMap setObject:@(-2) forKey:itemId];
            [self.taskMap removeObjectForKey:itemId];
            [[NSNotificationCenter defaultCenter] postNotificationName:RSDownloadsChangedNotification
                                                                object:nil];
        });
    }];
}

- (void)resumeDownloadForItemId:(NSString *)itemId {
    if (itemId.length == 0) return;
    NSData *resumeData = [self.resumeDataMap objectForKey:itemId];
    if (!resumeData) { [self.pausedSet removeObject:itemId]; return; }

    [self.pausedSet removeObject:itemId];
    [self.progressMap setObject:@(0) forKey:itemId];

    __weak typeof(self) weakSelf = self;
    NSURLSessionDownloadTask *task =
    [self.session downloadTaskWithResumeData:resumeData
                           completionHandler:^(NSURL *location, NSURLResponse *resp, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [self.progressMap removeObjectForKey:itemId];
            [self.taskMap removeObjectForKey:itemId];
            [self.resumeDataMap removeObjectForKey:itemId];
            if (err || !location) {
                self.lastError = err.localizedDescription ?: @"续传失败";
                [[NSNotificationCenter defaultCenter] postNotificationName:@"RSDownloadFailed"
                                                                    object:itemId];
                [[NSNotificationCenter defaultCenter] postNotificationName:RSDownloadsChangedNotification
                                                                    object:nil];
                return;
            }
            RSDownloadRecord *rec = [self recordForItemId:itemId];
            NSString *fn = rec.fileName.length ? rec.fileName : @"app.ipa";
            NSString *dest = [[self downloadsDir] stringByAppendingPathComponent:fn];
            NSURL *destURL = [NSURL fileURLWithPath:dest];
            [[NSFileManager defaultManager] removeItemAtURL:destURL error:nil];
            [[NSFileManager defaultManager] moveItemAtURL:location toURL:destURL error:nil];

            [self.finishedMap setObject:destURL forKey:itemId];
            if (rec) {
                rec.filePath = dest;
                rec.finished = YES;
                rec.finishedAt = [NSDate date];
            }
            [self saveRecords];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"RSDownloadFinished"
                                                                object:itemId];
            [[NSNotificationCenter defaultCenter] postNotificationName:RSDownloadsChangedNotification
                                                                object:nil];
        });
    }];

    [task addObserver:self forKeyPath:@"countOfBytesReceived"
              options:NSKeyValueObservingOptionNew context:nil];
    [self.taskItemMap setObject:itemId forKey:@(task.taskIdentifier)];
    [self.taskMap setObject:task forKey:itemId];
    [task resume];
}

/// taskIdentifier → itemId
- (NSString *)itemIdForTaskIdentifier:(NSNumber *)tid {
    if (!tid) return nil;
    return [self.taskItemMap objectForKey:tid];
}

/// 清掉 tmp 目录里 NSURLSession 留下的下载碎片
- (void)purgeTempFragments {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *tmp = NSTemporaryDirectory();
    NSArray<NSString *> *items = [fm contentsOfDirectoryAtPath:tmp error:nil];
    for (NSString *f in items) {
        if ([f hasPrefix:@"CFNetworkDownload"] || [f hasSuffix:@".download"] ||
            [f hasSuffix:@".ipdownload"]) {
            [fm removeItemAtPath:[tmp stringByAppendingPathComponent:f] error:nil];
        }
    }
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

        // 关键：必须把进度写回 progressMap，
        // 否则下载管理器 currentProgressForItemId 永远读到初始值 0
        // （详情页靠 cb(p) 回调能显示，但管理器读不到 → 进度条一动不动）
        NSString *itemId = [[self itemIdForTaskIdentifier:@(t.taskIdentifier)] copy];
        if (itemId) {
            // KVO 在后台线程回调，字典是共享的，必须加锁防止并发写崩溃
            @synchronized (self.progressMap) {
                [self.progressMap setObject:@(p) forKey:itemId];
            }
        }

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

- (NSURL *)finishedURLForItem:(RSAppItem *)item {
    return [self.finishedMap objectForKey:item.itemId];
}

@end
