#import "RSAddRepoViewController.h"
#import "RSStore.h"
#import "RSTheme.h"
#import "RSDeobfuscator.h"

@interface RSAddRepoViewController ()
@property (nonatomic, strong) UITextField *urlField;
@property (nonatomic, strong) UITextField *codeField;
@property (nonatomic, strong) UIButton *addBtn;
@end

@implementation RSAddRepoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [RSTheme bg];
    self.title = @"添加软件源";

    self.navigationItem.leftBarButtonItem =
    [[UIBarButtonItem alloc] initWithTitle:@"取消" style:UIBarButtonItemStylePlain
                                    target:self action:@selector(cancel)];
    self.navigationItem.leftBarButtonItem.tintColor = [UIColor whiteColor];

    [self buildUI];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self.urlField becomeFirstResponder];
    });
}

- (void)cancel { [self dismissViewControllerAnimated:YES completion:nil]; }

- (UILabel *)labelWithText:(NSString *)text {
    UILabel *l = [UILabel new];
    l.translatesAutoresizingMaskIntoConstraints = NO;
    l.text = text;
    l.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    l.textColor = [RSTheme textSub];
    return l;
}

- (UITextField *)fieldWithPlaceholder:(NSString *)ph secure:(BOOL)secure {
    UITextField *f = [UITextField new];
    f.translatesAutoresizingMaskIntoConstraints = NO;
    f.placeholder = ph;
    f.textColor = [UIColor whiteColor];
    f.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular];
    f.backgroundColor = [RSTheme card2];
    f.layer.cornerRadius = 14;
    f.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 14, 1)];
    f.leftViewMode = UITextFieldViewModeAlways;
    f.attributedPlaceholder =
    [[NSAttributedString alloc] initWithString:ph
                                    attributes:@{NSForegroundColorAttributeName:
                                                     [[UIColor whiteColor] colorWithAlphaComponent:0.3]}];
    if (secure) {
        f.secureTextEntry = YES;
        f.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
        f.autocorrectionType = UITextAutocorrectionTypeNo;
    } else {
        f.keyboardType = UIKeyboardTypeURL;
        f.autocapitalizationType = UITextAutocapitalizationTypeNone;
        f.autocorrectionType = UITextAutocorrectionTypeNo;
    }
    [f addTarget:self action:@selector(textChanged) forControlEvents:UIControlEventEditingChanged];
    return f;
}

- (void)buildUI {
    UIView *root = self.view;

    UIView *headIcon = [UIView new];
    headIcon.translatesAutoresizingMaskIntoConstraints = NO;
    headIcon.backgroundColor = [RSTheme accent];
    headIcon.layer.cornerRadius = 18;
    UIImageView *iv = [UIImageView new];
    iv.translatesAutoresizingMaskIntoConstraints = NO;
    iv.image = [UIImage systemImageNamed:@"link.badge.plus"];
    iv.tintColor = [UIColor whiteColor];
    iv.contentMode = UIViewContentModeScaleAspectFit;
    [headIcon addSubview:iv];

    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"添加软件源";
    title.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
    title.textColor = [UIColor whiteColor];
    title.textAlignment = NSTextAlignmentCenter;

    UILabel *sub = [UILabel new];
    sub.translatesAutoresizingMaskIntoConstraints = NO;
    sub.text = @"粘贴源地址或加密源串，支持 JSON / ESign 格式";
    sub.font = [UIFont systemFontOfSize:13];
    sub.textColor = [RSTheme textSub];
    sub.textAlignment = NSTextAlignmentCenter;

    UILabel *urlTip = [self labelWithText:@"源地址"];
    self.urlField = [self fieldWithPlaceholder:@"https://example.com/repo.json" secure:NO];

    UILabel *codeTip = [self labelWithText:@"解锁码（选填）"];
    self.codeField = [self fieldWithPlaceholder:@"如果该源需要解锁，在这里输入" secure:YES];

    self.addBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.addBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.addBtn setTitle:@"添加" forState:UIControlStateNormal];
    [self.addBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.addBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.addBtn.backgroundColor = [RSTheme card2];
    self.addBtn.layer.cornerRadius = 15;
    self.addBtn.enabled = NO;
    [self.addBtn addTarget:self action:@selector(add) forControlEvents:UIControlEventTouchUpInside];

    for (UIView *v in @[headIcon, title, sub, urlTip, self.urlField,
                        codeTip, self.codeField, self.addBtn]) {
        [root addSubview:v];
    }

    UILayoutGuide *g = root.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [headIcon.topAnchor constraintEqualToAnchor:g.topAnchor constant:28],
        [headIcon.centerXAnchor constraintEqualToAnchor:root.centerXAnchor],
        [headIcon.widthAnchor constraintEqualToConstant:72],
        [headIcon.heightAnchor constraintEqualToConstant:72],
        [iv.centerXAnchor constraintEqualToAnchor:headIcon.centerXAnchor],
        [iv.centerYAnchor constraintEqualToAnchor:headIcon.centerYAnchor],
        [iv.widthAnchor constraintEqualToConstant:34],
        [iv.heightAnchor constraintEqualToConstant:34],

        [title.topAnchor constraintEqualToAnchor:headIcon.bottomAnchor constant:15],
        [title.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:24],
        [title.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-24],

        [sub.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:6],
        [sub.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:24],
        [sub.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-24],

        [urlTip.topAnchor constraintEqualToAnchor:sub.bottomAnchor constant:30],
        [urlTip.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:24],

        [self.urlField.topAnchor constraintEqualToAnchor:urlTip.bottomAnchor constant:8],
        [self.urlField.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:24],
        [self.urlField.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-24],
        [self.urlField.heightAnchor constraintEqualToConstant:50],

        [codeTip.topAnchor constraintEqualToAnchor:self.urlField.bottomAnchor constant:20],
        [codeTip.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:24],

        [self.codeField.topAnchor constraintEqualToAnchor:codeTip.bottomAnchor constant:8],
        [self.codeField.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:24],
        [self.codeField.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-24],
        [self.codeField.heightAnchor constraintEqualToConstant:50],

        [self.addBtn.topAnchor constraintEqualToAnchor:self.codeField.bottomAnchor constant:28],
        [self.addBtn.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:24],
        [self.addBtn.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-24],
        [self.addBtn.heightAnchor constraintEqualToConstant:52],
    ]];
}

