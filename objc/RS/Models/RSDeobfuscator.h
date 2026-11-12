//
//  RSDeobfuscator.h
//  RepoStore
//
//  源「加密串」解码器 —— 兼容 ESign(轻松签) / Ksign 等生态
//
//  支持三种输入：
//    1. source[<base64>]      ESign 加密源（esign_key 逐字节 XOR）
//    2. <base64> 含 [K$]/[M$] 自定义客户端分隔的源
//    3. <base64>              普通 base64 加密源
//    4. 明文多行               直接按行切分
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RSDeobfuscator : NSObject

/// 判断输入是否属于「加密串」而非 http(s) URL
+ (BOOL)looksLikeEncodedSource:(NSString *)text;

/// 解码源串，返回按行切分后的内容；非加密串或解码失败返回 nil
+ (nullable NSArray<NSString *> *)decodeSource:(NSString *)text;

/// 是否为 ESign 格式（source[...]）
+ (BOOL)isESignFormat:(NSString *)text;

/// 把明文 JSON 编码成 ESign 格式 source[base64]，用于自建加密源
+ (nullable NSString *)encodeAsESign:(NSString *)plain;

@end

NS_ASSUME_NONNULL_END
