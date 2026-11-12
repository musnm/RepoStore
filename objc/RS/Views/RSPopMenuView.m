#import "RSPopMenuView.h"
#import "RSTheme.h"

NSString *const RSPopMenuItemKeyTitle  = @"title";
NSString *const RSPopMenuItemKeySymbol = @"symbol";

static const CGFloat kRowHeight   = 46.0;
static const CGFloat kMenuWidth   = 178.0;
static const CGFloat kCorner      = 13.0;
static const CGFloat kArrowHeight = 8.0;
static const CGFloat kArrowHalf   = 9.0;

@interface RSPopMenuView ()
@property (nonatomic, strong) UIView *backdrop;
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) CAShapeLayer *panelShape;
@property (nonatomic, copy)   NSArray<NSDictionary *> *items;
@property (nonatomic, copy)   void (^handler)(NSInteger);
@property (nonatomic, weak)   UIView *hostView;
@property (nonatomic, assign) CGRect anchorRect;
@property (nonatomic, assign) BOOL dismissing;
@end

@implementation RSPopMenuView

+ (instancetype)showInView:(UIView *)hostView
                anchorRect:(CGRect)anchorRect
                     items:(NSArray<NSDictionary *> *)items
                   handler:(void (^)(NSInteger))handler {
    RSPopMenuView *menu = [[RSPopMenuView alloc] initWithHost:hostView
                                                   anchorRect:anchorRect
                                                        items:items
                                                      handler:handler];
    [menu present];
    return menu;
}

- (instancetype)initWithHost:(UIView *)hostView
                  anchorRect:(CGRect)anchorRect
                       items:(NSArray<NSDictionary *> *)items
                     handler:(void (^)(NSInteger))handler {
    self = [super initWithFrame:hostView.bounds];
    if (!self) return nil;

    self.items = items;
    self.handler = handler;
    self.hostView = hostView;
    self.anchorRect = anchorRect;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.backgroundColor = [UIColor clearColor];

    // 遮罩：全屏近乎透明，点它即收回
    self.backdrop = [[UIView alloc] initWithFrame:self.bounds];
    self.backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.backdrop.backgroundColor = [UIColor colorWithWhite:0 alpha:0.01];
    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backdropTapped)];
    [self.backdrop addGestureRecognizer:tap];
    [self addSubview:self.backdrop];

    // 先按 hostView 坐标存下锚点，等 present 时换到 window 坐标再重算 panel，
    // 避免 self.view 与 window 原点不同导致菜单整体偏移（掉到屏幕下方）。
    self.anchorRect = anchorRect;
    CGFloat menuH = kRowHeight * (CGFloat)items.count + kArrowHeight;
    CGFloat hostW = CGRectGetWidth(hostView.bounds);
    CGFloat hostH = CGRectGetHeight(hostView.bounds);

    CGFloat anchorMidX = CGRectGetMidX(anchorRect);
    if (anchorMidX <= 0 || isnan(anchorMidX)) anchorMidX = hostW - 28;

    CGRect panelFrame;
    BOOL upward;
    if (CGRectGetMaxY(anchorRect) + menuH + 8 <= hostH) {
        upward = NO;
        panelFrame = CGRectMake(0, CGRectGetMaxY(anchorRect) + 6, kMenuWidth, menuH);
    } else {
        upward = YES;
        panelFrame = CGRectMake(0, CGRectGetMinY(anchorRect) - menuH - 6, kMenuWidth, menuH);
    }
    CGFloat x = anchorMidX - kMenuWidth + 42;
    if (x + kMenuWidth > hostW - 8) x = hostW - 8 - kMenuWidth;
    if (x < 8) x = 8;
    panelFrame.origin.x = x;
    if (panelFrame.origin.y < 8) panelFrame.origin.y = 8;

    self.panel = [[UIView alloc] initWithFrame:panelFrame];
    self.panel.backgroundColor = [UIColor clearColor];
    [self addSubview:self.panel];

    self.panelShape = [CAShapeLayer layer];
    self.panelShape.fillColor =
        [UIColor colorWithRed:0.16 green:0.16 blue:0.18 alpha:1.0].CGColor;
    self.panelShape.shadowColor = [UIColor blackColor].CGColor;
    self.panelShape.shadowOpacity = 0.4;
    self.panelShape.shadowRadius = 14;
    self.panelShape.shadowOffset = CGSizeMake(0, 6);
    self.panelShape.frame = self.panel.bounds;
    [self.panel.layer addSublayer:self.panelShape];

    [self buildRowsUpward:upward anchorMidX:anchorMidX];
    return self;
}

