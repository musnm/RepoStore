//
//  RSTranslateService.m
//  RepoStore — 简介翻译（Bing 公开接口）
//

#import "RSTranslateService.h"

static NSString *const kBingTranslatorPage = @"https://www.bing.com/translator";
static NSString *const kBingTranslateAPI  = @"https://www.bing.com/ttranslatev3?isVertical=1&&IG=1&IID=translator.5028";

// Bing 单次请求实测可处理 900+ 字符，取保守值；超长时按句子边界切开
static const NSUInteger kMaxChunkChars = 900;

static NSString *const kUserAgent =
    @"Mozilla/5.0 (iPhone; CPU iPhone OS 16_1_2 like Mac OS X) "
    @"AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1";

@interface RSTranslateService ()
@property (nonatomic, copy, nullable) NSString *token;
@property (nonatomic, copy, nullable) NSString *key;
@property (nonatomic, strong, nullable) NSDate *tokenExpiry;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *cache;
@property (nonatomic, strong) NSURLSession *session;
// 串行化 token 抓取，避免并发重复抓取
@property (nonatomic, strong) dispatch_queue_t tokenQueue;
@end

@implementation RSTranslateService

+ (instancetype)shared {
    static RSTranslateService *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [RSTranslateService new]; });
    return s;
}

- (instancetype)init {
    if ((self = [super init])) {
        _cache = [NSMutableDictionary dictionary];
        _tokenQueue = dispatch_queue_create("com.musnm.repostore.translate.token", DISPATCH_QUEUE_SERIAL);

        NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        cfg.timeoutIntervalForRequest = 15;
        cfg.timeoutIntervalForResource = 40;
        cfg.HTTPAdditionalHeaders = @{@"User-Agent": kUserAgent,
                                      @"Accept-Language": @"zh-CN,zh;q=0.9,en;q=0.8"};
        _session = [NSURLSession sessionWithConfiguration:cfg];
    }
    return self;
}

- (void)clearCache {
    @synchronized (self.cache) {
        [self.cache removeAllObjects];
    }
}

#pragma mark - 中文判定

+ (BOOL)isMostlyChinese:(NSString *)text {
    if (text.length == 0) return YES;
    NSUInteger cjk = 0, letters = 0;
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        if (c >= 0x4E00 && c <= 0x9FFF) cjk++;
        else if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')) letters++;
    }
    NSUInteger total = cjk + letters;
    if (total == 0) return YES;          // 全是符号/数字，不需要翻译
    // 中文字符占比 > 60% 即认为已是中文
    return (double)cjk / (double)total > 0.6;
}

#pragma mark - 对外入口

- (void)translateToChinese:(NSString *)text
                completion:(void (^)(NSString *, NSString *, NSError *))completion {
    if (completion == nil) return;

    NSString *src = [text stringByTrimmingCharactersInSet:
                     [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (src.length == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil, nil, [self errorWithCode:1 msg:@"简介为空"]);
        });
        return;
    }

    // 命中缓存直接返回
    NSString *cached = nil;
    @synchronized (self.cache) {
        cached = self.cache[src];
    }
    if (cached.length) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(cached, nil, nil);
        });
        return;
    }

    [self ensureToken:^(NSError *tokenErr) {
        if (tokenErr) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, nil, tokenErr); });
            return;
        }
        [self translateChunks:src completion:^(NSString *result, NSString *lang, NSError *err) {
            if (result.length) {
                @synchronized (self.cache) {
                    self.cache[src] = result;
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{ completion(result, lang, err); });
        }];
    }];
}

#pragma mark - Token 获取

