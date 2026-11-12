#import "RSUnlockViewController.h"
#import "RSStore.h"
#import "RSTheme.h"
#import "RSIconView.h"

@interface RSUnlockViewController ()
@property (nonatomic, strong) UITextField *codeField;
@property (nonatomic, strong) UIButton *eyeBtn;
@property (nonatomic, strong) UIButton *submitBtn;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, assign) BOOL reveal;
@end

@implementation RSUnlockViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [RSTheme bg];
    self.title = @"解锁源";

    self.navigationItem.leftBarButtonItem =
    [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStylePlain
                                    target:self action:@selector(close)];
    self.navigationItem.leftBarButtonItem.tintColor = [UIColor whiteColor];

    [self buildUI];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self.codeField becomeFirstResponder];
    });
}

- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }

- (void)buildUI {
    UIView *root = self.view;

    RSIconView *icon = [RSIconView new];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [icon configureWithURL:self.repo.iconURL
                     seed:(self.repo.name.length ? self.repo.name : self.repo.url)
             cornerRadius:16];

    UILabel *name = [UILabel new];
    name.translatesAutoresizingMaskIntoConstraints = NO;
    name.text = self.repo.name.length ? self.repo.name : @"此软件源";
    name.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    name.textColor = [UIColor whiteColor];
    name.textAlignment = NSTextAlignmentCenter;

    UILabel *urlLabel = [UILabel new];
    urlLabel.translatesAutoresizingMaskIntoConstraints = NO;
    urlLabel.text = self.repo.url;
    urlLabel.font = [UIFont systemFontOfSize:11];
    urlLabel.textColor = [RSTheme textSub];
    urlLabel.textAlignment = NSTextAlignmentCenter;
    urlLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;

    UILabel *tip = [UILabel new];
    tip.translatesAutoresizingMaskIntoConstraints = NO;
    tip.text = @"解锁码";
    tip.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    tip.textColor = [RSTheme textSub];

    self.codeField = [UITextField new];
    self.codeField.translatesAutoresizingMaskIntoConstraints = NO;
    self.codeField.placeholder = @"请输入解锁码";
    self.codeField.textColor = [UIColor whiteColor];
    self.codeField.font = [UIFont monospacedSystemFontOfSize:16 weight:UIFontWeightRegular];
    self.codeField.backgroundColor = [RSTheme card2];
    self.codeField.layer.cornerRadius = 14;
    self.codeField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.codeField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.codeField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 14, 1)];
    self.codeField.leftViewMode = UITextFieldViewModeAlways;
    self.codeField.returnKeyType = UIReturnKeyGo;
    [self.codeField addTarget:self action:@selector(submit) forControlEvents:UIControlEventEditingDidEndOnExit];
    self.codeField.attributedPlaceholder =
    [[NSAttributedString alloc] initWithString:@"请输入解锁码"
                                    attributes:@{NSForegroundColorAttributeName:
                                                     [[UIColor whiteColor] colorWithAlphaComponent:0.3]}];

    self.eyeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.eyeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.eyeBtn setImage:[UIImage systemImageNamed:@"eye.fill"] forState:UIControlStateNormal];
    self.eyeBtn.tintColor = [RSTheme textSub];
    self.eyeBtn.backgroundColor = [RSTheme card2];
    self.eyeBtn.layer.cornerRadius = 14;
    [self.eyeBtn addTarget:self action:@selector(toggleEye) forControlEvents:UIControlEventTouchUpInside];

    self.errorLabel = [UILabel new];
    self.errorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.errorLabel.font = [UIFont systemFontOfSize:12];
    self.errorLabel.textColor = [UIColor colorWithRed:1 green:0.3 blue:0.3 alpha:1];
    self.errorLabel.numberOfLines = 0;
    self.errorLabel.hidden = YES;

    self.submitBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.submitBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.submitBtn setTitle:@"解锁" forState:UIControlStateNormal];
    [self.submitBtn setImage:[UIImage systemImageNamed:@"key.fill"] forState:UIControlStateNormal];
    [self.submitBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.submitBtn.tintColor = [UIColor whiteColor];
    self.submitBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.submitBtn.backgroundColor = [RSTheme accent];
    self.submitBtn.layer.cornerRadius = 15;
    self.submitBtn.imageEdgeInsets = UIEdgeInsetsMake(0, -6, 0, 6);
    [self.submitBtn addTarget:self action:@selector(submit) forControlEvents:UIControlEventTouchUpInside];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.spinner.color = [UIColor whiteColor];
    self.spinner.hidesWhenStopped = YES;
    [self.submitBtn addSubview:self.spinner];

    UILabel *note = [UILabel new];
    note.translatesAutoresizingMaskIntoConstraints = NO;
    note.text = @"解锁码请向源作者获取，不要公开分享";
    note.font = [UIFont systemFontOfSize:11];
    note.textColor = [[RSTheme textSub] colorWithAlphaComponent:0.8];
    note.textAlignment = NSTextAlignmentCenter;

    for (UIView *v in @[icon, name, urlLabel, tip, self.codeField, self.eyeBtn,
                        self.errorLabel, self.submitBtn, note]) {
        [root addSubview:v];
    }

    UILayoutGuide *g = root.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [icon.topAnchor constraintEqualToAnchor:g.topAnchor constant:26],
        [icon.centerXAnchor constraintEqualToAnchor:root.centerXAnchor],
        [icon.widthAnchor constraintEqualToConstant:70],
        [icon.heightAnchor constraintEqualToConstant:70],

        [name.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:13],
        [name.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:24],
        [name.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-24],

        [urlLabel.topAnchor constraintEqualToAnchor:name.bottomAnchor constant:5],
        [urlLabel.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:24],
        [urlLabel.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-24],

        [tip.topAnchor constraintEqualToAnchor:urlLabel.bottomAnchor constant:24],
        [tip.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:24],

        [self.codeField.topAnchor constraintEqualToAnchor:tip.bottomAnchor constant:8],
        [self.codeField.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:24],
        [self.codeField.heightAnchor constraintEqualToConstant:50],

        [self.eyeBtn.leadingAnchor constraintEqualToAnchor:self.codeField.trailingAnchor constant:9],
        [self.eyeBtn.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-24],
        [self.eyeBtn.centerYAnchor constraintEqualToAnchor:self.codeField.centerYAnchor],
        [self.eyeBtn.widthAnchor constraintEqualToConstant:50],
        [self.eyeBtn.heightAnchor constraintEqualToConstant:50],

        [self.errorLabel.topAnchor constraintEqualToAnchor:self.codeField.bottomAnchor constant:9],
        [self.errorLabel.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:26],
        [self.errorLabel.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-24],

        [self.submitBtn.topAnchor constraintEqualToAnchor:self.errorLabel.bottomAnchor constant:16],
        [self.submitBtn.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:24],
        [self.submitBtn.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-24],
        [self.submitBtn.heightAnchor constraintEqualToConstant:52],

        [self.spinner.centerXAnchor constraintEqualToAnchor:self.submitBtn.centerXAnchor],
        [self.spinner.centerYAnchor constraintEqualToAnchor:self.submitBtn.centerYAnchor],

        [note.topAnchor constraintEqualToAnchor:self.submitBtn.bottomAnchor constant:14],
        [note.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:24],
        [note.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-24],
    ]];
}

