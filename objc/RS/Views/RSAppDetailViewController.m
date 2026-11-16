#import "RSAppDetailViewController.h"
#import "RSTheme.h"
#import "RSIconView.h"
#import "RSStore.h"
#import "RSInstallService.h"
#import "RSTranslateService.h"

@interface RSAppDetailViewController ()
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) RSIconView *iconView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *devLabel;
@property (nonatomic, strong) UILabel *metaLabel;
@property (nonatomic, strong) UILabel *descLabel;
@property (nonatomic, strong) UIButton *actionBtn;
@property (nonatomic, strong) UIProgressView *progressBar;
@property (nonatomic, strong) UILabel *progressLabel;
@property (nonatomic, strong) UIButton *translateBtn;
@property (nonatomic, strong) UILabel *infoHeader;
@property (nonatomic, strong) UIView *infoCard;
@property (nonatomic, strong) UILabel *infoBody;
@property (nonatomic, strong) UIView *versionRow;
@property (nonatomic, strong) UILabel *versionValue;
@property (nonatomic, strong) UILabel *sizeValue;
@property (nonatomic, strong) UILabel *dateValue;
@property (nonatomic, strong) UILabel *idValue;
@property (nonatomic, strong) UILabel *archValue;
@property (nonatomic, assign) BOOL showingTranslation;

/// 用户是否在「版本」行手动选过版本。
/// YES 时点下载就直接下，不再弹确认（他已经明确选了）；
/// NO 时点下载才需要弹一次，让他知道还有别的架构可选。
@property (nonatomic, assign) BOOL userPickedVersion;
@property (nonatomic, copy) NSString *translatedText;
@end

@implementation RSAppDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [RSTheme bg];
    self.title = self.item.name;

    self.scroll = [[UIScrollView alloc] initWithFrame:CGRectZero];
    self.scroll.translatesAutoresizingMaskIntoConstraints = NO;
    self.scroll.backgroundColor = [RSTheme bg];
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

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onDownloadsChanged)
                                                 name:RSDownloadsChangedNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)onDownloadsChanged {
    [self restoreDownloadState];
}

#pragma mark - 构建界面

