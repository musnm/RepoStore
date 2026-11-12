#import "RSRepoListViewController.h"
#import "RSStore.h"
#import "RSTheme.h"
#import "RSIconView.h"
#import "RSRepoCell.h"
#import "RSRepoDetailViewController.h"
#import "RSAddRepoViewController.h"
#import "RSUnlockViewController.h"

@interface RSRepoListViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) UIView *emptyView;
@property (nonatomic, strong) UIRefreshControl *refreshCtrl;
@end

@implementation RSRepoListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onReposChanged)
                                                 name:@"RSReposChanged"
                                               object:nil];
    self.title = @"软件源";
    self.view.backgroundColor = [RSTheme bg];

    UINavigationBarAppearance *app = [UINavigationBarAppearance new];
    [app configureWithOpaqueBackground];
    app.backgroundColor = [RSTheme bg];
    app.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor whiteColor]};
    app.largeTitleTextAttributes = @{NSForegroundColorAttributeName: [UIColor whiteColor]};
    self.navigationController.navigationBar.standardAppearance = app;
    self.navigationController.navigationBar.scrollEdgeAppearance = app;

    self.navigationItem.rightBarButtonItem =
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                  target:self
                                                  action:@selector(addTapped)];

    self.table = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.table.backgroundColor = [RSTheme bg];
    self.table.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.contentInset = UIEdgeInsetsMake(8, 0, 24, 0);
    [self.table registerClass:[RSRepoCell class] forCellReuseIdentifier:@"repo"];
    [self.view addSubview:self.table];

    self.refreshCtrl = [UIRefreshControl new];
    [self.refreshCtrl addTarget:self action:@selector(refreshAll) forControlEvents:UIControlEventValueChanged];
    self.refreshCtrl.tintColor = [RSTheme accent];
    [self.table addSubview:self.refreshCtrl];

    [self buildEmptyView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.table reloadData];
    [self updateEmpty];
}

- (void)onReposChanged {
    [self.table reloadData];
    [self updateEmpty];
}

