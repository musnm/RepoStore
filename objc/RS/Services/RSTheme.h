#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 全局主题
@interface RSTheme : NSObject

+ (UIColor *)accent;
+ (UIColor *)accent2;
+ (UIColor *)bg;
+ (UIColor *)card;
+ (UIColor *)card2;
+ (UIColor *)textSub;

+ (CAGradientLayer *)gradientLayerWithFrame:(CGRect)frame;
+ (CAGradientLayer *)gradientForSeed:(NSString *)seed frame:(CGRect)frame;
+ (NSArray<UIColor *> *)paletteForSeed:(NSString *)seed;
+ (UIColor *)colorFromHex:(NSString *)hex;

@end

NS_ASSUME_NONNULL_END