- (void)buildUI {
    UIView *root = self.scroll;
    CGFloat W = self.view.bounds.size.width;
    if (W <= 0) W = UIScreen.mainScreen.bounds.size.width;

    // ── 顶部大图标 + 名称 + 开发者
    self.iconView = [RSIconView new];
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.iconView configureWithURL:self.item.iconURL seed:self.item.name cornerRadius:22];
    [root addSubview:self.iconView];

    self.nameLabel = [UILabel new];
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.nameLabel.text = self.item.name;
    self.nameLabel.font = [UIFont systemFontOfSize:21 weight:UIFontWeightBold];
    self.nameLabel.textColor = [UIColor whiteColor];
    self.nameLabel.textAlignment = NSTextAlignmentCenter;
    self.nameLabel.numberOfLines = 2;
    [root addSubview:self.nameLabel];

    self.devLabel = [UILabel new];
    self.devLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.devLabel.text = self.item.developerName.length ? self.item.developerName : @"";
    self.devLabel.font = [UIFont systemFontOfSize:13];
    self.devLabel.textColor = [RSTheme textSub];
    self.devLabel.textAlignment = NSTextAlignmentCenter;
    [root addSubview:self.devLabel];

    self.metaLabel = [UILabel new];
    self.metaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.metaLabel.font = [UIFont systemFontOfSize:12];
    self.metaLabel.textColor = [RSTheme textSub];
    self.metaLabel.textAlignment = NSTextAlignmentCenter;
    self.metaLabel.numberOfLines = 0;
    [root addSubview:self.metaLabel];

    // ── 下载按钮
    self.actionBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.actionBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.actionBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.actionBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.actionBtn.tintColor = [UIColor whiteColor];
    self.actionBtn.backgroundColor = [RSTheme accent];
    self.actionBtn.layer.cornerRadius = 14;
    self.actionBtn.layer.cornerCurve = kCACornerCurveContinuous;
    [self.actionBtn addTarget:self action:@selector(actionTapped) forControlEvents:UIControlEventTouchUpInside];
    [root addSubview:self.actionBtn];

    self.progressBar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressBar.progressTintColor = [RSTheme accent];
    self.progressBar.trackTintColor = [RSTheme card2];
    self.progressBar.layer.cornerRadius = 3;
    self.progressBar.clipsToBounds = YES;
    self.progressBar.hidden = YES;
    [root addSubview:self.progressBar];

    self.progressLabel = [UILabel new];
    self.progressLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightSemibold];
    self.progressLabel.textColor = [RSTheme textSub];
    self.progressLabel.textAlignment = NSTextAlignmentCenter;
    self.progressLabel.hidden = YES;
    [root addSubview:self.progressLabel];

    // ── 信息卡片（版本 / 大小 / 日期 / 标识 / 架构）
    self.infoCard = [UIView new];
    self.infoCard.translatesAutoresizingMaskIntoConstraints = NO;
    self.infoCard.backgroundColor = [RSTheme card];
    self.infoCard.layer.cornerRadius = 16;
    self.infoCard.layer.cornerCurve = kCACornerCurveContinuous;
    [root addSubview:self.infoCard];

    self.versionValue = [self infoRowInCard:self.infoCard title:@"版本" first:YES];
    self.sizeValue    = [self infoRowInCard:self.infoCard title:@"大小" first:NO];
    self.dateValue    = [self infoRowInCard:self.infoCard title:@"更新日期" first:NO];

    // 架构行：越狱插件的关键信息，无根/隐根必看
    if (self.item.architecture.length) {
        self.archValue = [self infoRowInCard:self.infoCard title:@"架构" first:NO];
    }
    self.idValue = [self infoRowInCard:self.infoCard title:@"标识" first:NO];

    // ── 版本切换行：有多个版本时显示，点它可换版本
    NSArray<RSAppItem *> *vs = [self allVersionsForItem:self.item];
    if (vs.count > 1) {
        self.versionRow = [self makeTapRowInCard:self.infoCard
                                           title:@"切换版本"
                                          detail:[NSString stringWithFormat:@"共 %lu 个版本",
                                                  (unsigned long)vs.count]];
    }

    // ── 简介
    UILabel *descHeader = [UILabel new];
    descHeader.translatesAutoresizingMaskIntoConstraints = NO;
    descHeader.text = @"简介";
    descHeader.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    descHeader.textColor = [RSTheme textSub];
    [root addSubview:descHeader];

    self.descLabel = [UILabel new];
    self.descLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.descLabel.font = [UIFont systemFontOfSize:14];
    self.descLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.85];
    self.descLabel.numberOfLines = 0;
    self.descLabel.text = self.item.localizedDescription.length
        ? self.item.localizedDescription : @"暂无简介";
    [root addSubview:self.descLabel];

    // 翻译按钮：简介不是中文时才出现
    self.translateBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.translateBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.translateBtn setTitle:@"翻译成中文" forState:UIControlStateNormal];
    [self.translateBtn setImage:[UIImage systemImageNamed:@"character.bubble"] forState:UIControlStateNormal];
    self.translateBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    self.translateBtn.tintColor = [RSTheme accent];
    self.translateBtn.hidden = [RSTranslateService isMostlyChinese:self.item.localizedDescription ?: @""];
    [self.translateBtn addTarget:self action:@selector(translateTapped) forControlEvents:UIControlEventTouchUpInside];
    [root addSubview:self.translateBtn];

    [self layoutTopAreaWithRoot:root descHeader:descHeader];

    [self fillInfoValues];
}

