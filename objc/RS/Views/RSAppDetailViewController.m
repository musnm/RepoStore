#import "RSAppDetailViewController.h"
#import "RSStore.h"
#import "RSTheme.h"
#import "RSIconView.h"
#import "RSInstallService.h"
#import "RSTranslateService.h"

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

// 简介翻译
@property (nonatomic, strong) UILabel *descLabel;
@property (nonatomic, strong) UIButton *translateBtn;
@property (nonatomic, assign) BOOL showingTranslation;
@property (nonatomic, copy) NSString *translatedText;
@property (nonatomic, assign) BOOL translating;

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
    // 关键：scroll 已钉在 safeAreaLayoutGuide.top，若系统再自动加一次安全区 inset，
    // contentOffset 会被二次下推，滚到底后回弹 —— 这是"上滑弹回"的根因。
    self.scroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.scroll.contentInset = UIEdgeInsetsZero;
    self.scroll.scrollIndicatorInsets = UIEdgeInsetsZero;
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
