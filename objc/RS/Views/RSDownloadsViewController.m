#import "RSDownloadsViewController.h"
#import "RSStore.h"
#import "RSTheme.h"
#import "RSIconView.h"
#import "RSInstallService.h"

static NSString *const kCellId = @"download";

/// 下载条目单元格
@interface RSDownloadCell : UITableViewCell
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) RSIconView *icon;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) UILabel *stateLabel;
@property (nonatomic, strong) UIProgressView *bar;
@property (nonatomic, strong) NSLayoutConstraint *barHeight;
@property (nonatomic, strong) NSLayoutConstraint *barGap;
- (void)configureWithRecord:(RSDownloadRecord *)rec progress:(double)p;
@end

@implementation RSDownloadCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _card = [UIView new];
        _card.backgroundColor = [RSTheme card];
        _card.layer.cornerRadius = 16;
        _card.layer.cornerCurve = kCACornerCurveContinuous;
        _card.layer.borderWidth = 1.0;
        _card.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.05].CGColor;
        _card.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_card];

        _icon = [RSIconView new];
        _icon.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_icon];

        _nameLabel = [UILabel new];
        _nameLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        _nameLabel.textColor = [UIColor whiteColor];
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_nameLabel];

        _detailLabel = [UILabel new];
        _detailLabel.font = [UIFont systemFontOfSize:11];
        _detailLabel.textColor = [RSTheme textSub];
        _detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_detailLabel];

        _stateLabel = [UILabel new];
        _stateLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightSemibold];
        _stateLabel.textColor = [RSTheme accent];
        _stateLabel.textAlignment = NSTextAlignmentRight;
        _stateLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_stateLabel];

        _bar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        _bar.translatesAutoresizingMaskIntoConstraints = NO;
        _bar.progressTintColor = [RSTheme accent];
        _bar.trackTintColor = [RSTheme card2];
        _bar.layer.cornerRadius = 2;
        _bar.clipsToBounds = YES;
        _bar.hidden = YES;
        [_card addSubview:_bar];

        // 进度条高度约束：隐藏时高度归零，让卡片收起来（避免"下载中挤、已下载空一大块"）
        _barHeight = [_bar.heightAnchor constraintEqualToConstant:4];
        _barGap = [_bar.topAnchor constraintEqualToAnchor:_detailLabel.bottomAnchor constant:7];

        [NSLayoutConstraint activateConstraints:@[
            [_card.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:5],
            [_card.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5],
            [_card.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_card.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],

            // 图标固定大小，垂直居中，但不参与决定卡片高度
            [_icon.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:12],
            [_icon.centerYAnchor constraintEqualToAnchor:_card.centerYAnchor],
            [_icon.widthAnchor constraintEqualToConstant:46],
            [_icon.heightAnchor constraintEqualToConstant:46],
            [_icon.topAnchor constraintGreaterThanOrEqualToAnchor:_card.topAnchor constant:10],
            [_icon.bottomAnchor constraintLessThanOrEqualToAnchor:_card.bottomAnchor constant:-10],

            // 状态文字：右侧，和名字同一水平线，不与内容重叠
            [_stateLabel.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-13],
            [_stateLabel.topAnchor constraintEqualToAnchor:_card.topAnchor constant:13],

            // 名字
            [_nameLabel.leadingAnchor constraintEqualToAnchor:_icon.trailingAnchor constant:11],
            [_nameLabel.topAnchor constraintEqualToAnchor:_card.topAnchor constant:12],
            [_nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_stateLabel.leadingAnchor constant:-8],

            // 详情
            [_detailLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_detailLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:3],
            [_detailLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_card.trailingAnchor constant:-13],

            // 进度条
            _barGap,
            [_bar.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_bar.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-13],
            _barHeight,
            // 关键：进度条底边钉死卡片底部，卡片高度才能真正算出来
            [_bar.bottomAnchor constraintEqualToAnchor:_card.bottomAnchor constant:-12],
        ]];
    }
    return self;
}

