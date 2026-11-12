#import "RSAppDetailViewController.h"
#import "RSStore.h"
#import "RSTheme.h"
#import "RSIconView.h"
#import "RSInstallService.h"

@interface RSAppDetailViewController ()
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIButton *actionBtn;
@property (nonatomic, strong) UIProgressView *progressBar;
@property (nonatomic, strong) UILabel *progressLabel;
@property (nonatomic, strong) UIButton *trollBtn;
@property (nonatomic, strong) UIButton *retryBtn;
@property (nonatomic, strong) NSURL *downloadedURL;
@end

@implementation RSAppDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [RSTheme bg];
    self.title = self.item.name;

    self.scroll = [UIScrollView new];
    self.scroll.translatesAutoresizingMaskIntoConstraints = NO;
    self.scroll.alwaysBounceVertical = YES;
    [self.view addSubview:self.scroll];
    [NSLayoutConstraint activateConstraints:@[
        [self.scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    [self buildUI];
}

- (UIView *)cardContainer {
    UIView *v = [UIView new];
    v.translatesAutoresizingMaskIntoConstraints = NO;
    v.backgroundColor = [RSTheme card];
    v.layer.cornerRadius = 20;
    v.layer.cornerCurve = kCACornerCurveContinuous;
    v.layer.borderWidth = 1.0;
    v.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.06].CGColor;
    return v;
}

- (void)buildUI {
    UIView *content = [UIView new];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scroll addSubview:content];

    // ── 头部
    RSIconView *icon = [RSIconView new];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [icon configureWithURL:self.item.iconURL seed:self.item.name cornerRadius:22];

    UILabel *name = [UILabel new];
    name.translatesAutoresizingMaskIntoConstraints = NO;
    name.text = self.item.name;
    name.font = [UIFont systemFontOfSize:21 weight:UIFontWeightBold];
    name.textColor = [UIColor whiteColor];
    name.textAlignment = NSTextAlignmentCenter;
    name.numberOfLines = 2;

    UILabel *dev = [UILabel new];
    dev.translatesAutoresizingMaskIntoConstraints = NO;
    dev.text = self.item.developerName;
    dev.font = [UIFont systemFontOfSize:13];
    dev.textColor = [RSTheme textSub];
    dev.textAlignment = NSTextAlignmentCenter;

    // ── 操作卡片
    UIView *actionCard = [self cardContainer];

    self.actionBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.actionBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.actionBtn setTitle:@"  下载 IPA" forState:UIControlStateNormal];
    [self.actionBtn setImage:[UIImage systemImageNamed:@"arrow.down.circle.fill"] forState:UIControlStateNormal];
    [self.actionBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.actionBtn.tintColor = [UIColor whiteColor];
    self.actionBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.actionBtn.backgroundColor = [RSTheme accent];
    self.actionBtn.layer.cornerRadius = 15;
    [self.actionBtn addTarget:self action:@selector(downloadTapped) forControlEvents:UIControlEventTouchUpInside];

    self.progressBar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressBar.progressTintColor = [RSTheme accent];
    self.progressBar.trackTintColor = [RSTheme card2];
    self.progressBar.layer.cornerRadius = 3;
    self.progressBar.clipsToBounds = YES;
    self.progressBar.hidden = YES;

    self.progressLabel = [UILabel new];
    self.progressLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightBold];
    self.progressLabel.textColor = [RSTheme accent];
    self.progressLabel.textAlignment = NSTextAlignmentCenter;
    self.progressLabel.text = @"0%";
    self.progressLabel.hidden = YES;

    self.trollBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.trollBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.trollBtn setTitle:@"  TrollStore 安装" forState:UIControlStateNormal];
    [self.trollBtn setImage:[UIImage systemImageNamed:@"bolt.fill"] forState:UIControlStateNormal];
    [self.trollBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.trollBtn.tintColor = [UIColor whiteColor];
    self.trollBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    self.trollBtn.backgroundColor = [RSTheme card2];
    self.trollBtn.layer.cornerRadius = 13;
    self.trollBtn.hidden = YES;
    [self.trollBtn addTarget:self action:@selector(trollTapped) forControlEvents:UIControlEventTouchUpInside];

    self.retryBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.retryBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.retryBtn setTitle:@"  重新下载" forState:UIControlStateNormal];
    [self.retryBtn setImage:[UIImage systemImageNamed:@"arrow.clockwise"] forState:UIControlStateNormal];
    [self.retryBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.retryBtn.tintColor = [UIColor whiteColor];
    self.retryBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    self.retryBtn.backgroundColor = [RSTheme card2];
    self.retryBtn.layer.cornerRadius = 13;
    self.retryBtn.hidden = YES;
    [self.retryBtn addTarget:self action:@selector(downloadTapped) forControlEvents:UIControlEventTouchUpInside];

    for (UIView *v in @[self.actionBtn, self.progressBar, self.progressLabel,
                        self.trollBtn, self.retryBtn]) {
        [actionCard addSubview:v];
    }

    // ── 描述卡片
    UIView *descCard = nil;
    UILabel *descLabel = nil;
    if (self.item.localizedDescription.length > 0) {
        descCard = [self cardContainer];
        UILabel *dt = [UILabel new];
        dt.translatesAutoresizingMaskIntoConstraints = NO;
        dt.text = @"简介";
        dt.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        dt.textColor = [RSTheme textSub];
        [descCard addSubview:dt];

        descLabel = [UILabel new];
        descLabel.translatesAutoresizingMaskIntoConstraints = NO;
        descLabel.text = self.item.localizedDescription;
        descLabel.font = [UIFont systemFontOfSize:14];
        descLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.9];
        descLabel.numberOfLines = 0;
        [descCard addSubview:descLabel];

        [NSLayoutConstraint activateConstraints:@[
            [dt.topAnchor constraintEqualToAnchor:descCard.topAnchor constant:16],
            [dt.leadingAnchor constraintEqualToAnchor:descCard.leadingAnchor constant:16],
            [descLabel.topAnchor constraintEqualToAnchor:dt.bottomAnchor constant:8],
            [descLabel.leadingAnchor constraintEqualToAnchor:descCard.leadingAnchor constant:16],
            [descLabel.trailingAnchor constraintEqualToAnchor:descCard.trailingAnchor constant:-16],
            [descLabel.bottomAnchor constraintEqualToAnchor:descCard.bottomAnchor constant:-16],
        ]];
    }

    // ── 信息卡片
    UIView *infoCard = [self cardContainer];
    NSMutableArray *rows = [NSMutableArray array];
    [rows addObject:@[@"Bundle ID", self.item.bundleIdentifier]];
    if (self.item.version.length) [rows addObject:@[@"版本", self.item.version]];
    if (self.item.sizeText.length) [rows addObject:@[@"大小", self.item.sizeText]];
    if (self.item.categoryName.length) [rows addObject:@[@"分类", self.item.categoryName]];
    [rows addObject:@[@"下载地址", self.item.downloadURL]];

    UIView *prev = nil;
    NSMutableArray *constraints = [NSMutableArray array];
    for (NSUInteger i = 0; i < rows.count; i++) {
        UIView *row = [UIView new];
        row.translatesAutoresizingMaskIntoConstraints = NO;

        UILabel *k = [UILabel new];
        k.translatesAutoresizingMaskIntoConstraints = NO;
        k.text = rows[i][0];
        k.font = [UIFont systemFontOfSize:13];
        k.textColor = [RSTheme textSub];

        UILabel *v = [UILabel new];
        v.translatesAutoresizingMaskIntoConstraints = NO;
        v.text = rows[i][1];
        v.font = [UIFont systemFontOfSize:12];
        v.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.85];
        v.textAlignment = NSTextAlignmentRight;
        v.lineBreakMode = NSLineBreakByTruncatingMiddle;

        [row addSubview:k];
        [row addSubview:v];
        [infoCard addSubview:row];

        [constraints addObjectsFromArray:@[
            [k.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
            [k.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
            [v.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
            [v.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
            [v.leadingAnchor constraintGreaterThanOrEqualToAnchor:k.trailingAnchor constant:12],
        ]];

        if (prev == nil) {
            [constraints addObject:[row.topAnchor constraintEqualToAnchor:infoCard.topAnchor constant:13]];
        } else {
            [constraints addObject:[row.topAnchor constraintEqualToAnchor:prev.bottomAnchor constant:13]];
            UIView *line = [UIView new];
            line.translatesAutoresizingMaskIntoConstraints = NO;
            line.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.06];
            [infoCard addSubview:line];
            [constraints addObjectsFromArray:@[
                [line.topAnchor constraintEqualToAnchor:prev.bottomAnchor],
                [line.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
                [line.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
                [line.heightAnchor constraintEqualToConstant:0.5],
            ]];
        }
        prev = row;
    }
    [constraints addObject:[prev.bottomAnchor constraintEqualToAnchor:infoCard.bottomAnchor constant:-13]];

    // ── 组装
    NSMutableArray *all = [NSMutableArray arrayWithArray:@[icon, name, dev, actionCard]];
    if (descCard) [all addObject:descCard];
    [all addObject:infoCard];
    for (UIView *v in all) [content addSubview:v];

    [NSLayoutConstraint activateConstraints:@[
        [content.topAnchor constraintEqualToAnchor:self.scroll.topAnchor],
        [content.leadingAnchor constraintEqualToAnchor:self.scroll.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:self.scroll.trailingAnchor],
        [content.bottomAnchor constraintEqualToAnchor:self.scroll.bottomAnchor],
        [content.widthAnchor constraintEqualToAnchor:self.scroll.widthAnchor],

        [icon.topAnchor constraintEqualToAnchor:content.topAnchor constant:14],
        [icon.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
        [icon.widthAnchor constraintEqualToConstant:92],
        [icon.heightAnchor constraintEqualToConstant:92],

        [name.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:13],
        [name.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:24],
        [name.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-24],

        [dev.topAnchor constraintEqualToAnchor:name.bottomAnchor constant:4],
        [dev.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:24],
        [dev.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-24],

        [actionCard.topAnchor constraintEqualToAnchor:dev.bottomAnchor constant:18],
        [actionCard.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [actionCard.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],

        [self.actionBtn.topAnchor constraintEqualToAnchor:actionCard.topAnchor constant:14],
        [self.actionBtn.leadingAnchor constraintEqualToAnchor:actionCard.leadingAnchor constant:14],
        [self.actionBtn.trailingAnchor constraintEqualToAnchor:actionCard.trailingAnchor constant:-14],
        [self.actionBtn.heightAnchor constraintEqualToConstant:50],

        [self.progressLabel.topAnchor constraintEqualToAnchor:actionCard.topAnchor constant:24],
        [self.progressLabel.centerXAnchor constraintEqualToAnchor:actionCard.centerXAnchor],

        [self.progressBar.topAnchor constraintEqualToAnchor:self.progressLabel.bottomAnchor constant:8],
        [self.progressBar.leadingAnchor constraintEqualToAnchor:actionCard.leadingAnchor constant:18],
        [self.progressBar.trailingAnchor constraintEqualToAnchor:actionCard.trailingAnchor constant:-18],
        [self.progressBar.heightAnchor constraintEqualToConstant:6],

        [self.trollBtn.topAnchor constraintEqualToAnchor:self.actionBtn.bottomAnchor constant:10],
        [self.trollBtn.leadingAnchor constraintEqualToAnchor:actionCard.leadingAnchor constant:14],
        [self.trollBtn.heightAnchor constraintEqualToConstant:42],

        [self.retryBtn.topAnchor constraintEqualToAnchor:self.actionBtn.bottomAnchor constant:10],
        [self.retryBtn.leadingAnchor constraintEqualToAnchor:self.trollBtn.trailingAnchor constant:10],
        [self.retryBtn.trailingAnchor constraintEqualToAnchor:actionCard.trailingAnchor constant:-14],
        [self.retryBtn.widthAnchor constraintEqualToAnchor:self.trollBtn.widthAnchor],
        [self.retryBtn.heightAnchor constraintEqualToConstant:42],

        [actionCard.bottomAnchor constraintEqualToAnchor:self.actionBtn.bottomAnchor constant:14],
    ]];
    [NSLayoutConstraint activateConstraints:constraints];

    UIView *lastBefore = actionCard;
    if (descCard) {
        [NSLayoutConstraint activateConstraints:@[
            [descCard.topAnchor constraintEqualToAnchor:actionCard.bottomAnchor constant:12],
            [descCard.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
            [descCard.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
        ]];
        lastBefore = descCard;
    }
    [NSLayoutConstraint activateConstraints:@[
        [infoCard.topAnchor constraintEqualToAnchor:lastBefore.bottomAnchor constant:12],
        [infoCard.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [infoCard.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
        [content.bottomAnchor constraintGreaterThanOrEqualToAnchor:infoCard.bottomAnchor constant:30],
    ]];
}

#pragma mark - 下载

- (void)downloadTapped {
    self.actionBtn.enabled = NO;
    [self.actionBtn setTitle:@"  下载中…" forState:UIControlStateNormal];
    self.actionBtn.backgroundColor = [RSTheme card2];
    self.progressBar.hidden = NO;
    self.progressLabel.hidden = NO;
    self.progressBar.progress = 0;
    self.progressLabel.text = @"0%";
    self.trollBtn.hidden = YES;
    self.retryBtn.hidden = YES;

    __weak typeof(self) weakSelf = self;
    [[RSStore shared] downloadItem:self.item
                          progress:^(double p) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            self.progressBar.progress = (float)p;
            self.progressLabel.text = [NSString stringWithFormat:@"%.0f%%", p * 100];
        });
    } completion:^(NSURL *url, NSString *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            self.actionBtn.enabled = YES;

            if (url) {
                self.downloadedURL = url;
                [self.actionBtn setTitle:@"  保存 / 分享 / 打开方式" forState:UIControlStateNormal];
                [self.actionBtn setImage:[UIImage systemImageNamed:@"square.and.arrow.up.fill"]
                                forState:UIControlStateNormal];
                self.actionBtn.backgroundColor = [RSTheme accent];
                self.progressBar.hidden = YES;
                self.progressLabel.text = @"✓ 下载完成";
                self.trollBtn.hidden = NO;
                self.retryBtn.hidden = NO;

                UINotificationFeedbackGenerator *fb = [UINotificationFeedbackGenerator new];
                [fb notificationOccurred:UINotificationFeedbackTypeSuccess];

                [RSInstallService shareFile:url from:self];
            } else {
                [self.actionBtn setTitle:@"  重试下载" forState:UIControlStateNormal];
                self.actionBtn.backgroundColor = [RSTheme accent];
                self.progressLabel.text = @"下载失败";
                self.progressLabel.textColor = [UIColor colorWithRed:1 green:0.3 blue:0.3 alpha:1];
                [RSInstallService toast:(error.length ? error : @"下载失败") in:self];
            }
        });
    }];
}

- (void)trollTapped {
    if (!self.downloadedURL) return;
    if (![RSInstallService trollStoreInstall:self.downloadedURL]) {
        [RSInstallService shareFile:self.downloadedURL from:self];
    }
}

@end