/// 顶部区域的整体约束（图标 → 名称 → 按钮 → 信息卡 → 简介）
- (void)layoutTopAreaWithRoot:(UIView *)root descHeader:(UILabel *)descHeader {
    CGFloat margin = 20;

    NSMutableArray<NSLayoutConstraint *> *cs = [NSMutableArray array];
    [cs addObjectsFromArray:@[
        [self.iconView.topAnchor constraintEqualToAnchor:root.topAnchor constant:18],
        [self.iconView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.iconView.widthAnchor constraintEqualToConstant:88],
        [self.iconView.heightAnchor constraintEqualToConstant:88],

        [self.nameLabel.topAnchor constraintEqualToAnchor:self.iconView.bottomAnchor constant:14],
        [self.nameLabel.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:margin],
        [self.nameLabel.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-margin],

        [self.devLabel.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:5],
        [self.devLabel.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:margin],
        [self.devLabel.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-margin],

        [self.metaLabel.topAnchor constraintEqualToAnchor:self.devLabel.bottomAnchor constant:6],
        [self.metaLabel.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:margin],
        [self.metaLabel.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-margin],

        [self.actionBtn.topAnchor constraintEqualToAnchor:self.metaLabel.bottomAnchor constant:18],
        [self.actionBtn.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:margin],
        [self.actionBtn.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-margin],
        [self.actionBtn.heightAnchor constraintEqualToConstant:50],

        [self.progressBar.topAnchor constraintEqualToAnchor:self.actionBtn.bottomAnchor constant:10],
        [self.progressBar.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:margin],
        [self.progressBar.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-margin],

        [self.progressLabel.topAnchor constraintEqualToAnchor:self.progressBar.bottomAnchor constant:5],
        [self.progressLabel.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:margin],
        [self.progressLabel.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-margin],

        [self.infoCard.topAnchor constraintEqualToAnchor:self.progressLabel.bottomAnchor constant:18],
        [self.infoCard.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:margin],
        [self.infoCard.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-margin],

        [descHeader.topAnchor constraintEqualToAnchor:self.infoCard.bottomAnchor constant:22],
        [descHeader.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:margin],

        [self.descLabel.topAnchor constraintEqualToAnchor:descHeader.bottomAnchor constant:8],
        [self.descLabel.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:margin],
        [self.descLabel.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-margin],

        [self.translateBtn.topAnchor constraintEqualToAnchor:self.descLabel.bottomAnchor constant:10],
        [self.translateBtn.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:margin],
        [self.translateBtn.heightAnchor constraintEqualToConstant:30],
    ]];

    // scroll 内容高度由最后一个元素决定
    [cs addObject:[self.translateBtn.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-28]];
    [NSLayoutConstraint activateConstraints:cs];
}

/// 在信息卡里加一行「标题 + 值」，返回值 label
- (UILabel *)infoRowInCard:(UIView *)card title:(NSString *)title first:(BOOL)first {
    UILabel *k = [UILabel new];
    k.translatesAutoresizingMaskIntoConstraints = NO;
    k.text = title;
    k.font = [UIFont systemFontOfSize:13];
    k.textColor = [RSTheme textSub];
    [card addSubview:k];

    UILabel *v = [UILabel new];
    v.translatesAutoresizingMaskIntoConstraints = NO;
    v.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    v.textColor = [UIColor whiteColor];
    v.textAlignment = NSTextAlignmentRight;
    v.numberOfLines = 1;
    v.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [card addSubview:v];

    [NSLayoutConstraint activateConstraints:@[
        [k.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14],
        [k.topAnchor constraintEqualToAnchor:card.topAnchor
                                    constant:(first ? 13 : 0)],
        [v.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14],
        [v.centerYAnchor constraintEqualToAnchor:k.centerYAnchor],
        [v.leadingAnchor constraintGreaterThanOrEqualToAnchor:k.trailingAnchor constant:10],
    ]];

    if (!first) {
        // 非首行：把它的顶部接到上一个视图的底部
        UIView *prev = card.subviews[card.subviews.count - 3]; // 上一行的 key
        [k.topAnchor constraintEqualToAnchor:prev.bottomAnchor constant:11].active = YES;
        // 修正为真正的上一行
    }
    return v;
}

