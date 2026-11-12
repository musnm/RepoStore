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
@property (nonatomic, strong) NSTimer *progressTimer;
@property (nonatomic, strong) UIButton *cancelBtn;
@property (nonatomic, strong) UIButton *pauseBtn;

// 操作卡片底边跟随：同一时刻只让一条生效，避免多条同锚点约束互相打架导致错位
@property (nonatomic, strong) NSLayoutConstraint *bottomFollowAction;
@property (nonatomic, strong) NSLayoutConstraint *bottomFollowPause;
@property (nonatomic, strong) NSLayoutConstraint *bottomFollowBar;
@property (nonatomic, strong) NSLayoutConstraint *bottomFollowTroll;

// 可折叠约束（隐藏时归零，让操作卡片真正收起）
@property (nonatomic, strong) NSLayoutConstraint *progressGap;
@property (nonatomic, strong) NSLayoutConstraint *progressHeight;
@property (nonatomic, strong) NSLayoutConstraint *barGap;
@property (nonatomic, strong) NSLayoutConstraint *barHeight;
@property (nonatomic, strong) NSLayoutConstraint *pauseGap;
@property (nonatomic, strong) NSLayoutConstraint *pauseHeight;
@property (nonatomic, strong) NSLayoutConstraint *trollGap;
@property (nonatomic, strong) NSLayoutConstraint *trollHeight;

/// 根据当前控件显隐，切换操作卡片底边约束。
/// 必须每次改完 hidden 都调用，否则卡片高度会和实际内容脱节 → 按钮互相遮挡 / 被简介压住。
- (void)syncActionCardHeight;
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
    [self restoreDownloadState];
}

/// 进入页面时恢复下载现场：已下载 → 显示分享按钮；下载中 → 显示进度并继续跟踪
- (void)restoreDownloadState {
    NSString *itemId = self.item.itemId;
    if (!itemId.length) return;

    // 公告 / 通知 / 无资源条目：不给下载
    if (!self.item.isDownloadable) {
        [self applyNonDownloadableUI];
        return;
    }

    // 已下载完成
    NSURL *done = [[RSStore shared] finishedURLForItem:self.item];
    if (!done) {
        for (RSDownloadRecord *r in [[RSStore shared] downloadRecords]) {
            if ([r.itemId isEqualToString:itemId] && r.finished && r.filePath.length) {
                done = [NSURL fileURLWithPath:r.filePath];
                break;
            }
        }
    }
    if (done) {
        self.downloadedURL = done;
        [self applyFinishedUI];
        return;
    }

    // 暂停功能已移除，忽略历史遗留的暂停状态，直接按进度恢复
    if ([[RSStore shared] isPausedItemId:itemId]) {
        [[RSStore shared] resumeDownloadForItemId:itemId];
    }

    // 正在下载
    double p = [[RSStore shared] currentProgressForItemId:itemId];
    if (p >= 0) {
        [self applyDownloadingUI];
        self.progressBar.progress = (float)p;
        self.progressLabel.text = [NSString stringWithFormat:@"%.0f%%", p * 100];
        [self startProgressTracking];
        return;
    }

    // 无下载任务（取消后 / 全新条目）：明确回到可下载初始态。
    // 原来这里什么都不做，界面停留在未初始化状态，才出现"此条目不可下载"的假象。
    [self applyIdleUI];
}

/// 可下载 · 初始态
- (void)applyIdleUI {
    self.actionBtn.enabled = YES;
    [self.actionBtn setTitle:@"  下载 IPA" forState:UIControlStateNormal];
    [self.actionBtn setImage:[UIImage systemImageNamed:@"arrow.down.circle.fill"]
                    forState:UIControlStateNormal];
    self.actionBtn.backgroundColor = [RSTheme accent];
    self.progressBar.hidden = YES;
    self.progressBar.progress = 0;
    self.progressLabel.hidden = YES;
    self.progressLabel.text = @"";
    self.trollBtn.hidden = YES;
    self.retryBtn.hidden = YES;
    self.cancelBtn.hidden = YES;
    self.pauseBtn.hidden = YES;
    [self syncActionCardHeight];
}