// 根据 window 坐标下的锚点重新摆放 panel（含箭头朝向）
- (void)drawBubbleUpward:(BOOL)upward anchorMidX:(CGFloat)anchorMidX {
    CGFloat W = kMenuWidth;
    CGFloat H = CGRectGetHeight(self.panel.bounds);
    CGFloat bodyTop = upward ? 0 : kArrowHeight;
    CGFloat bodyH = H - kArrowHeight;

    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:
        CGRectMake(0, bodyTop, W, bodyH) cornerRadius:kCorner];

    CGFloat ax = anchorMidX - CGRectGetMinX(self.panel.frame);
    ax = MAX(kCorner + kArrowHalf + 2, MIN(W - kCorner - kArrowHalf - 2, ax));

    UIBezierPath *arrow = [UIBezierPath bezierPath];
    if (upward) {
        CGFloat by = H - kArrowHeight;
        [arrow moveToPoint:CGPointMake(ax - kArrowHalf, by)];
        [arrow addLineToPoint:CGPointMake(ax, H)];
        [arrow addLineToPoint:CGPointMake(ax + kArrowHalf, by)];
    } else {
        CGFloat by = kArrowHeight;
        [arrow moveToPoint:CGPointMake(ax - kArrowHalf, by)];
        [arrow addLineToPoint:CGPointMake(ax, 0)];
        [arrow addLineToPoint:CGPointMake(ax + kArrowHalf, by)];
    }
    [arrow closePath];
    [path appendPath:arrow];
    self.panelShape.path = path.CGPath;
}

