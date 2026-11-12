#import "RSAppCell.h"
#import "RSTheme.h"
#import "RSIconView.h"

@interface RSAppCell ()
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) RSIconView *icon;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *bidLabel;
@property (nonatomic, strong) UILabel *metaLabel;
@property (nonatomic, strong) UIImageView *dlIcon;
@end

@implementation RSAppCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _card = [UIView new];
        _card.backgroundColor = [RSTheme card];
        _card.layer.cornerRadius = 18;
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
        _nameLabel.numberOfLines = 1;
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_nameLabel];

        _bidLabel = [UILabel new];
        _bidLabel.font = [UIFont systemFontOfSize:11];
        _bidLabel.textColor = [RSTheme textSub];
        _bidLabel.numberOfLines = 1;
        _bidLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        _bidLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_bidLabel];

        _metaLabel = [UILabel new];
        _metaLabel.font = [UIFont systemFontOfSize:11];
        _metaLabel.textColor = [RSTheme textSub];
        _metaLabel.numberOfLines = 1;
        _metaLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_metaLabel];

        _dlIcon = [UIImageView new];
        _dlIcon.image = [UIImage systemImageNamed:@"arrow.down.circle"];
        _dlIcon.tintColor = [RSTheme accent];
        _dlIcon.contentMode = UIViewContentModeScaleAspectFit;
        _dlIcon.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_dlIcon];

        // ---- 布局：内容链两端都钉死，让 cell 自适应高度，绝不溢出卡片 ----
        [NSLayoutConstraint activateConstraints:@[
            // 卡片：上下留 5，左右留 16
            [_card.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:5],
            [_card.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5],
            [_card.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_card.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],

            // 图标：左边，垂直居中，固定 50
            [_icon.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:12],
            [_icon.centerYAnchor constraintEqualToAnchor:_card.centerYAnchor],
            [_icon.widthAnchor constraintEqualToConstant:50],
            [_icon.heightAnchor constraintEqualToConstant:50],
            // 图标不能决定卡片高度（否则和文字冲突），只要求不超出
            [_icon.topAnchor constraintGreaterThanOrEqualToAnchor:_card.topAnchor constant:10],
            [_icon.bottomAnchor constraintLessThanOrEqualToAnchor:_card.bottomAnchor constant:-10],

            // 右侧下载图标
            [_dlIcon.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-13],
            [_dlIcon.centerYAnchor constraintEqualToAnchor:_card.centerYAnchor],
            [_dlIcon.widthAnchor constraintEqualToConstant:22],
            [_dlIcon.heightAnchor constraintEqualToConstant:22],

            // 文字块左边界
            [_nameLabel.leadingAnchor constraintEqualToAnchor:_icon.trailingAnchor constant:11],
            [_nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_dlIcon.leadingAnchor constant:-10],
            [_bidLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_bidLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_dlIcon.leadingAnchor constant:-10],
            [_metaLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_metaLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_dlIcon.leadingAnchor constant:-10],

            // 关键：文字三行形成垂直链，且顶端/底端都钉住卡片
            [_nameLabel.topAnchor constraintEqualToAnchor:_card.topAnchor constant:14],
            [_bidLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:2],
            [_metaLabel.topAnchor constraintEqualToAnchor:_bidLabel.bottomAnchor constant:3],
            [_metaLabel.bottomAnchor constraintEqualToAnchor:_card.bottomAnchor constant:-14],
        ]];
    }
    return self;
}

- (void)configureWithItem:(RSAppItem *)item {
    [_icon configureWithURL:item.iconURL seed:item.name cornerRadius:12];
    _nameLabel.text = item.name;
    _bidLabel.text = item.bundleIdentifier;

    // 版本 + 大小合并成一行，避免三行叠加挤爆卡片
    NSString *ver = item.version.length ? [NSString stringWithFormat:@"v%@", item.version] : @"";
    NSString *size = item.sizeText.length ? item.sizeText : nil;

    if (!item.isDownloadable) {
        _dlIcon.image = [UIImage systemImageNamed:@"megaphone"];
        _dlIcon.tintColor = [RSTheme textSub];
        _metaLabel.text = size ? [NSString stringWithFormat:@"%@  ·  公告 / 通知", size] : @"公告 / 通知";
    } else {
        _dlIcon.image = [UIImage systemImageNamed:@"arrow.down.circle"];
        _dlIcon.tintColor = [RSTheme accent];
        if (ver.length && size.length) {
            _metaLabel.text = [NSString stringWithFormat:@"%@  ·  %@", ver, size];
        } else if (ver.length) {
            _metaLabel.text = ver;
        } else {
            _metaLabel.text = size ?: @"大小未知";
        }
    }
}

@end