/// 已下载状态的外观
- (void)applyFinishedUI {
    self.actionBtn.enabled = YES;
    [self.actionBtn setTitle:@"  保存 / 分享 / 打开方式" forState:UIControlStateNormal];
    [self.actionBtn setImage:[UIImage systemImageNamed:@"square.and.arrow.up.fill"]
                    forState:UIControlStateNormal];
    self.actionBtn.backgroundColor = [RSTheme accent];
    self.progressBar.hidden = YES;
    self.progressLabel.hidden = NO;
    self.progressLabel.textColor = [RSTheme accent];
    self.progressLabel.text = @"✓ 下载完成";
    self.trollBtn.hidden = YES;
    self.retryBtn.hidden = YES;
    self.cancelBtn.hidden = YES;
    self.pauseBtn.hidden = YES;
    [self syncActionCardHeight];
}

/// 下载中状态的外观
- (void)applyDownloadingUI {
    self.actionBtn.enabled = NO;
    [self.actionBtn setTitle:@"  下载中…" forState:UIControlStateNormal];
    [self.actionBtn setImage:nil forState:UIControlStateNormal];
    self.actionBtn.backgroundColor = [RSTheme card2];
    self.progressBar.hidden = NO;
    self.progressLabel.hidden = NO;
    self.progressLabel.textColor = [RSTheme accent];
    self.trollBtn.hidden = YES;
    self.retryBtn.hidden = YES;
    // 暂停 / 取消下载已移除：续传从零开始无意义，统一到下载管理器处理
    self.cancelBtn.hidden = YES;
    self.pauseBtn.hidden = YES;
    [self syncActionCardHeight];
}

/// 公告 / 通知 / 无下载资源的条目外观
- (void)applyNonDownloadableUI {
    self.actionBtn.enabled = NO;
    [self.actionBtn setTitle:@"  此条目不可下载" forState:UIControlStateNormal];
    [self.actionBtn setImage:nil forState:UIControlStateNormal];
    self.actionBtn.backgroundColor = [RSTheme card2];
    self.progressBar.hidden = YES;
    self.progressLabel.hidden = NO;
    self.progressLabel.textColor = [RSTheme textSub];
    self.progressLabel.text = @"公告 / 通知";
    self.trollBtn.hidden = YES;
    self.retryBtn.hidden = YES;
    self.cancelBtn.hidden = YES;
    self.pauseBtn.hidden = YES;
    [self syncActionCardHeight];
}

/// 轮询进度（页面可能在下载开始后才进入）
- (void)startProgressTracking {
    [self.progressTimer invalidate];
    __weak typeof(self) weakSelf = self;
    self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.3 repeats:YES block:^(NSTimer *t) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) { [t invalidate]; return; }
        NSString *itemId = self.item.itemId;

        // 暂停功能已移除：不再在此切暂停外观

        double p = [[RSStore shared] currentProgressForItemId:itemId];
        if (p >= 0) {
            self.progressBar.progress = (float)p;
            self.progressLabel.text = [NSString stringWithFormat:@"%.0f%%", p * 100];
            return;
        }
        // 下载已结束（成功或失败）
        [t invalidate];
        self.progressTimer = nil;
        NSURL *done = [[RSStore shared] finishedURLForItem:self.item];
        if (!done) {
            for (RSDownloadRecord *r in [[RSStore shared] downloadRecords]) {
                if ([r.itemId isEqualToString:itemId] && r.finished && r.filePath.length) {
                    done = [NSURL fileURLWithPath:r.filePath];
                    break;
                }
            }
        }
        if (done) {
            self.downloadedURL = done;
            [self applyFinishedUI];
        } else {
            [self.actionBtn setTitle:@"  重试下载" forState:UIControlStateNormal];
            self.actionBtn.enabled = YES;
            self.actionBtn.backgroundColor = [RSTheme accent];
            self.progressLabel.text = @"下载失败";
            self.progressLabel.textColor = [UIColor colorWithRed:1 green:0.3 blue:0.3 alpha:1];
            self.progressBar.hidden = YES;
        }
    }];
}