- (void)buildRowsUpward:(BOOL)upward anchorMidX:(CGFloat)anchorMidX {
    CGFloat W = kMenuWidth;
    CGFloat H = CGRectGetHeight(self.panel.bounds);
    CGFloat bodyTop = upward ? 0 : kArrowHeight;

    [self drawBubbleUpward:upward anchorMidX:anchorMidX];

    for (NSInteger i = 0; i < (NSInteger)self.items.count; i++) {
        NSDictionary *d = self.items[i];
        UIButton *row = [UIButton buttonWithType:UIButtonTypeCustom];
        row.frame = CGRectMake(0, bodyTop + i * kRowHeight, W, kRowHeight);
        row.tag = 100 + i;
        row.backgroundColor = [UIColor clearColor];

        NSString *symbol = d[RSPopMenuItemKeySymbol];
        UIImage *img = [UIImage systemImageNamed:symbol ?: @"circle"];
        UIImageView *iv = [[UIImageView alloc] initWithImage:img];
        iv.tintColor = [UIColor colorWithWhite:1 alpha:0.92];
        iv.contentMode = UIViewContentModeScaleAspectFit;
        iv.frame = CGRectMake(16, (kRowHeight - 20) / 2.0, 20, 20);
        iv.userInteractionEnabled = NO;
        [row addSubview:iv];

        UILabel *lb = [[UILabel alloc] initWithFrame:CGRectMake(48, 0, W - 62, kRowHeight)];
        lb.text = d[RSPopMenuItemKeyTitle];
        lb.textColor = [UIColor whiteColor];
        lb.font = [UIFont systemFontOfSize:15.5];
        lb.userInteractionEnabled = NO;
        [row addSubview:lb];

        [row addTarget:self action:@selector(rowTouchDown:) forControlEvents:UIControlEventTouchDown];
        [row addTarget:self action:@selector(rowTouchUp:)
      forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
        [row addTarget:self action:@selector(rowTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.panel addSubview:row];

        if (i < (NSInteger)self.items.count - 1) {
            UIView *line = [[UIView alloc] initWithFrame:
                CGRectMake(48, bodyTop + (i + 1) * kRowHeight - 0.5, W - 60, 0.5)];
            line.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
            line.userInteractionEnabled = NO;
            [self.panel addSubview:line];
        }
    }
}

#pragma mark - 展示 / 收回

- (void)present {
    if (!self.hostView) { [self removeFromSuperview]; return; }

    // 自检：panel 必须有可见尺寸，否则宁可不出菜单，也不能留一个全屏死遮罩
    // 把整个界面点成"没反应"。
    if (self.panel.frame.size.width < 1 || self.panel.frame.size.height < 1 ||
        isnan(self.panel.frame.origin.x) || isnan(self.panel.frame.origin.y)) {
        NSLog(@"[RSPopMenu] panel 尺寸异常，放弃弹出: %@", NSStringFromCGRect(self.panel.frame));
        [self removeFromSuperview];
        return;
    }

    // 挂到 window 层级，确保盖住导航栏和表格，不会被它们遮住
    UIView *container = self.hostView;
    UIWindow *win = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *sc in [UIApplication sharedApplication].connectedScenes) {
            if (![sc isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *w in ((UIWindowScene *)sc).windows) {
                if (w.isKeyWindow) { win = w; break; }
            }
            if (win) break;
        }
    }
    if (!win) win = self.hostView.window;
    if (win) container = win;

    self.frame = container.bounds;
    [container addSubview:self];

    // panel 的 frame 是相对 self 的，而 self 现在铺满 window，
    // 所以直接用 window 坐标重新摆一次，确保菜单紧贴导航栏下方。
    {
        CGRect a = self.anchorRect;
        if (self.hostView && self.hostView.window) {
            a = [self.hostView convertRect:a toView:container];
        }
        CGFloat menuH = kRowHeight * (CGFloat)self.items.count + kArrowHeight;
        CGFloat W = CGRectGetWidth(self.bounds);
        CGFloat H = CGRectGetHeight(self.bounds);

        BOOL up = (CGRectGetMaxY(a) + menuH + 8 > H);
        CGFloat y = up ? (CGRectGetMinY(a) - menuH - 6)
                       : (CGRectGetMaxY(a) + 6);
        if (y < 8) y = 8;

        CGFloat ax = CGRectGetMidX(a);
        CGFloat x = ax - kMenuWidth + 42;
        if (x + kMenuWidth > W - 8) x = W - 8 - kMenuWidth;
        if (x < 8) x = 8;

        self.panel.frame = CGRectMake(x, y, kMenuWidth, menuH);
        self.panelShape.frame = self.panel.bounds;
        [self drawBubbleUpward:up anchorMidX:ax];
    }

    self.panel.transform = CGAffineTransformMakeScale(0.9, 0.9);
    self.panel.alpha = 0;

    [UIView animateWithDuration:0.16
                          delay:0
         usingSpringWithDamping:0.85
          initialSpringVelocity:0.3
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.panel.transform = CGAffineTransformIdentity;
        self.panel.alpha = 1;
    } completion:nil];
}

- (void)dismiss {
    if (self.dismissing) return;
    self.dismissing = YES;
    self.panel.userInteractionEnabled = NO;
    [UIView animateWithDuration:0.12
                          delay:0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        self.panel.transform = CGAffineTransformMakeScale(0.92, 0.92);
        self.panel.alpha = 0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

- (void)backdropTapped { [self dismiss]; }

#pragma mark - 行交互

- (void)rowTouchDown:(UIButton *)btn {
    btn.backgroundColor = [UIColor colorWithWhite:1 alpha:0.09];
}
- (void)rowTouchUp:(UIButton *)btn {
    btn.backgroundColor = [UIColor clearColor];
}
- (void)rowTapped:(UIButton *)btn {
    btn.backgroundColor = [UIColor clearColor];
    NSInteger idx = btn.tag - 100;
    void (^h)(NSInteger) = self.handler;
    self.handler = nil;
    [self dismiss];
    if (h) {
        dispatch_async(dispatch_get_main_queue(), ^{ h(idx); });
    }
}

@end
