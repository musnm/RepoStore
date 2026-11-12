#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const RSPopMenuItemKeyTitle;
extern NSString *const RSPopMenuItemKeySymbol;

/// 微信风格的小气泡菜单：从指定锚点弹出，点菜单外任意处自动收回
@interface RSPopMenuView : UIView

/// anchorRect: 锚点在 hostView 坐标系中的矩形（菜单贴它的下方，箭头对准它的中心）
+ (instancetype)showInView:(UIView *)hostView
                anchorRect:(CGRect)anchorRect
                     items:(NSArray<NSDictionary *> *)items
                   handler:(void (^)(NSInteger index))handler;

- (void)dismiss;

@end

NS_ASSUME_NONNULL_END