- (void)dealloc {
    [_progressTimer invalidate];
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
    [self.actionBtn addTarget:self action:@selector(actionTapped) forControlEvents:UIControlEventTouchUpInside];

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

    // 取消下载
    self.cancelBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.cancelBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.cancelBtn setTitle:@"  取消下载" forState:UIControlStateNormal];
    [self.cancelBtn setImage:[UIImage systemImageNamed:@"xmark.circle"] forState:UIControlStateNormal];
    [self.cancelBtn setTitleColor:[UIColor colorWithRed:1 green:0.35 blue:0.35 alpha:1]
                         forState:UIControlStateNormal];
    self.cancelBtn.tintColor = [UIColor colorWithRed:1 green:0.35 blue:0.35 alpha:1];
    self.cancelBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    self.cancelBtn.backgroundColor = [RSTheme card2];
    self.cancelBtn.layer.cornerRadius = 13;
    self.cancelBtn.hidden = YES;

    // 暂停 / 继续
    self.pauseBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.pauseBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.pauseBtn setTitle:@"  暂停" forState:UIControlStateNormal];
    [self.pauseBtn setImage:[UIImage systemImageNamed:@"pause.circle"] forState:UIControlStateNormal];
    [self.pauseBtn setTitleColor:[RSTheme accent] forState:UIControlStateNormal];
    self.pauseBtn.tintColor = [RSTheme accent];
    self.pauseBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    self.pauseBtn.backgroundColor = [RSTheme card2];
    self.pauseBtn.layer.cornerRadius = 13;
    self.pauseBtn.hidden = YES;

    for (UIView *v in @[self.actionBtn, self.progressBar, self.progressLabel,
                        self.trollBtn, self.retryBtn, self.cancelBtn, self.pauseBtn]) {
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
        k.numberOfLines = 1;
        // 左侧 key 必须优先完整显示，否则会被右侧长值挤成 0 宽 → 文本溢出卡片
        [k setContentCompressionResistancePriority:UILayoutPriorityRequired
                                           forAxis:UILayoutConstraintAxisHorizontal];
        [k setContentHuggingPriority:UILayoutPriorityRequired
                              forAxis:UILayoutConstraintAxisHorizontal];

        UILabel *v = [UILabel new];
        v.translatesAutoresizingMaskIntoConstraints = NO;
        v.text = rows[i][1];
        v.font = [UIFont systemFontOfSize:12];
        v.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.85];
        v.textAlignment = NSTextAlignmentRight;
        v.numberOfLines = 1;
        v.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [v setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                           forAxis:UILayoutConstraintAxisHorizontal];

        [row addSubview:k];
        [row addSubview:v];
        [infoCard addSubview:row];

        [constraints addObjectsFromArray:@[
            [k.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
            [k.topAnchor constraintEqualToAnchor:row.topAnchor],
            [k.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
            [v.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
            [v.topAnchor constraintEqualToAnchor:row.topAnchor],
            [v.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
            [v.leadingAnchor constraintGreaterThanOrEqualToAnchor:k.trailingAnchor constant:12],
            [row.heightAnchor constraintGreaterThanOrEqualToConstant:22],
            // 关键：row 必须横向钉在 infoCard 内，否则宽度为 0 → 标签画到卡片外面
            [row.leadingAnchor constraintEqualToAnchor:infoCard.leadingAnchor constant:14],
            [row.trailingAnchor constraintEqualToAnchor:infoCard.trailingAnchor constant:-14],
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

    UILayoutGuide *g = self.scroll.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [content.topAnchor constraintEqualToAnchor:self.scroll.topAnchor],
        [content.leadingAnchor constraintEqualToAnchor:self.scroll.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:self.scroll.trailingAnchor],
        // 注意：不在这里钉 content.bottom = scroll.bottom，
        // 否则和下方 "content.bottom = infoCard.bottom + 30" 冲突，导致内容被压缩。
        // content 高度完全由内部内容链决定（608 行那条）。
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

        // ── 操作卡片内部：一条从上到下的唯一垂直流，每个控件都有明确的上一环
        // 1) 主按钮
        [self.actionBtn.topAnchor constraintEqualToAnchor:actionCard.topAnchor constant:14],
        [self.actionBtn.leadingAnchor constraintEqualToAnchor:actionCard.leadingAnchor constant:14],
        [self.actionBtn.trailingAnchor constraintEqualToAnchor:actionCard.trailingAnchor constant:-14],
        [self.actionBtn.heightAnchor constraintEqualToConstant:50],

        // 2) 进度文字（仅下载中显示）
        [self.progressLabel.leadingAnchor constraintEqualToAnchor:actionCard.leadingAnchor constant:18],
        [self.progressLabel.trailingAnchor constraintEqualToAnchor:actionCard.trailingAnchor constant:-18],

        // 3) 进度条
        [self.progressBar.leadingAnchor constraintEqualToAnchor:actionCard.leadingAnchor constant:18],
        [self.progressBar.trailingAnchor constraintEqualToAnchor:actionCard.trailingAnchor constant:-18],

        // 4) 暂停 / 取消：并排
        [self.pauseBtn.leadingAnchor constraintEqualToAnchor:actionCard.leadingAnchor constant:14],

        [self.cancelBtn.topAnchor constraintEqualToAnchor:self.pauseBtn.topAnchor],
        [self.cancelBtn.leadingAnchor constraintEqualToAnchor:self.pauseBtn.trailingAnchor constant:10],
        [self.cancelBtn.trailingAnchor constraintEqualToAnchor:actionCard.trailingAnchor constant:-14],
        [self.cancelBtn.widthAnchor constraintEqualToAnchor:self.pauseBtn.widthAnchor],
        [self.cancelBtn.heightAnchor constraintEqualToConstant:42],

        // 5) TrollStore / 重新下载：并排
        [self.trollBtn.leadingAnchor constraintEqualToAnchor:actionCard.leadingAnchor constant:14],

        [self.retryBtn.topAnchor constraintEqualToAnchor:self.trollBtn.topAnchor],
        [self.retryBtn.leadingAnchor constraintEqualToAnchor:self.trollBtn.trailingAnchor constant:10],
        [self.retryBtn.trailingAnchor constraintEqualToAnchor:actionCard.trailingAnchor constant:-14],
        [self.retryBtn.widthAnchor constraintEqualToAnchor:self.trollBtn.widthAnchor],
        [self.retryBtn.heightAnchor constraintEqualToConstant:42],
    ]];

    // ── 三级"可折叠"约束：隐藏时高度/间距归零，让卡片真正收起来。
    //    之前隐藏视图仍占位，且卡片底边只挂主按钮 → 隐藏控件溢出卡片、互相遮挡。
    self.progressGap   = [self.progressLabel.topAnchor
                          constraintEqualToAnchor:self.actionBtn.bottomAnchor constant:10];
    self.progressHeight= [self.progressLabel.heightAnchor constraintEqualToConstant:16];
    self.barGap        = [self.progressBar.topAnchor
                          constraintEqualToAnchor:self.progressLabel.bottomAnchor constant:8];
    self.barHeight     = [self.progressBar.heightAnchor constraintEqualToConstant:6];
    self.pauseGap      = [self.pauseBtn.topAnchor
                          constraintEqualToAnchor:self.progressBar.bottomAnchor constant:12];
    self.pauseHeight   = [self.pauseBtn.heightAnchor constraintEqualToConstant:42];
    self.trollGap      = [self.trollBtn.topAnchor
                          constraintEqualToAnchor:self.pauseBtn.bottomAnchor constant:10];
    self.trollHeight   = [self.trollBtn.heightAnchor constraintEqualToConstant:42];
    [NSLayoutConstraint activateConstraints:@[
        self.progressGap, self.progressHeight,
        self.barGap, self.barHeight,
        self.pauseGap, self.pauseHeight,
        self.trollGap, self.trollHeight,
    ]];

    // ── 卡片底边：按"最后一行可见控件"决定，用运行时动态切换整组约束，
    // 而不是同时挂多条同锚点约束互相打架（那是之前错位的根因）。
    self.bottomFollowAction = [actionCard.bottomAnchor
        constraintEqualToAnchor:self.actionBtn.bottomAnchor constant:14];
    self.bottomFollowPause = [actionCard.bottomAnchor
        constraintEqualToAnchor:self.pauseBtn.bottomAnchor constant:14];
    self.bottomFollowBar = [actionCard.bottomAnchor
        constraintEqualToAnchor:self.progressBar.bottomAnchor constant:14];
    self.bottomFollowTroll = [actionCard.bottomAnchor
        constraintEqualToAnchor:self.trollBtn.bottomAnchor constant:14];
    // 默认：只有主按钮
    self.bottomFollowAction.active = YES;
    self.bottomFollowPause.active = NO;
    self.bottomFollowBar.active = NO;
    self.bottomFollowTroll.active = NO;

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
        [content.bottomAnchor constraintEqualToAnchor:infoCard.bottomAnchor constant:30],
    ]];
}

#pragma mark - 下载

/// 主按钮：未下载→下载；已下载→分享；下载中→暂停
- (void)actionTapped {
    if (self.item.isDownloadable == NO) return;

    NSURL *done = [[RSStore shared] finishedURLForItem:self.item];
    if (done) {
        [RSInstallService shareFile:done from:self];
        return;
    }
    if ([[RSStore shared] isDownloadingItemId:self.item.itemId]) {
        return;
    }
    [self downloadTapped];
}

/// 发起下载
- (void)downloadTapped {
    if (self.item.isDownloadable == NO) return;

    [self applyDownloadingUI];
    __weak typeof(self) weakSelf = self;
    [[RSStore shared] downloadItem:self.item
                          progress:^(double p) {
        __strong typeof(weakSelf) s = weakSelf;
        if (!s) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            s.progressBar.progress = (float)p;
            s.progressLabel.text = [NSString stringWithFormat:@"%.0f%%", p * 100];
        });
    }
                        completion:^(NSURL *fileURL, NSString *error) {
        __strong typeof(weakSelf) s = weakSelf;
        if (!s) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (fileURL) {
                s.downloadedURL = fileURL;
                [s applyFinishedUI];
            } else {
                [RSInstallService toast:(error.length ? error : @"下载失败") in:s];
                [s applyNonDownloadableUI];
            }
        });
    }];
}