- (void)toggleEye {
    self.reveal = !self.reveal;
    self.codeField.secureTextEntry = !self.reveal;
    [self.eyeBtn setImage:[UIImage systemImageNamed:(self.reveal ? @"eye.slash.fill" : @"eye.fill")]
                 forState:UIControlStateNormal];
}

- (void)submit {
    NSString *code = [self.codeField.text stringByTrimmingCharactersInSet:
                      [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (code.length == 0) return;

    self.errorLabel.hidden = YES;
    self.submitBtn.enabled = NO;
    self.submitBtn.backgroundColor = [RSTheme card2];
    [self.spinner startAnimating];

    __weak typeof(self) weakSelf = self;
    [[RSStore shared] unlockRepo:self.repo code:code completion:^(BOOL ok, NSString *message) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            self.submitBtn.enabled = YES;
            self.submitBtn.backgroundColor = [RSTheme accent];
            [self.spinner stopAnimating];

            if (ok) {
                UINotificationFeedbackGenerator *fb = [UINotificationFeedbackGenerator new];
                [fb notificationOccurred:UINotificationFeedbackTypeSuccess];
                void (^after)(void) = self.onUnlocked;
                [self dismissViewControllerAnimated:YES completion:^{
                    if (after) after();
                }];
            } else {
                UINotificationFeedbackGenerator *fb = [UINotificationFeedbackGenerator new];
                [fb notificationOccurred:UINotificationFeedbackTypeError];
                self.errorLabel.hidden = NO;
                self.errorLabel.text = message.length ? message : @"解锁码无效";
            }
        });
    }];
}

@end
