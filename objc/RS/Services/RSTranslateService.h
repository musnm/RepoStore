//
//  RSTranslateService.h
//  RepoStore — 简介翻译（免费 / 无需 API Key）
//
//  使用微软 Bing 翻译的公开网页接口：
//    1) GET  https://www.bing.com/translator   → 从 HTML 抓 params_AbusePreventionHelper = [key,"token",ttl]
//    2) POST https://www.bing.com/ttranslatev3  → 带 key + token 请求翻译
//
//  特点：自动检测源语言（auto-detect），支持长文本，返回的 usedLLM=true 表示走大模型，
//  质量优于传统 NMT。无需注册、无需 API Key。
//
//  设计约束：
//  - 默认不翻译，只有用户点击后才发起请求
//  - 结果缓存到内存，同一段文本不重复请求
//  - token 有 ttl（约 1 小时），过期自动重新抓取
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RSTranslateService : NSObject

+ (instancetype)shared;

/// 翻译一段文本到简体中文。
/// @param text       原文
/// @param completion 主线程回调。成功时 translated 非空、error 为 nil；失败时 translated 为 nil。
- (void)translateToChinese:(NSString *)text
                completion:(void (^)(NSString * _Nullable translated,
                                     NSString * _Nullable detectedLang,
                                     NSError * _Nullable error))completion;

/// 清除内存缓存（一般无需调用）
- (void)clearCache;

/// 粗判一段文本是否"已经是中文"，用于「无需翻译」时隐藏入口。
+ (BOOL)isMostlyChinese:(NSString *)text;

@end

NS_ASSUME_NONNULL_END
