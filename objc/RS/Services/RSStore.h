#import <Foundation/Foundation.h>
#import "RSRepo.h"
#import "RSAppItem.h"

NS_ASSUME_NONNULL_BEGIN

/// 下载记录变化通知
extern NSString *const RSDownloadsChangedNotification;

/// 一条下载记录
@interface RSDownloadRecord : NSObject
@property (nonatomic, copy) NSString *itemId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *version;
@property (nonatomic, copy) NSString *sizeText;
@property (nonatomic, copy) NSString *iconURL;
@property (nonatomic, copy) NSString *fileName;
@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, assign) BOOL finished;
@property (nonatomic, strong, nullable) NSDate *finishedAt;
@end

@interface RSStore : NSObject

+ (instancetype)shared;

@property (nonatomic, copy, nullable) NSString *lastError;
@property (nonatomic, readonly) NSArray<RSRepo *> *repos;

// 源管理
- (nullable RSRepo *)addRepoWithURL:(NSString *)url;
- (void)addRepoWithURL:(NSString *)url autoRefresh:(BOOL)refresh;
- (void)removeRepo:(RSRepo *)repo;
- (nullable RSRepo *)repoWithUID:(NSString *)uid;

// 刷新
- (void)refreshRepo:(nullable RSRepo *)repo
         completion:(nullable void (^)(BOOL ok, NSString *_Nullable err))completion;
- (void)refreshRepoByUID:(NSString *)uid
              completion:(nullable void (^)(BOOL ok, NSString *_Nullable err))completion;
- (void)refreshAll:(nullable void (^)(void))completion;

// 解锁
- (void)unlockRepo:(RSRepo *)repo
              code:(NSString *)code
        completion:(void (^)(BOOL ok, NSString *_Nullable err))completion;
- (void)lockRepo:(RSRepo *)repo;

// 下载
- (void)downloadItem:(RSAppItem *)item;

/// 带进度回调的下载
- (void)downloadItem:(RSAppItem *)item
            progress:(void (^ _Nullable)(double p))progress
          completion:(void (^ _Nullable)(NSURL * _Nullable fileURL, NSString * _Nullable error))completion;
- (double)progressForItem:(RSAppItem *)item;
- (nullable NSURL *)finishedURLForItem:(RSAppItem *)item;

// 下载记录（持久化）
- (NSString *)downloadsDir;
- (NSArray<RSDownloadRecord *> *)downloadRecords;
- (double)currentProgressForItemId:(NSString *)itemId;
- (BOOL)isDownloadingItemId:(NSString *)itemId;
- (void)removeDownloadRecord:(RSDownloadRecord *)record;

/// 取消下载并彻底清理相关文件与记录
- (void)cancelDownloadForItemId:(NSString *)itemId;

/// 暂停下载（保留断点，可续传）
- (void)pauseDownloadForItemId:(NSString *)itemId;
/// 从断点继续下载
- (void)resumeDownloadForItemId:(NSString *)itemId;
/// 是否处于暂停状态
- (BOOL)isPausedItemId:(NSString *)itemId;

@end

NS_ASSUME_NONNULL_END
