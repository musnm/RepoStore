//
//  RSDeobfuscator.m
//  RepoStore
//
//  注意：本文件依赖 RSEsignKey.h（第 2 方库的 ESign 解密密钥表，未随本仓库分发）。
//  在本地构建前，请自备该头文件，提供：
//      extern const unsigned char rs_esign_key[];
//      #define RS_ESIGN_KEY_LEN <key 长度>
//  来源参考：Nyasami/Ksign — AltSourceKit/Utilities/Key/EsignSourceKey.swift
//

#import "RSDeobfuscator.h"
#import "RSEsignKey.h"

/// 其它客户端自定义的段分隔符
static NSArray<NSString *> *RSDelimiters(void) {
    static NSArray *d;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        d = @[@"[K$]", @"[M$]"];
    });
    return d;
}

@implementation RSDeobfuscator

#pragma mark - 判断

+ (BOOL)isESignFormat:(NSString *)text {
    NSString *t = [text stringByTrimmingCharactersInSet:
                   [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return [t hasPrefix:@"source["];
}

+ (BOOL)looksLikeEncodedSource:(NSString *)text {
    NSString *t = [text stringByTrimmingCharactersInSet:
                   [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (t.length == 0) return NO;

    // 明显是 URL 就不当加密串
    NSString *low = t.lowercaseString;
    if ([low hasPrefix:@"http://"] || [low hasPrefix:@"https://"]) return NO;
    // 域名形态（含点且无换行、长度较短）也当 URL
    if (t.length < 200 && [t rangeOfString:@"\n"].location == NSNotFound
        && [t rangeOfString:@"."].location != NSNotFound
        && [t rangeOfString:@" "].location == NSNotFound
        && [t rangeOfString:@"["].location == NSNotFound) {
        return NO;
    }

    if ([self isESignFormat:t]) return YES;

    // 含分隔符或长得像 base64 且足够长
    for (NSString *d in RSDelimiters()) {
        if ([t rangeOfString:d].location != NSNotFound) return YES;
    }

    // 纯 base64 判定：去掉空白后全部是 base64 字符且长度 > 64
    NSCharacterSet *b64 = [NSCharacterSet characterSetWithCharactersInString:
        @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="];
    NSCharacterSet *inverted = [b64 invertedSet];
    if (t.length > 64 && [t rangeOfCharacterFromSet:inverted].location == NSNotFound) {
        return YES;
    }
    return NO;
}

#pragma mark - 解密

+ (nullable NSArray<NSString *> *)decodeSource:(NSString *)text {
    NSString *t = [text stringByTrimmingCharactersInSet:
                   [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (t.length == 0) return nil;

    // 1. ESign: source[...]
    if ([self isESignFormat:t]) {
        return [self decryptESign:t];
    }

    // 2. base64（可能含 [K$]/[M$] 分隔）
    NSArray *b64 = [self decodeBase64Lines:t];
    if (b64.count > 0) return b64;

    // 3. 明文多行
    NSArray *lines = [t componentsSeparatedByCharactersInSet:
                      [NSCharacterSet newlineCharacterSet]];
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *l in lines) {
        NSString *s = [l stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (s.length > 0) [out addObject:s];
    }
    return out.count ? out : nil;
}

/// 从 source[xxxx] 里取出 base64 正文
+ (nullable NSData *)extractBase64FromESign:(NSString *)text {
    NSString *t = [text stringByTrimmingCharactersInSet:
                   [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSRange open = [t rangeOfString:@"source["];
    if (open.location == NSNotFound) return nil;
    NSRange close = [t rangeOfString:@"]"
                             options:NSBackwardsSearch];
    if (close.location == NSNotFound || close.location <= NSMaxRange(open)) return nil;

    NSRange body = NSMakeRange(NSMaxRange(open), close.location - NSMaxRange(open));
    NSString *b64 = [t substringWithRange:body];
    // 去掉可能的空白
    b64 = [b64 stringByTrimmingCharactersInSet:
           [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (b64.length == 0) return nil;

    return [[NSData alloc] initWithBase64EncodedString:b64
                                               options:NSDataBase64DecodingIgnoreUnknownCharacters];
}

+ (nullable NSArray<NSString *> *)decryptESign:(NSString *)text {
    NSData *data = [self extractBase64FromESign:text];
    if (!data || data.length == 0) return nil;

    const unsigned char *in = data.bytes;
    NSUInteger n = data.length;
    NSMutableData *out = [NSMutableData dataWithLength:n];
    unsigned char *dst = out.mutableBytes;

    NSUInteger keyIndex = 0;
    for (NSUInteger i = 0; i < n; i++) {
        dst[i] = in[i] ^ rs_esign_key[keyIndex];
        keyIndex = (keyIndex + 1) % RS_ESIGN_KEY_LEN;
    }

    NSString *s = [[NSString alloc] initWithData:out encoding:NSUTF8StringEncoding];
    if (!s) return nil;

    NSMutableArray *lines = [NSMutableArray array];
    for (NSString *l in [s componentsSeparatedByString:@"\n"]) {
        NSString *x = [l stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (x.length > 0) [lines addObject:x];
    }
    return lines.count ? lines : nil;
}

+ (nullable NSArray<NSString *> *)decodeBase64Lines:(NSString *)code {
    NSData *data = [[NSData alloc] initWithBase64EncodedString:code
                                                       options:NSDataBase64DecodingIgnoreUnknownCharacters];
    if (!data) return nil;
    NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!s || s.length == 0) return nil;

    // 含客户端分隔符
    for (NSString *d in RSDelimiters()) {
        if ([s rangeOfString:d].location != NSNotFound) {
            NSMutableArray *out = [NSMutableArray array];
            for (NSString *p in [s componentsSeparatedByString:d]) {
                NSString *x = [p stringByTrimmingCharactersInSet:
                               [NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (x.length > 0) [out addObject:x];
            }
            return out.count ? out : nil;
        }
    }

    NSString *trim = [s stringByTrimmingCharactersInSet:
                      [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return trim.length ? @[trim] : nil;
}

#pragma mark - 加密（自建源用）

+ (nullable NSString *)encodeAsESign:(NSString *)plain {
    if (plain.length == 0) return nil;
    NSData *d = [plain dataUsingEncoding:NSUTF8StringEncoding];
    if (!d) return nil;

    const unsigned char *in = d.bytes;
    NSUInteger n = d.length;
    NSMutableData *out = [NSMutableData dataWithLength:n];
    unsigned char *dst = out.mutableBytes;

    NSUInteger keyIndex = 0;
    for (NSUInteger i = 0; i < n; i++) {
        dst[i] = in[i] ^ rs_esign_key[keyIndex];
        keyIndex = (keyIndex + 1) % RS_ESIGN_KEY_LEN;
    }

    NSString *b64 = [out base64EncodedStringWithOptions:0];
    return [NSString stringWithFormat:@"source[%@]", b64];
}

@end
