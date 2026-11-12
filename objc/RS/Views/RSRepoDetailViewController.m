#import "RSRepoDetailViewController.h"
#import "RSStore.h"
#import "RSTheme.h"
#import "RSAppCell.h"
#import "RSIconView.h"
#import "RSAppDetailViewController.h"

@interface RSRepoDetailViewController () <UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating>
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) NSArray<RSAppItem *> *filtered;
@property (nonatomic, strong) UISearchController *search;
@end

@implementation RSRepoDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.repo.name.length ? self.repo.name : @"源";
    self.view.backgroundColor = [RSTheme bg];

    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.table.translatesAutoresizingMaskIntoConstraints = NO;
    self.table.backgroundColor = [RSTheme bg];
    self.table.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.contentInset = UIEdgeInsetsMake(6, 0, 24, 0);
    // 让 cell 自适应高度（内容链两端已钉死），避免固定行高裁切 / 内容溢出遮挡
    self.table.rowHeight = UITableViewAutomaticDimension;
    self.table.estimatedRowHeight = 88;
    [self.table registerClass:[RSAppCell class] forCellReuseIdentifier:@"app"];
    [self.view addSubview:self.table];
    // 钉在安全区，避免被导航栏 / 搜索栏压住
    [NSLayoutConstraint activateConstraints:@[
        [self.table.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.table.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.table.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.table.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    self.search = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.search.searchResultsUpdater = self;
    self.search.obscuresBackgroundDuringPresentation = NO;
    self.search.searchBar.placeholder = @"搜索应用";
    self.search.searchBar.tintColor = [RSTheme accent];
    self.navigationItem.searchController = self.search;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;

    [self applyFilter:@""];

    if (self.repo.requiresUnlock && !self.repo.isUnlocked) {
        [self showLockedOverlay];
    }

    // 添加源后刷新是异步的，刷新完成会发 RSReposChanged。
    // 这里必须监听并重载，否则进源时看到的是空列表，要手动刷新一次才出内容。
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onReposChanged)
                                                 name:@"RSReposChanged"
                                               object:nil];
}

- (void)onReposChanged {
    [self applyFilter:(self.search.searchBar.text ?: @"")];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)showLockedOverlay {
    self.table.hidden = YES;

    UIView *v = [UIView new];
    v.translatesAutoresizingMaskIntoConstraints = NO;

    UIImageView *icon = [UIImageView new];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.image = [UIImage systemImageNamed:@"lock.fill"];
    icon.tintColor = [UIColor orangeColor];
    icon.contentMode = UIViewContentModeScaleAspectFit;

    UILabel *t = [UILabel new];
    t.translatesAutoresizingMaskIntoConstraints = NO;
    t.text = @"这个源需要解锁";
    t.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
    t.textColor = [UIColor whiteColor];
    t.textAlignment = NSTextAlignmentCenter;

    UILabel *s = [UILabel new];
    s.translatesAutoresizingMaskIntoConstraints = NO;
    s.text = @"回到源列表，点击该源输入解锁码";
    s.font = [UIFont systemFontOfSize:13];
    s.textColor = [RSTheme textSub];
    s.textAlignment = NSTextAlignmentCenter;

    [v addSubview:icon];
    [v addSubview:t];
    [v addSubview:s];
    [self.view addSubview:v];

    [NSLayoutConstraint activateConstraints:@[
        [v.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [v.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [v.widthAnchor constraintEqualToAnchor:self.view.widthAnchor constant:-60],
        [icon.centerXAnchor constraintEqualToAnchor:v.centerXAnchor],
        [icon.topAnchor constraintEqualToAnchor:v.topAnchor],
        [icon.widthAnchor constraintEqualToConstant:64],
        [icon.heightAnchor constraintEqualToConstant:64],
        [t.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:16],
        [t.leadingAnchor constraintEqualToAnchor:v.leadingAnchor],
        [t.trailingAnchor constraintEqualToAnchor:v.trailingAnchor],
        [s.topAnchor constraintEqualToAnchor:t.bottomAnchor constant:8],
        [s.leadingAnchor constraintEqualToAnchor:v.leadingAnchor],
        [s.trailingAnchor constraintEqualToAnchor:v.trailingAnchor],
        [v.bottomAnchor constraintEqualToAnchor:s.bottomAnchor],
    ]];
}

- (void)applyFilter:(NSString *)q {
    if (q.length == 0) {
        self.filtered = self.repo.apps;
    } else {
        NSMutableArray *m = [NSMutableArray array];
        for (RSAppItem *a in self.repo.apps) {
            BOOL hit = [a.name localizedCaseInsensitiveContainsString:q] ||
                       [a.bundleIdentifier localizedCaseInsensitiveContainsString:q] ||
                       [a.developerName localizedCaseInsensitiveContainsString:q];
            if (hit) [m addObject:a];
        }
        self.filtered = m;
    }
    [self.table reloadData];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    [self applyFilter:searchController.searchBar.text ?: @""];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filtered.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    RSAppCell *cell = [tableView dequeueReusableCellWithIdentifier:@"app" forIndexPath:indexPath];
    [cell configureWithItem:self.filtered[indexPath.row]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    RSAppDetailViewController *vc = [RSAppDetailViewController new];
    vc.item = self.filtered[indexPath.row];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
