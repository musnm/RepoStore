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
