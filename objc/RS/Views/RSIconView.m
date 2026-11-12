#import "RSIconView.h"
#import "RSTheme.h"

@interface RSIconView ()
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UILabel *letterLabel;
@property (nonatomic, strong) CAGradientLayer *gradient;
@property (nonatomic, copy) NSString *currentURL;
@end

@implementation RSIconView

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.clipsToBounds = YES;
        self.layer.cornerCurve = kCACornerCurveContinuous;

        _gradient = [CAGradientLayer layer];
        _gradient.frame = self.bounds;
        [self.layer addSublayer:_gradient];

        _letterLabel = [UILabel new];
        _letterLabel.textAlignment = NSTextAlignmentCenter;
        _letterLabel.textColor = [UIColor whiteColor];
        _letterLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
        [self addSubview:_letterLabel];

        _imageView = [UIImageView new];
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;
        [self addSubview:_imageView];

        self.layer.borderWidth = 1.0;
        self.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12].CGColor;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.cornerRadius = self.bounds.size.width * 0.22;
    _gradient.frame = self.bounds;
    _gradient.cornerRadius = self.layer.cornerRadius;
    _imageView.frame = self.bounds;
    _imageView.layer.cornerRadius = self.layer.cornerRadius;
    _letterLabel.frame = self.bounds;
    _letterLabel.font = [UIFont systemFontOfSize:self.bounds.size.width * 0.42
                                          weight:UIFontWeightBold];
}

- (void)configureWithURL:(NSString *)urlString
                    seed:(NSString *)seed
            cornerRadius:(CGFloat)corner {
    // 渐变兜底
    NSArray<UIColor *> *pal = [RSTheme paletteForSeed:(seed.length ? seed : @"?")];
    _gradient.colors = @[(id)pal[0].CGColor, (id)pal[1].CGColor];

    NSString *initial = seed.length > 0
        ? [[seed substringToIndex:1] uppercaseString]
        : @"?";
    _letterLabel.text = initial;

    _imageView.image = nil;
    _imageView.hidden = YES;
    _currentURL = [urlString copy];

    if (urlString.length == 0) return;
    NSURL *u = [NSURL URLWithString:urlString];
    if (!u) return;

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *t =
    [[NSURLSession sharedSession] dataTaskWithURL:u
                                completionHandler:^(NSData *data, NSURLResponse *resp, NSError *error) {
        if (!data || error) return;
        UIImage *img = [UIImage imageWithData:data];
        if (!img) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            if (![self.currentURL isEqualToString:urlString]) return;
            self.imageView.image = img;
            self.imageView.hidden = NO;
        });
    }];
    [t resume];
}

@end