- (void)ensureToken:(void (^)(NSError * _Nullable))done {
    // 有效期内直接复用
    if (self.token.length && self.key.length &&
        self.tokenExpiry && [self.tokenExpiry timeIntervalSinceNow] > 120) {
        done(nil);
        return;
    }

    dispatch_async(self.tokenQueue, ^{
        // 二次检查（可能已被前一个排队任务刷新）
        if (self.token.length && self.key.length &&
            self.tokenExpiry && [self.tokenExpiry timeIntervalSinceNow] > 120) {
            done(nil);
            return;
        }

        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:
                                    [NSURL URLWithString:kBingTranslatorPage]];
        [req setValue:kUserAgent forHTTPHeaderField:@"User-Agent"];

        NSURLSessionDataTask *t =
        [self.session dataTaskWithRequest:req completionHandler:^(NSData *data,
                                                                  NSURLResponse *resp,
                                                                  NSError *err) {
            if (err || data.length == 0) {
                done([self errorWithCode:2 msg:@"无法连接翻译服务"]);
                return;
            }
            NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (html.length == 0) {
                html = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
            }

            // 匹配：params_AbusePreventionHelper = [1794609709462,"Dk-n_bK...",3600000]
            NSString *key = nil, *token = nil;
            NSUInteger ttl = 3600;

            NSRange marker = [html rangeOfString:@"params_AbusePreventionHelper"];
            if (marker.location != NSNotFound) {
                NSString *tail = [html substringFromIndex:marker.location];
                NSRange open = [tail rangeOfString:@"["];
                NSRange close = [tail rangeOfString:@"]"];
                if (open.location != NSNotFound && close.location != NSNotFound &&
                    close.location > open.location) {
                    NSString *inner = [tail substringWithRange:
                                       NSMakeRange(open.location + 1,
                                                   close.location - open.location - 1)];
                    // inner 形如：1794609709462,"Dk-n_bK...",3600000
                    NSArray<NSString *> *parts = [inner componentsSeparatedByString:@","];
                    if (parts.count >= 2) {
                        key = [parts[0] stringByTrimmingCharactersInSet:
                               [NSCharacterSet whitespaceAndNewlineCharacterSet]];
                        NSString *tk = parts[1];
                        tk = [tk stringByTrimmingCharactersInSet:
                              [NSCharacterSet characterSetWithCharactersInString:@" \t\r\n\""]];
                        token = tk;
                    }
                    if (parts.count >= 3) {
                        NSInteger v = [[parts[2] stringByTrimmingCharactersInSet:
                                        [NSCharacterSet whitespaceAndNewlineCharacterSet]] integerValue];
                        if (v > 0) ttl = (NSUInteger)v;
                    }
                }
            }

            if (key.length == 0 || token.length == 0) {
                done([self errorWithCode:3 msg:@"翻译服务返回格式变化，请稍后再试"]);
                return;
            }

            self.key = key;
            self.token = token;
            // ttl 约 3600000（毫秒）；留 5 分钟余量
            NSTimeInterval life = (NSTimeInterval)ttl / 1000.0;
            if (life < 600) life = (NSTimeInterval)ttl;   // 有些返回是秒
            self.tokenExpiry = [NSDate dateWithTimeIntervalSinceNow:MAX(life - 300, 60)];
            done(nil);
        }];
        [t resume];
    });
}

#pragma mark - 分段翻译

- (void)translateChunks:(NSString *)text
             completion:(void (^)(NSString *, NSString *, NSError *))completion {
    NSArray<NSString *> *chunks = [self splitText:text limit:kMaxChunkChars];

    NSMutableArray<NSString *> *results = [NSMutableArray array];
    for (NSUInteger i = 0; i < chunks.count; i++) {
        [results addObject:@""];
    }

    __block NSUInteger remaining = chunks.count;
    __block NSUInteger failedCount = 0;
    __block NSString *detectedLang = nil;
    __block BOOL finished = NO;

    for (NSUInteger idx = 0; idx < chunks.count; idx++) {
        [self requestChunk:chunks[idx]
                completion:^(NSString *translated, NSString *lang, NSError *err) {
            @synchronized (results) {
                if (translated.length) {
                    results[idx] = translated;
                    if (detectedLang == nil && lang.length) detectedLang = lang;
                } else {
                    failedCount++;
                }
                remaining--;

                if (remaining == 0 && !finished) {
                    finished = YES;
                    if (failedCount == chunks.count) {
                        completion(nil, nil, err ?: [self errorWithCode:4 msg:@"翻译失败"]);
                        return;
                    }
                    completion([results componentsJoinedByString:@""], detectedLang, nil);
                }
            }
        }];
    }
}

- (void)requestChunk:(NSString *)chunk
          completion:(void (^)(NSString *, NSString *, NSError *))completion {
    // token 过期（ttl 到）时会失败，允许重试一次
    [self doRequestChunk:chunk retry:YES completion:completion];
}

