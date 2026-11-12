#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 圆角图标视图：给定 URL 就异步加载，否则用 seed 生成色彩底色 + 首字母
@interface RSIconView : UIView

- (void)configureWithURL:(nullable NSString *)url
                    seed:(nullable NSString *)seed
              cornerRadius:(CGFloat)radius;

@end

NS_ASSUME_NONNULL_END