- (void)buildEmptyView {
    UIView *v = [UIView new];
    v.translatesAutoresizingMaskIntoConstraints = NO;

    UIImageView *icon = [UIImageView new];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.image = [UIImage systemImageNamed:@"square.stack.3d.up.fill"];
    icon.tintColor = [RSTheme accent];
    icon.contentMode = UIViewContentModeScaleAspectFit;

    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"还没有软件源";
    title.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
    title.textColor = [UIColor whiteColor];
    title.textAlignment = NSTextAlignmentCenter;

    UILabel *sub = [UILabel new];
    sub.translatesAutoresizingMaskIntoConstraints = NO;
    sub.text = @"添加一个源地址，就能浏览并下载里面的应用";
    sub.font = [UIFont systemFontOfSize:13];
    sub.textColor = [RSTheme textSub];
    sub.textAlignment = NSTextAlignmentCenter;
    sub.numberOfLines = 0;

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn setTitle:@" 添加软件源" forState:UIControlStateNormal];
    [btn setImage:[UIImage systemImageNamed:@"plus"] forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    btn.tintColor = [UIColor whiteColor];
    btn.backgroundColor = [RSTheme accent];
    btn.layer.cornerRadius = 22;
    btn.configuration = nil;
    btn.contentEdgeInsets = UIEdgeInsetsMake(12, 20, 12, 20);
    [btn addTarget:self action:@selector(addTapped) forControlEvents:UIControlEventTouchUpInside];

    [v addSubview:icon];
    [v addSubview:title];
    [v addSubview:sub];
    [v addSubview:btn];
    [self.view addSubview:v];
    self.emptyView = v;

    [NSLayoutConstraint activateConstraints:@[
        [v.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [v.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-40],
        [v.widthAnchor constraintEqualToAnchor:self.view.widthAnchor constant:-60],

        [icon.centerXAnchor constraintEqualToAnchor:v.centerXAnchor],
        [icon.topAnchor constraintEqualToAnchor:v.topAnchor],
        [icon.widthAnchor constraintEqualToConstant:70],
        [icon.heightAnchor constraintEqualToConstant:70],

        [title.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:16],
        [title.leadingAnchor constraintEqualToAnchor:v.leadingAnchor],
        [title.trailingAnchor constraintEqualToAnchor:v.trailingAnchor],

        [sub.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:8],
        [sub.leadingAnchor constraintEqualToAnchor:v.leadingAnchor],
        [sub.trailingAnchor constraintEqualToAnchor:v.trailingAnchor],

        [btn.topAnchor constraintEqualToAnchor:sub.bottomAnchor constant:22],
        [btn.centerXAnchor constraintEqualToAnchor:v.centerXAnchor],
        [btn.heightAnchor constraintEqualToConstant:44],

        [v.bottomAnchor constraintEqualToAnchor:btn.bottomAnchor],
    ]];
}

- (void)updateEmpty {
    BOOL empty = [RSStore shared].repos.count == 0;
    self.emptyView.hidden = !empty;
    self.table.hidden = empty;
}

#pragma mark - 操作

- (void)addTapped {
    RSAddRepoViewController *vc = [RSAddRepoViewController new];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)refreshAll {
    NSArray *repos = [[RSStore shared].repos copy];
    if (repos.count == 0) {
        [self.refreshCtrl endRefreshing];
        return;
    }
    __block NSInteger remaining = repos.count;
    for (RSRepo *r in repos) {
        [[RSStore shared] refreshRepo:r completion:^(BOOL ok, NSString *err) {
            remaining--;
            if (remaining <= 0) {
                [self.refreshCtrl endRefreshing];
                [self.table reloadData];
            }
        }];
    }
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [RSStore shared].repos.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 88;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    RSRepoCell *cell = [tableView dequeueReusableCellWithIdentifier:@"repo" forIndexPath:indexPath];
    RSRepo *repo = [RSStore shared].repos[indexPath.row];
    [cell configureWithRepo:repo];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    RSRepo *repo = [RSStore shared].repos[indexPath.row];

    if (repo.requiresUnlock && !repo.isUnlocked) {
        RSUnlockViewController *vc = [RSUnlockViewController new];
        vc.repo = repo;
        vc.modalPresentationStyle = UIModalPresentationPageSheet;
        __weak typeof(self) weakSelf = self;
        vc.onUnlocked = ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            // 解锁成功：刷新源并直接进入
            [[RSStore shared] refreshRepo:repo completion:^(BOOL ok, NSString *err) {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"RSReposChanged" object:nil];
            }];
            RSRepoDetailViewController *d = [RSRepoDetailViewController new];
            d.repo = repo;
            [self.navigationController pushViewController:d animated:YES];
        };
        [self presentViewController:vc animated:YES completion:nil];
        return;
    }

    RSRepoDetailViewController *vc = [RSRepoDetailViewController new];
    vc.repo = repo;
    [self.navigationController pushViewController:vc animated:YES];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    RSRepo *repo = [RSStore shared].repos[indexPath.row];

    UIContextualAction *del = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                      title:@"删除"
                                                                    handler:^(UIContextualAction *a, UIView *v, void (^done)(BOOL)) {
        [[RSStore shared] removeRepo:repo];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        [self updateEmpty];
        done(YES);
    }];
    del.backgroundColor = [UIColor colorWithRed:1 green:0.27 blue:0.27 alpha:1];

    UIContextualAction *refresh = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                          title:@"刷新"
                                                                        handler:^(UIContextualAction *a, UIView *v, void (^done)(BOOL)) {
        [[RSStore shared] refreshRepo:repo completion:^(BOOL ok, NSString *err) {
            [tableView reloadData];
            done(ok);
        }];
    }];
    refresh.backgroundColor = [RSTheme accent];

    return [UISwipeActionsConfiguration configurationWithActions:@[del, refresh]];
}

@end
