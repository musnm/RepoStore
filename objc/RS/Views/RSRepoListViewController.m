#import "RSRepoListViewController.h"
#import "RSPopMenuView.h"
#import "RSTheme.h"
#import "RSStore.h"
#import "RSRepo.h"
#import "RSRepoCell.h"
#import "RSAddRepoViewController.h"
#import "RSRepoDetailViewController.h"
#import "RSDownloadsViewController.h"
#import "RSUnlockViewController.h"

@interface RSRepoListViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) UIView *emptyView;
@property (nonatomic, strong) RSPopMenuView *popMenu;
@property (nonatomic, assign) BOOL presentedFromEmptyButton;
@end

@implementation RSRepoListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"软件源";
    self.view.backgroundColor = [RSTheme bg];

    UINavigationBarAppearance *app = [UINavigationBarAppearance new];
    [app configureWithOpaqueBackground];
    app.backgroundColor = [RSTheme bg];
    app.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor whiteColor]};
    app.largeTitleTextAttributes = @{NSForegroundColorAttributeName: [UIColor whiteColor]};
    self.navigationController.navigationBar.standardAppearance = app;
    self.navigationController.navigationBar.scrollEdgeAppearance = app;

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"ellipsis.circle"]
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(menuTapped)];
    self.navigationItem.rightBarButtonItem.tintColor = [UIColor whiteColor];

    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.table.translatesAutoresizingMaskIntoConstraints = NO;
    self.table.backgroundColor = [RSTheme bg];
    self.table.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.contentInset = UIEdgeInsetsMake(8, 0, 24, 0);
    self.table.rowHeight = UITableViewAutomaticDimension;
    self.table.estimatedRowHeight = 92;
    [self.table registerClass:[RSRepoCell class] forCellReuseIdentifier:@"repo"];
    [self.view addSubview:self.table];
    [NSLayoutConstraint activateConstraints:@[
        [self.table.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.table.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.table.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.table.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onReposChanged)
                                                 name:@"RSReposChanged"
                                               object:nil];

    [self buildEmptyView];
    [self updateEmpty];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // 回到列表页时，回收任何可能残留的弹出菜单遮罩，
    // 防止"全屏透明遮罩没被移除 → 整个界面点不动"。
    for (UIView *v in self.view.subviews) {
        if ([v isKindOfClass:[RSPopMenuView class]]) {
            [(RSPopMenuView *)v dismiss];
        }
    }
    if (self.popMenu) {
        [self.popMenu dismiss];
        self.popMenu = nil;
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)buildEmptyView {
    self.emptyView = [[UIView alloc] init];
    self.emptyView.translatesAutoresizingMaskIntoConstraints = NO;
    // 空态容器不拦截触摸，避免把整个屏幕点死
    self.emptyView.backgroundColor = [UIColor clearColor];

    UIImageView *icon = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"square.stack.3d.up.slash"]];
    icon.tintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.22];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *title = [[UILabel alloc] init];
    title.text = @"还没有软件源";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:20];
    title.textAlignment = NSTextAlignmentCenter;
    title.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *sub = [[UILabel alloc] init];
    sub.text = @"添加一个源，开始浏览应用";
    sub.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.5];
    sub.font = [UIFont systemFontOfSize:15];
    sub.textAlignment = NSTextAlignmentCenter;
    sub.translatesAutoresizingMaskIntoConstraints = NO;

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:@"添加软件源" forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    btn.backgroundColor = [RSTheme accent];
    btn.layer.cornerRadius = 22;
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn addTarget:self action:@selector(addTapped) forControlEvents:UIControlEventTouchUpInside];

    [self.emptyView addSubview:icon];
    [self.emptyView addSubview:title];
    [self.emptyView addSubview:sub];
    [self.emptyView addSubview:btn];
    [self.view addSubview:self.emptyView];

    [NSLayoutConstraint activateConstraints:@[
        [self.emptyView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [self.emptyView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [self.emptyView.centerYAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerYAnchor],

        // 垂直链必须有始有终，否则 emptyView 高度算不出来 → 按钮被压成 0 高度点不到
        [icon.topAnchor constraintEqualToAnchor:self.emptyView.topAnchor],
        [icon.centerXAnchor constraintEqualToAnchor:self.emptyView.centerXAnchor],
        [icon.heightAnchor constraintEqualToConstant:72],
        [icon.widthAnchor constraintEqualToConstant:72],

        [title.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:18],
        [title.centerXAnchor constraintEqualToAnchor:self.emptyView.centerXAnchor],
        [title.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.emptyView.leadingAnchor constant:24],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:self.emptyView.trailingAnchor constant:-24],

        [sub.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:8],
        [sub.centerXAnchor constraintEqualToAnchor:self.emptyView.centerXAnchor],
        [sub.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.emptyView.leadingAnchor constant:24],
        [sub.trailingAnchor constraintLessThanOrEqualToAnchor:self.emptyView.trailingAnchor constant:-24],

        [btn.topAnchor constraintEqualToAnchor:sub.bottomAnchor constant:28],
        [btn.centerXAnchor constraintEqualToAnchor:self.emptyView.centerXAnchor],
        [btn.widthAnchor constraintEqualToConstant:168],
        [btn.heightAnchor constraintEqualToConstant:44],
        [btn.bottomAnchor constraintEqualToAnchor:self.emptyView.bottomAnchor],
    ]];
}

