#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 应用图标：远程加载，失败时渐变+首字母
@interface RSIconView : UIView

- (void)configureWithURL:(nullable NSString *)urlString
                    seed:(NSString *)seed
                cornerRadius:(CGFloat)corner;

@end

NS_ASSUME_NONNULL_END