- (void)doRequestChunk:(NSString *)chunk
                 retry:(BOOL)allowRetry
            completion:(void (^)(NSString *, NSString *, NSError *))completion {

    if (self.token.length == 0 || self.key.length == 0) {
        [self ensureToken:^(NSError *e) {
            if (e) { completion(nil, nil, e); return; }
            [self doRequestChunk:chunk retry:NO completion:completion];
        }];
        return;
    }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:
                                [NSURL URLWithString:kBingTranslateAPI]];
    req.HTTPMethod = @"POST";
    [req setValue:kUserAgent forHTTPHeaderField:@"User-Agent"];
    [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [req setValue:@"https://www.bing.com/translator" forHTTPHeaderField:@"Referer"];

    NSString *body = [NSString stringWithFormat:
                      @"fromLang=auto-detect&to=zh-Hans&text=%@&token=%@&key=%@",
                      [self urlEncode:chunk],
                      [self urlEncode:self.token],
                      [self urlEncode:self.key]];
    req.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];

    NSURLSessionDataTask *t =
    [self.session dataTaskWithRequest:req completionHandler:^(NSData *data,
                                                              NSURLResponse *resp,
                                                              NSError *err) {
        if (err) { completion(nil, nil, err); return; }

        NSHTTPURLResponse *http = (NSHTTPURLResponse *)resp;
        if ([http isKindOfClass:[NSHTTPURLResponse class]] && http.statusCode != 200) {
            // 400/403 一般是 token 失效
            if (allowRetry && (http.statusCode == 400 || http.statusCode == 403)) {
                self.token = nil; self.key = nil; self.tokenExpiry = nil;
                [self doRequestChunk:chunk retry:NO completion:completion];
                return;
            }
            completion(nil, nil, [self errorWithCode:(NSInteger)http.statusCode
                                                 msg:@"翻译服务拒绝请求"]);
            return;
        }

        id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![obj isKindOfClass:[NSArray class]] || [(NSArray *)obj count] == 0) {
            if (allowRetry) {
                self.token = nil; self.key = nil; self.tokenExpiry = nil;
                [self doRequestChunk:chunk retry:NO completion:completion];
                return;
            }
            completion(nil, nil, [self errorWithCode:5 msg:@"翻译结果解析失败"]);
            return;
        }

        NSDictionary *first = [(NSArray *)obj firstObject];
        if (![first isKindOfClass:[NSDictionary class]]) {
            completion(nil, nil, [self errorWithCode:5 msg:@"翻译结果解析失败"]);
            return;
        }

        NSString *out = nil;
        NSArray *trans = first[@"translations"];
        if ([trans isKindOfClass:[NSArray class]] && trans.count > 0) {
            id t0 = trans.firstObject;
            if ([t0 isKindOfClass:[NSDictionary class]]) {
                out = t0[@"text"];
            }
        }

        NSString *lang = nil;
        NSDictionary *dl = first[@"detectedLanguage"];
        if ([dl isKindOfClass:[NSDictionary class]]) {
            lang = dl[@"language"];
        }

        if (out == nil) {
            completion(nil, nil, [self errorWithCode:5 msg:@"翻译结果为空"]);
            return;
        }
        completion(out, lang, nil);
    }];
    [t resume];
}

#pragma mark - 工具

/// 按句子边界切分，尽量不切断句子
- (NSArray<NSString *> *)splitText:(NSString *)text limit:(NSUInteger)limit {
    if (text.length <= limit) return @[text];

    NSMutableArray<NSString *> *out = [NSMutableArray array];
    NSString *rest = text;

    while (rest.length > limit) {
        NSString *head = [rest substringToIndex:limit];

        // 在窗口内从后往前找段落/句子边界
        NSInteger cut = -1;
        NSArray<NSString *> *seps = @[@"\n\n", @"\n", @". ", @"! ", @"? ", @"。", @"！", @"？", @"; ", @"；"];
        for (NSString *sep in seps) {
            NSRange r = [head rangeOfString:sep options:NSBackwardsSearch];
            if (r.location != NSNotFound) {
                cut = (NSInteger)(r.location + r.length);
                break;
            }
        }
        if (cut <= 0) {
            // 找不到边界就找空格
            NSRange r = [head rangeOfString:@" " options:NSBackwardsSearch];
            cut = (r.location != NSNotFound) ? (NSInteger)(r.location + r.length) : (NSInteger)limit;
        }
        if (cut <= 0) cut = (NSInteger)limit;

        [out addObject:[rest substringToIndex:(NSUInteger)cut]];
        rest = [rest substringFromIndex:(NSUInteger)cut];
    }
    if (rest.length) [out addObject:rest];
    return out;
}

- (NSString *)urlEncode:(NSString *)s {
    if (s.length == 0) return @"";
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
        @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"];
    return [s stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: @"";
}

- (NSError *)errorWithCode:(NSInteger)code msg:(NSString *)msg {
    return [NSError errorWithDomain:@"RSTranslateError"
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: msg ?: @"翻译失败"}];
}

@end