/// 安全兜底（按钮已隐藏，不会触发；保留避免 unrecognized selector）
- (void)trollTapped {}

- (void)syncActionCardHeight {
    BOOL barOn   = !self.progressBar.hidden;
    BOOL pauseOn = !self.pauseBtn.hidden;
    BOOL trollOn = NO;   // Troll/重试行已移除

    // 1) 进度文字 / 进度条：不可见就整段折掉，不留空高
    self.progressGap.constant    = barOn ? 10 : 0;
    self.progressHeight.constant = barOn ? 16 : 0;
    self.barGap.constant         = barOn ? 8  : 0;
    self.barHeight.constant      = barOn ? 6  : 0;

    // 2) 暂停/取消行
    self.pauseGap.constant    = pauseOn ? 12 : 0;
    self.pauseHeight.constant = pauseOn ? 42 : 0;

    // 3) Troll/重试行：已移除，永久折叠
    self.trollGap.constant    = 0;
    self.trollHeight.constant = 0;

    // 4) 卡片底边跟随最后一个可见行（只激活一条，避免多约束打架）
    self.bottomFollowAction.active = NO;
    self.bottomFollowPause.active  = NO;
    self.bottomFollowBar.active    = NO;
    self.bottomFollowTroll.active  = NO;

    if (trollOn) {
        self.bottomFollowTroll.active = YES;
    } else if (pauseOn) {
        self.bottomFollowPause.active = YES;
    } else if (barOn) {
        self.bottomFollowBar.active = YES;
    } else {
        self.bottomFollowAction.active = YES;
    }

    [UIView animateWithDuration:0.22 animations:^{
        [self.view layoutIfNeeded];
    }];
}

@end