/// 可点击的一行（切换版本）
- (UIView *)makeTapRowInCard:(UIView *)card title:(NSString *)title detail:(NSString *)detail {
    UIView *row = [UIView new];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.userInteractionEnabled = YES;
    [card addSubview:row];

    UITapGestureRecognizer *tap =
    [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(versionRowTapped)];
    [row addGestureRecognizer:tap];

    UILabel *k = [UILabel new];
    k.translatesAutoresizingMaskIntoConstraints = NO;
    k.text = title;
    k.font = [UIFont systemFontOfSize:13];
    k.textColor = [RSTheme textSub];
    [row addSubview:k];

    UILabel *v = [UILabel new];
    v.translatesAutoresizingMaskIntoConstraints = NO;
    v.text = detail;
    v.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    v.textColor = [RSTheme accent];
    v.textAlignment = NSTextAlignmentRight;
    [row addSubview:v];

    UIImageView *chev = [UIImageView new];
    chev.translatesAutoresizingMaskIntoConstraints = NO;
    chev.image = [UIImage systemImageNamed:@"chevron.right"];
    chev.tintColor = [RSTheme accent];
    chev.contentMode = UIViewContentModeScaleAspectFit;
    [row addSubview:chev];

    // 接在信息卡最后一行之后
    UIView *last = card.subviews[card.subviews.count - 4];
    [NSLayoutConstraint activateConstraints:@[
        [row.topAnchor constraintEqualToAnchor:last.bottomAnchor constant:12],
        [row.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14],
        [row.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14],
        [row.heightAnchor constraintEqualToConstant:26],
        [row.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-13],

        [k.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [k.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],

        [chev.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [chev.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [chev.widthAnchor constraintEqualToConstant:7],
        [chev.heightAnchor constraintEqualToConstant:12],

        [v.trailingAnchor constraintEqualToAnchor:chev.leadingAnchor constant:-6],
        [v.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
    ]];
    return row;
}

- (void)fillInfoValues {
    self.versionValue.text = self.item.version ?: @"-";
    self.sizeValue.text = self.item.sizeText.length ? self.item.sizeText : @"未知";
    self.dateValue.text = self.item.versionDate.length ? self.item.versionDate : @"-";
    self.idValue.text = self.item.bundleIdentifier ?: @"-";
    if (self.archValue) {
        self.archValue.text = [self.item architectureDisplayName];
    }

    NSMutableArray *bits = [NSMutableArray array];
    if (self.item.version.length) [bits addObject:[NSString stringWithFormat:@"v%@", self.item.version]];
    if (self.item.sizeText.length) [bits addObject:self.item.sizeText];
    self.metaLabel.text = [bits componentsJoinedByString:@"  ·  "];
}

/// 该条目的全部可下载版本
- (NSArray<RSAppItem *> *)allVersionsForItem:(RSAppItem *)item {
    // versions 已经是完整的（含多架构），直接用
    if (item.versions.count > 1) return item.versions;

    NSString *key = item.packageName.length ? item.packageName : item.bundleIdentifier;
    if (key.length == 0) return item.versions;

    // 从全局所有源的条目里按包名收集同款包（含不同架构）
    NSMutableArray<RSAppItem *> *found = [NSMutableArray array];
    for (RSRepo *r in [[RSStore shared] repos]) {
        for (RSAppItem *a in r.apps) {
            NSString *k = a.packageName.length ? a.packageName : a.bundleIdentifier;
            if (![k isEqualToString:key]) continue;
            // 只收可下载的：别的源里同名却没有体积/地址的条目，
            // 一旦混进来被选中，界面就会变成"此条目不可下载"。
            if (!a.isDownloadable) continue;
            [found addObject:a];
        }
    }
    // 并上 item.versions 里可下载的那部分
    for (RSAppItem *v in item.versions ?: @[]) {
        if (!v.isDownloadable) continue;
        BOOL dup = NO;
        for (RSAppItem *f in found) {
            if ([f.downloadURL isEqualToString:v.downloadURL]) { dup = YES; break; }
        }
        if (!dup) [found addObject:v];
    }
    if (found.count > 1) {
        item.versions = [found copy];
        return item.versions;
    }
    return item.versions;
}

/// 按钮文案按文件类型区分：
/// 越狱源的 deb 包是插件，不该写成"下载 IPA"。
- (NSString *)downloadButtonTitle {
    NSString *u = self.item.downloadURL.lowercaseString ?: @"";
    if ([u containsString:@".deb"]) return @"  下载插件";
    if ([u containsString:@".ipa"] || [u containsString:@".tipa"]) return @"  下载 IPA";
    if ([u containsString:@".zip"] || [u containsString:@".tar"] ||
        [u containsString:@".xz"] || [u containsString:@".gz"] ||
        [u containsString:@".bz2"] || [u containsString:@".7z"]) return @"  下载压缩包";
    return @"  下载文件";
}

/// 切换版本后重建界面。
/// buildUI 不清空旧视图，所以先移除 scroll 的所有子视图，再重新构建。
- (void)rebuildUIForItem:(RSAppItem *)item {
    self.item = item;
    self.title = item.name;
    for (UIView *v in [self.scroll.subviews copy]) {
        [v removeFromSuperview];
    }
    [self buildUI];
    [self restoreDownloadState];
}

/// 弹出版本选择列表（同包多版本时可用）
- (void)showVersionPicker {
    NSArray<RSAppItem *> *versions = [self allVersionsForItem:self.item];
    if (versions.count <= 1) return;

    UIAlertController *sheet = [UIAlertController
        alertControllerWithTitle:@"选择版本"
                         message:[NSString stringWithFormat:@"%@ 共 %lu 个版本",
                                  self.item.name, (unsigned long)versions.count]
                  preferredStyle:UIAlertControllerStyleActionSheet];

    // 标题里标注当前选中的版本与架构，避免同版本不同架构时看不出区别
    for (RSAppItem *v in versions) {
        if (!v.isDownloadable) continue;   // 无地址/体积异常的条目不给选
        NSString *title = v.version ?: @"?";
        // 直接写清「无根/隐根」，同版本不同架构时一眼能分辨
        if (v.architecture.length) {
            title = [NSString stringWithFormat:@"%@  ·  %@", title, [v architectureDisplayName]];
        }
        if (v.sizeText.length) {
            title = [title stringByAppendingFormat:@"  ·  %@", v.sizeText];
        }
        // 当前版本打勾
        BOOL isCurrent = [v.version isEqualToString:self.item.version] &&
                         (v.downloadURL == self.item.downloadURL ||
                          [v.downloadURL isEqualToString:self.item.downloadURL]);

        UIAlertAction *a = [UIAlertAction actionWithTitle:title
                                                    style:UIAlertActionStyleDefault
                                                  handler:^(UIAlertAction *act) {
            // 用户手动选了版本 → 之后点下载不再弹确认
            self.userPickedVersion = YES;
            if (isCurrent) return;
            // 切换版本要给这个版本补上它自己的 versions，详情页才能再次切换
            v.versions = versions;
            [self rebuildUIForItem:v];
        }];
        [sheet addAction:a];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:@"取消"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    // iPad / 大屏需要锚点，否则 present 会崩
    sheet.popoverPresentationController.sourceView = self.view;
    sheet.popoverPresentationController.sourceRect =
        CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);

    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)restoreDownloadState {
    NSString *itemId = self.item.itemId;
    if (!itemId.length) {
        [self applyIdleUI];
        return;
    }

    // 公告 / 通知 / 无资源条目：不给下载
    if (!self.item.isDownloadable) {
        // 兜底：只要还有有效下载地址，就不该锁死按钮。
        // （切换版本后出现的"此条目不可下载"就是误判到这里）
        NSString *u = self.item.downloadURL.lowercaseString ?: @"";
        BOOL hasURL = [u hasPrefix:@"http"];
        if (hasURL) {
            [self applyIdleUI];
        } else {
            [self applyNonDownloadableUI];
        }
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
    [self.actionBtn setTitle:[self downloadButtonTitle] forState:UIControlStateNormal];
    [self.actionBtn setImage:[UIImage systemImageNamed:@"arrow.down.circle.fill"]
                    forState:UIControlStateNormal];
    self.actionBtn.backgroundColor = [RSTheme accent];
    self.progressBar.hidden = YES;
    self.progressBar.progress = 0;
    self.progressLabel.hidden = YES;
    self.progressLabel.text = @"";
    [self stopProgressTracking];
}

/// 不可下载（公告 / 通知）
- (void)applyNonDownloadableUI {
    self.actionBtn.enabled = NO;
    [self.actionBtn setTitle:@"  此条目不可下载" forState:UIControlStateNormal];
    [self.actionBtn setImage:[UIImage systemImageNamed:@"nosign"] forState:UIControlStateNormal];
    self.actionBtn.backgroundColor = [RSTheme card2];
    self.progressBar.hidden = YES;
    self.progressLabel.hidden = YES;
    [self stopProgressTracking];
}

/// 下载中
- (void)applyDownloadingUI {
    self.actionBtn.enabled = NO;
    [self.actionBtn setTitle:@"  下载中…" forState:UIControlStateNormal];
    [self.actionBtn setImage:[UIImage systemImageNamed:@"arrow.down.circle"] forState:UIControlStateNormal];
    self.actionBtn.backgroundColor = [RSTheme card2];
    self.progressBar.hidden = NO;
    self.progressLabel.hidden = NO;
}

/// 已完成
- (void)applyFinishedUI {
    self.actionBtn.enabled = YES;
    NSString *u = self.item.downloadURL.lowercaseString ?: @"";
    BOOL deb = [u containsString:@".deb"];
    [self.actionBtn setTitle:(deb ? @"  分享插件" : @"  分享 / 安装")
                   forState:UIControlStateNormal];
    [self.actionBtn setImage:[UIImage systemImageNamed:@"square.and.arrow.up"]
                    forState:UIControlStateNormal];
    self.actionBtn.backgroundColor = [RSTheme accent2];
    self.progressBar.hidden = YES;
    self.progressLabel.hidden = YES;
    [self stopProgressTracking];
}

#pragma mark - 进度轮询

- (void)startProgressTracking {
    if (self.progressTimer) return;
    self.progressTimer = [CADisplayLink displayLinkWithTarget:self selector:@selector(tickProgress)];
    self.progressTimer.preferredFramesPerSecond = 6;
    [self.progressTimer addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopProgressTracking {
    [self.progressTimer invalidate];
    self.progressTimer = nil;
}

- (void)tickProgress {
    double p = [[RSStore shared] currentProgressForItemId:self.item.itemId];
    if (p < 0) return;
    if (p >= 1.0) {
        [self restoreDownloadState];
        return;
    }
    self.progressBar.progress = (float)p;
    self.progressLabel.text = [NSString stringWithFormat:@"%.0f%%", p * 100];
}

#pragma mark - 版本切换

- (void)versionRowTapped {
    [self showVersionPicker];
}

#pragma mark - 下载

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

    // 用户在「版本」行主动选过版本 → 直接下，不再多问一次。
    // 从没选过、而包里又有多个版本/架构 → 先让他挑，避免默认拿错架构。
    if (self.userPickedVersion) {
        [self downloadTapped];
        return;
    }
    NSArray<RSAppItem *> *choices = [self downloadableChoices];
    if (choices.count > 1) {
        [self presentChoicePicker:choices];
        return;
    }
    [self downloadTapped];
}

/// 该包所有可下载条目（去重），用于判断是否需要让用户先选。
- (NSArray<RSAppItem *> *)downloadableChoices {
    NSMutableArray<RSAppItem *> *all = [NSMutableArray array];
    [all addObjectsFromArray:[self allVersionsForItem:self.item]];
    if (all.count == 0) [all addObject:self.item];

    NSMutableArray<RSAppItem *> *uniq = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (RSAppItem *a in all) {
        // 只保留真正能下的：没有地址/体积异常的公告条目不能出现在选择列表里，
        // 否则选中它就变成"此条目不可下载"。
        if (!a.isDownloadable) continue;
        NSString *k = a.downloadURL.length ? a.downloadURL : a.itemId;
        if (!k.length || [seen containsObject:k]) continue;
        [seen addObject:k];
        [uniq addObject:a];
    }
    // 兜底：全被过滤掉时至少保留当前条目（它本身可下才会走到这里）
    if (uniq.count == 0 && self.item.isDownloadable) [uniq addObject:self.item];
    return uniq;
}

/// 下载前的选择弹窗：列出所有版本与架构，选一个后立即下载。
- (void)presentChoicePicker:(NSArray<RSAppItem *> *)choices {
    UIAlertController *sheet = [UIAlertController
        alertControllerWithTitle:@"选择要下载的版本"
                         message:@"该插件有多个版本或架构，请选择与你的越狱环境匹配的包"
                  preferredStyle:UIAlertControllerStyleActionSheet];

    for (RSAppItem *a in choices) {
        NSMutableString *t = [NSMutableString string];
        [t appendString:a.version.length ? a.version : @"?"];
        [t appendFormat:@"  ·  %@", [a architectureDisplayName]];
        if (a.sizeText.length) [t appendFormat:@"  ·  %@", a.sizeText];

        UIAlertAction *act = [UIAlertAction actionWithTitle:t
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction *x) {
            // 选完就当作"已选过"，直接下载所选条目
            self.userPickedVersion = YES;
            if (![a.downloadURL isEqualToString:self.item.downloadURL]) {
                a.versions = self.item.versions ?: choices;
                [self rebuildUIForItem:a];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [self downloadTapped];
            });
        }];
        [sheet addAction:act];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:@"取消"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    sheet.popoverPresentationController.sourceView = self.actionBtn ?: self.view;
    sheet.popoverPresentationController.sourceRect = self.actionBtn
        ? self.actionBtn.bounds
        : CGRectMake(CGRectGetMidX(self.view.bounds),
                     CGRectGetMidY(self.view.bounds), 1, 1);
    [self presentViewController:sheet animated:YES completion:nil];
}

/// 真正开始下载
- (void)downloadTapped {
    __weak typeof(self) weakSelf = self;
    [self applyDownloadingUI];
    self.progressBar.progress = 0;
    self.progressLabel.text = @"0%";

    [[RSStore shared] downloadItem:self.item
                          progress:^(double p) {
        __strong typeof(weakSelf) s = weakSelf;
        if (!s) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            s.progressBar.progress = (float)p;
            s.progressLabel.text = [NSString stringWithFormat:@"%.0f%%", p * 100];
        });
    } completion:^(NSURL *fileURL, NSString *error) {
        __strong typeof(weakSelf) s = weakSelf;
        if (!s) return;
        if (fileURL) {
            s.downloadedURL = fileURL;
            [s applyFinishedUI];
            UINotificationFeedbackGenerator *fb = [UINotificationFeedbackGenerator new];
            [fb notificationOccurred:UINotificationFeedbackTypeSuccess];
        } else {
            [s applyIdleUI];
            [RSInstallService toast:(error ?: @"下载失败") in:s];
        }
    }];
}

#pragma mark - 翻译

- (void)translateTapped {
    if (self.translatedText.length) {
        // 已有译文：在原文/译文之间切换
        self.showingTranslation = !self.showingTranslation;
        self.descLabel.text = self.showingTranslation
            ? self.translatedText
            : (self.item.localizedDescription.length ? self.item.localizedDescription : @"暂无简介");
        [self.translateBtn setTitle:(self.showingTranslation ? @"显示原文" : @"显示译文")
                           forState:UIControlStateNormal];
        return;
    }

    [self.translateBtn setEnabled:NO];
    [self.translateBtn setTitle:@"翻译中…" forState:UIControlStateNormal];

    __weak typeof(self) weakSelf = self;
    [[RSTranslateService shared] translateToChinese:self.item.localizedDescription
                                          completion:^(NSString *translated, NSString *lang, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) s = weakSelf;
            if (!s) return;
            [s.translateBtn setEnabled:YES];

            if (translated.length == 0) {
                [s.translateBtn setTitle:@"翻译成中文" forState:UIControlStateNormal];
                [RSInstallService toast:(error.localizedDescription ?: @"翻译失败") in:s];
                return;
            }
            s.translatedText = translated;
            s.showingTranslation = YES;
            s.descLabel.text = translated;
            [s.translateBtn setTitle:@"显示原文" forState:UIControlStateNormal];
        });
    }];
}

@end