- (void)onReposChanged {
    [self.table reloadData];
    [self updateEmpty];
}

- (void)updateEmpty {
    BOOL empty = ([RSStore shared].repos.count == 0);
    self.emptyView.hidden = !empty;
    self.table.hidden = empty;
}

#pragma mark - 菜单（微信式小气泡）

- (void)menuTapped {
    [self showMenuFromBarButton];
}

- (void)showMenuFromBarButton {
    if (self.popMenu) { [self dismissMenu]; return; }

    NSArray *items = @[
        @{RSPopMenuItemKeyTitle: @"添加软件源", RSPopMenuItemKeySymbol: @"plus"},
        @{RSPopMenuItemKeyTitle: @"下载",       RSPopMenuItemKeySymbol: @"arrow.down.circle"},
    ];

    // 锚点 = 导航栏底边（不依赖按钮视图，按钮矩形在系统里取不准，会飘）。
    // 菜单从导航栏下方 6pt 展开，箭头对准右上角。
    CGFloat vw = CGRectGetWidth(self.view.bounds);
    CGFloat anchorY;
    UINavigationBar *bar = self.navigationController.navigationBar;
    if (bar && !bar.hidden && bar.window) {
        CGRect r = [self.view convertRect:bar.frame
                                   fromView:bar.superview ?: self.view];
        anchorY = CGRectGetMaxY(r);
    } else {
        anchorY = self.view.safeAreaInsets.top > 0 ? self.view.safeAreaInsets.top : 88;
    }
    CGRect barRect = CGRectMake(vw - 44, anchorY, 44, 0);

    __weak typeof(self) weakSelf = self;
    self.popMenu = [RSPopMenuView showInView:self.view
                                  anchorRect:barRect
                                      items:items
                                    handler:^(NSInteger index) {
        __strong typeof(weakSelf) s = weakSelf;
        if (!s) return;
        if (index == 0) [s addTapped];
        else if (index == 1) [s downloadsTapped];
    }];

}

- (void)dismissMenu {
    [self.popMenu dismiss];
    self.popMenu = nil;
}

- (void)addTapped {
    [self dismissMenu];
    RSAddRepoViewController *vc = [RSAddRepoViewController new];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)downloadsTapped {
    [self dismissMenu];
    RSDownloadsViewController *vc = [RSDownloadsViewController new];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [RSStore shared].repos.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    RSRepoCell *cell = [tableView dequeueReusableCellWithIdentifier:@"repo" forIndexPath:indexPath];
    RSRepo *r = [RSStore shared].repos[indexPath.row];
    [cell configureWithRepo:r];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    RSRepo *r = [RSStore shared].repos[indexPath.row];

    if (r.requiresUnlock && !r.isUnlocked) {
        __weak typeof(self) weakSelf = self;
        RSUnlockViewController *u = [RSUnlockViewController new];
        u.repo = r;
        u.onUnlocked = ^{
            __strong typeof(weakSelf) s = weakSelf;
            if (!s) return;
            [[RSStore shared] refreshRepoByUID:r.uid completion:^(BOOL ok, NSString *err) {
                __strong typeof(weakSelf) ss = weakSelf;
                if (!ss) return;
                RSRepoDetailViewController *dvc = [RSRepoDetailViewController new];
                dvc.repo = r;
                [ss.navigationController pushViewController:dvc animated:YES];
            }];
        };
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:u];
        [self presentViewController:nav animated:YES completion:nil];
        return;
    }

    RSRepoDetailViewController *vc = [RSRepoDetailViewController new];
    vc.repo = r;
    [self.navigationController pushViewController:vc animated:YES];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    RSRepo *r = [RSStore shared].repos[indexPath.row];
    __weak typeof(self) weakSelf = self;
    UIContextualAction *del = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                     title:@"删除"
                                                                   handler:^(UIContextualAction *a, UIView *v, void (^done)(BOOL)) {
        __strong typeof(weakSelf) s = weakSelf;
        @try {
            [[RSStore shared] removeRepo:r];
        } @catch (NSException *e) {
            NSLog(@"[RepoList] 删除源异常: %@", e);
        } @finally {
            if (s) [s onReposChanged];
            done(YES);
        }
    }];
    del.backgroundColor = [UIColor colorWithRed:0.85 green:0.22 blue:0.25 alpha:1];
    return [UISwipeActionsConfiguration configurationWithActions:@[del]];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    RSRepo *r = [RSStore shared].repos[indexPath.row];
    __weak typeof(self) weakSelf = self;
    UIContextualAction *refresh = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                         title:@"刷新"
                                                                       handler:^(UIContextualAction *a, UIView *v, void (^done)(BOOL)) {
        __strong typeof(weakSelf) s = weakSelf;
        [[RSStore shared] refreshRepoByUID:r.uid completion:^(BOOL ok, NSString *err) {
            __strong typeof(weakSelf) ss = weakSelf;
            if (ss) [ss onReposChanged];
            done(ok);
        }];
    }];
    refresh.backgroundColor = [RSTheme accent];
    return [UISwipeActionsConfiguration configurationWithActions:@[refresh]];
}

@end