- (void)textChanged {
    BOOL has = self.urlField.text.length > 0;
    self.addBtn.enabled = has;
    self.addBtn.backgroundColor = has ? [RSTheme accent] : [RSTheme card2];
}

- (void)add {
    NSString *raw = [self.urlField.text stringByTrimmingCharactersInSet:
                     [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (raw.length == 0) return;

    RSRepo *repo = nil;

    // ① 用户粘贴的是加密源串（source[...] / base64 / 多行明文）
    if ([RSDeobfuscator looksLikeEncodedSource:raw]) {
        NSArray<NSString *> *lines = [RSDeobfuscator decodeSource:raw];
        NSString *realURL = nil;
        for (NSString *l in lines) {
            NSString *t = [l stringByTrimmingCharactersInSet:
                           [NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (t.length == 0) continue;
            // 取第一条像 URL 的，或直接是 JSON 的
            if ([t.lowercaseString hasPrefix:@"http"]) { realURL = t; break; }
            if ([t hasPrefix:@"{"]) {
                // 直接是内联 JSON 源：落盘成缓存再由 store 载入
                realURL = [self inlineSourceURLForJSON:t];
                break;
            }
        }
        if (!realURL && lines.count > 0) {
            NSString *t = [lines.firstObject stringByTrimmingCharactersInSet:
                           [NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([t.lowercaseString hasPrefix:@"http"]) realURL = t;
        }
        if (!realURL) {
            [self alert:@"无法识别"
              message:@"解码成功，但里面没有找到有效的源地址。"];
            return;
        }
        raw = realURL;
    }

    NSString *u = raw;
    if (![u.lowercaseString hasPrefix:@"http"] && ![u.lowercaseString hasPrefix:@"file://"]) {
        u = [@"https://" stringByAppendingString:u];
    }

    repo = [[RSStore shared] addRepoWithURL:u];
    if (repo) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"RSReposChanged" object:nil];
        [[RSStore shared] refreshRepo:repo completion:^(BOOL ok, NSString *err) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"RSReposChanged" object:nil];
        }];
    }

    NSString *code = [self.codeField.text stringByTrimmingCharactersInSet:
                      [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    [self dismissViewControllerAnimated:YES completion:nil];

    if (repo && code.length > 0) {
        [[RSStore shared] unlockRepo:repo code:code completion:^(BOOL ok, NSString *msg) {}];
    }
}

/// 把内联 JSON 源写成临时文件，返回 file:// URL
- (nullable NSString *)inlineSourceURLForJSON:(NSString *)json {
    NSString *dir = NSTemporaryDirectory();
    NSString *name = [NSString stringWithFormat:@"inline-%u.json",
                      (unsigned)arc4random()];
    NSString *path = [dir stringByAppendingPathComponent:name];
    NSError *err = nil;
    [json writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&err];
    if (err) return nil;
    return [@"file://" stringByAppendingString:path];
}

- (void)alert:(NSString *)title message:(NSString *)msg {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title
                                                              message:msg
                                                       preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

@end