- (void)configureWithRecord:(RSDownloadRecord *)rec progress:(double)p {
    [_icon configureWithURL:rec.iconURL seed:rec.name cornerRadius:10];
    _nameLabel.text = rec.name.length ? rec.name : @"未命名应用";

    NSMutableArray *bits = [NSMutableArray array];
    if (rec.version.length) [bits addObject:[NSString stringWithFormat:@"v%@", rec.version]];
    if (rec.sizeText.length) [bits addObject:rec.sizeText];
    _detailLabel.text = [bits componentsJoinedByString:@"  ·  "];

    if (rec.finished) {
        _stateLabel.text = @"已下载";
        _stateLabel.textColor = [RSTheme accent];
        _bar.hidden = YES;
        _barHeight.constant = 0;
        _barGap.constant = 0;
    } else {
        _stateLabel.text = (p >= 0) ? [NSString stringWithFormat:@"%.0f%%", p * 100] : @"下载中";
        _stateLabel.textColor = [RSTheme textSub];
        _bar.hidden = NO;
        _barHeight.constant = 4;
        _barGap.constant = 7;
        _bar.progress = (p >= 0) ? (float)p : 0;
    }
}

@end


@interface RSDownloadsViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) UIView *emptyView;
@property (nonatomic, strong) NSArray<RSDownloadRecord *> *items;
@property (nonatomic, strong) CADisplayLink *ticker;
@end

@implementation RSDownloadsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"下载";
    self.view.backgroundColor = [RSTheme bg];

    UINavigationBarAppearance *app = [UINavigationBarAppearance new];
    [app configureWithOpaqueBackground];
    app.backgroundColor = [RSTheme bg];
    app.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor whiteColor]};
    self.navigationController.navigationBar.standardAppearance = app;
    self.navigationController.navigationBar.scrollEdgeAppearance = app;
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];

    self.navigationItem.rightBarButtonItem =
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                  target:self
                                                  action:@selector(close)];

    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.table.translatesAutoresizingMaskIntoConstraints = NO;
    self.table.backgroundColor = [RSTheme bg];
    self.table.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.contentInset = UIEdgeInsetsMake(8, 0, 24, 0);
    self.table.rowHeight = UITableViewAutomaticDimension;
    self.table.estimatedRowHeight = 84;
    [self.table registerClass:[RSDownloadCell class] forCellReuseIdentifier:kCellId];
    [self.view addSubview:self.table];
    [NSLayoutConstraint activateConstraints:@[
        [self.table.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.table.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.table.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.table.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    [self buildEmptyView];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reload)
                                                 name:RSDownloadsChangedNotification
                                               object:nil];
    [self reload];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reload];
    [self startTicker];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopTicker];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopTicker];
}

- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }

#pragma mark - 刷新

- (void)reload {
    self.items = [[RSStore shared] downloadRecords];
    [self.table reloadData];
    self.emptyView.hidden = self.items.count > 0;
    self.table.hidden = (self.items.count == 0);
    // 有记录就轮询进度（是否完成交给 tick 判断）
    if (self.items.count > 0) [self startTicker]; else [self stopTicker];
}

