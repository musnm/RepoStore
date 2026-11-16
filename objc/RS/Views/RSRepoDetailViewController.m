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
/// 当前选中的分类（为空表示全部）
@property (nonatomic, copy, nullable) NSString *selectedCategory;
@property (nonatomic, strong) UIScrollView *categoryBar;
/// 分类标签顺序，按钮 tag 即下标
@property (nonatomic, strong) NSArray<NSString *> *categoryTitles;
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
    [self buildCategoryBar];

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
    // 每次过滤都从 store 取最新的同一个源对象，
    // 避免刷新后 repo 实例被替换、这里还抱着旧快照导致列表空白。
    RSRepo *fresh = [[RSStore shared] repoWithUID:self.repo.uid];
    if (fresh) self.repo = fresh;

    NSArray<RSAppItem *> *all = self.repo.apps ?: @[];
    NSMutableArray *m = [NSMutableArray array];
    for (RSAppItem *a in all) {
        // 分类标签筛选（如果有选中）
        if (self.selectedCategory.length) {
            if (![[self categoryOfItem:a] isEqualToString:self.selectedCategory]) continue;
        }
        if (q.length == 0) {
            [m addObject:a];
            continue;
        }
        BOOL hit = [a.name localizedCaseInsensitiveContainsString:q] ||
                   [a.bundleIdentifier localizedCaseInsensitiveContainsString:q] ||
                   [a.developerName localizedCaseInsensitiveContainsString:q];
        if (hit) [m addObject:a];
    }
    self.filtered = m;
    [self.table reloadData];
}

/// 构建分类筛选条：把源里所有 Section 汇总成横向滚动的标签。
/// 分类来自 APT 的 Section 字段，是源自身声明的，Sileo 也按它分组。
- (void)buildCategoryBar {
    // 收集分类名 → 数量
    NSMutableDictionary<NSString *, NSNumber *> *tally = [NSMutableDictionary dictionary];
    for (RSAppItem *a in self.repo.apps) {
        NSString *c = [self categoryOfItem:a];
        if (c.length == 0) continue;
        tally[c] = @([tally[c] integerValue] + 1);
    }
    if (tally.count == 0) {
        self.table.tableHeaderView = nil;
        self.categoryTitles = @[];
        return;
    }

    // 按数量从多到少，主要分类排前面
    NSArray<NSString *> *cats = [tally.allKeys sortedArrayUsingComparator:
        ^NSComparisonResult(NSString *x, NSString *y) {
            NSInteger cx = [tally[x] integerValue], cy = [tally[y] integerValue];
            if (cx != cy) return cx > cy ? NSOrderedAscending : NSOrderedDescending;
            return [x compare:y];
        }];

    // 顺序表：第 0 项固定是"全部"，按钮 tag 即其下标
    NSMutableArray<NSString *> *titles = [NSMutableArray arrayWithObject:@"全部"];
    [titles addObjectsFromArray:cats];
    self.categoryTitles = titles;

    CGFloat width = self.view.bounds.size.width;
    CGFloat h = 44;

    UIScrollView *bar = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, width, h)];
    bar.showsHorizontalScrollIndicator = NO;
    bar.alwaysBounceHorizontal = YES;
    bar.backgroundColor = [RSTheme bg];

    CGFloat x = 12;
    for (NSUInteger i = 0; i < titles.count; i++) {
        NSString *t = titles[i];
        NSInteger cnt = (i == 0) ? (NSInteger)self.repo.apps.count
                                 : [tally[t] integerValue];
        BOOL sel = (i == 0) ? (self.selectedCategory.length == 0)
                            : [t isEqualToString:self.selectedCategory];

        UIButton *b = [self categoryButtonWithTitle:t count:cnt selected:sel];
        b.tag = (NSInteger)i;
        b.frame = CGRectMake(x, (h - 28) / 2.0, b.frame.size.width, 28);

        [bar addSubview:b];
        x += b.frame.size.width + 8;
    }

    bar.contentSize = CGSizeMake(MAX(x + 4, width), h);
    self.table.tableHeaderView = bar;   // 用 header 挂载，table 约束不必改
    self.categoryBar = bar;
}

/// 生成一个分类标签按钮
- (UIButton *)categoryButtonWithTitle:(NSString *)title
                                count:(NSInteger)count
                             selected:(BOOL)selected {
    NSString *txt = [NSString stringWithFormat:@"%@ %ld", title, (long)count];
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [b setTitle:txt forState:UIControlStateNormal];
    [b setTitleColor:selected ? [UIColor whiteColor] : [RSTheme textSub]
            forState:UIControlStateNormal];
    b.backgroundColor = selected ? [RSTheme accent]
                                 : [[UIColor whiteColor] colorWithAlphaComponent:0.08];
    b.layer.cornerRadius = 14;
    // 用 sizeToFit 得到文字尺寸后左右各留 12pt 内边距
    [b sizeToFit];
    CGRect bf = b.frame;
    bf.size.width += 24;
    bf.size.height = 28;
    b.frame = bf;

    [b addTarget:self action:@selector(onCategoryTap:)
        forControlEvents:UIControlEventTouchUpInside];
    return b;
}

- (void)onCategoryTap:(UIButton *)sender {
    if (sender.tag < 0 || sender.tag >= (NSInteger)self.categoryTitles.count) return;
    NSString *c = self.categoryTitles[sender.tag];
    self.selectedCategory = [c isEqualToString:@"全部"] ? nil : c;
    [self applyFilter:self.search.searchBar.text ?: @""];
    [self buildCategoryBar];
}

/// 取条目的分类名。APT 源的 Section 在解析时补进了描述（"分类：xxx"），
/// 这里再兜一层：优先用 categoryName，否则从描述里提取。
- (NSString *)categoryOfItem:(RSAppItem *)a {
    if (a.categoryName.length) return a.categoryName;
    NSString *d = a.localizedDescription ?: @"";
    NSRange r = [d rangeOfString:@"分类："];
    if (r.location != NSNotFound) {
        NSString *tail = [d substringFromIndex:r.location + r.length];
        NSRange nl = [tail rangeOfString:@"\n"];
        if (nl.location != NSNotFound) tail = [tail substringToIndex:nl.location];
        return [tail stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }
    return @"";
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