- (void)startTicker {
    if (self.ticker) return;
    // 只要有记录就轮询：之前要求"存在未完成项"才启动，
    // 而刚点下载时记录可能还没落到 downloadRecords 里 → 定时器不启动 → 进度恒为 0。
    if (self.items.count == 0) return;
    self.ticker = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick)];
    self.ticker.preferredFramesPerSecond = 10;
    [self.ticker addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopTicker {
    [self.ticker invalidate];
    self.ticker = nil;
}

- (void)tick {
    // 只刷新可见 cell，避免整表 reload 打断滑动
    if (self.items.count == 0) { [self stopTicker]; return; }

    BOOL anyRunning = NO;
    for (NSIndexPath *ip in self.table.indexPathsForVisibleRows) {
        if (ip.row >= (NSInteger)self.items.count) continue;
        RSDownloadRecord *r = self.items[ip.row];
        if (r.finished) continue;

        double p = [[RSStore shared] currentProgressForItemId:r.itemId];
        if (p > 0 && p < 1) anyRunning = YES;

        RSDownloadCell *cell = (RSDownloadCell *)[self.table cellForRowAtIndexPath:ip];
        if ([cell isKindOfClass:[RSDownloadCell class]]) {
            [cell configureWithRecord:r progress:p];
        }
    }

    // 有下载完成时列表需要重建（记录会变为已下载）
    for (RSDownloadRecord *r in self.items) {
        if (!r.finished && [[RSStore shared] currentProgressForItemId:r.itemId] >= 1.0) {
            [self reload];
            return;
        }
    }
    if (!anyRunning) {
        // 没有任何进行中的下载，停止轮询省电
        BOOL hasUnfinished = NO;
        for (RSDownloadRecord *r in self.items) if (!r.finished) hasUnfinished = YES;
        if (!hasUnfinished) [self stopTicker];
    }
}

#pragma mark - 空态

- (void)buildEmptyView {
    self.emptyView = [UIView new];
    self.emptyView.translatesAutoresizingMaskIntoConstraints = NO;

    UIImageView *icon = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"arrow.down.circle.dotted"]];
    icon.tintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.22];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *title = [UILabel new];
    title.text = @"暂无下载";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:19];
    title.textAlignment = NSTextAlignmentCenter;
    title.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *sub = [UILabel new];
    sub.text = @"下载过的文件会出现在这里";
    sub.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.5];
    sub.font = [UIFont systemFontOfSize:14];
    sub.textAlignment = NSTextAlignmentCenter;
    sub.translatesAutoresizingMaskIntoConstraints = NO;

    [self.emptyView addSubview:icon];
    [self.emptyView addSubview:title];
    [self.emptyView addSubview:sub];
    [self.view addSubview:self.emptyView];

    [NSLayoutConstraint activateConstraints:@[
        [self.emptyView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.emptyView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.emptyView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],

        [icon.topAnchor constraintEqualToAnchor:self.emptyView.topAnchor],
        [icon.centerXAnchor constraintEqualToAnchor:self.emptyView.centerXAnchor],
        [icon.widthAnchor constraintEqualToConstant:64],
        [icon.heightAnchor constraintEqualToConstant:64],

        [title.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:16],
        [title.centerXAnchor constraintEqualToAnchor:self.emptyView.centerXAnchor],

        [sub.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:7],
        [sub.centerXAnchor constraintEqualToAnchor:self.emptyView.centerXAnchor],
        [sub.bottomAnchor constraintEqualToAnchor:self.emptyView.bottomAnchor],
    ]];
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    RSDownloadCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellId forIndexPath:indexPath];
    RSDownloadRecord *r = self.items[indexPath.row];
    double p = r.finished ? 1.0 : [[RSStore shared] currentProgressForItemId:r.itemId];
    [cell configureWithRecord:r progress:p];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    RSDownloadRecord *r = self.items[indexPath.row];
    if (!r.finished || r.filePath.length == 0) return;

    NSURL *file = [NSURL fileURLWithPath:r.filePath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:r.filePath]) {
        [RSInstallService toast:@"文件已不存在" in:self];
        [self reload];
        return;
    }

    UIAlertController *sheet = [UIAlertController
        alertControllerWithTitle:r.name
                         message:r.fileName
                  preferredStyle:UIAlertControllerStyleActionSheet];

    [sheet addAction:[UIAlertAction actionWithTitle:@"分享 / 安装"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        // IPA 优先尝试 TrollStore 直装，失败再走分享面板
        if ([r.fileName.lowercaseString hasSuffix:@".ipa"] &&
            [RSInstallService trollStoreInstall:file]) {
            return;
        }
        [RSInstallService shareFile:file from:self];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"删除"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *a) {
        [[RSStore shared] removeDownloadRecord:r];
        [self reload];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"取消"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    sheet.popoverPresentationController.sourceView = self.view;
    sheet.popoverPresentationController.sourceRect =
        CGRectMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2, 1, 1);
    [self presentViewController:sheet animated:YES completion:nil];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    RSDownloadRecord *r = self.items[indexPath.row];
    UIContextualAction *del = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                     title:@"删除"
                                                                   handler:^(UIContextualAction *a, UIView *v, void (^done)(BOOL)) {
        [[RSStore shared] removeDownloadRecord:r];
        [self reload];
        done(YES);
    }];
    del.backgroundColor = [UIColor colorWithRed:0.85 green:0.22 blue:0.25 alpha:1];
    return [UISwipeActionsConfiguration configurationWithActions:@[del]];
}

@end
