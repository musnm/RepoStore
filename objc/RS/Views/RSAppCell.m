#import "RSAppCell.h"
#import "RSTheme.h"
#import "RSIconView.h"

@interface RSAppCell ()
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) RSIconView *icon;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *bidLabel;
@property (nonatomic, strong) UILabel *verLabel;
@property (nonatomic, strong) UILabel *sizeLabel;
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
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_nameLabel];

        _bidLabel = [UILabel new];
        _bidLabel.font = [UIFont systemFontOfSize:11];
        _bidLabel.textColor = [RSTheme textSub];
        _bidLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_bidLabel];

        _verLabel = [UILabel new];
        _verLabel.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightSemibold];
        _verLabel.textColor = [RSTheme accent];
        _verLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_verLabel];

        _sizeLabel = [UILabel new];
        _sizeLabel.font = [UIFont systemFontOfSize:10];
        _sizeLabel.textColor = [RSTheme textSub];
        _sizeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_sizeLabel];

        _dlIcon = [UIImageView new];
        _dlIcon.image = [UIImage systemImageNamed:@"arrow.down.circle"];
        _dlIcon.tintColor = [RSTheme accent];
        _dlIcon.contentMode = UIViewContentModeScaleAspectFit;
        _dlIcon.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_dlIcon];

        [NSLayoutConstraint activateConstraints:@[
            [_card.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:5],
            [_card.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5],
            [_card.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_card.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],

            [_icon.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:12],
            [_icon.centerYAnchor constraintEqualToAnchor:_card.centerYAnchor],
            [_icon.widthAnchor constraintEqualToConstant:50],
            [_icon.heightAnchor constraintEqualToConstant:50],

            [_nameLabel.leadingAnchor constraintEqualToAnchor:_icon.trailingAnchor constant:11],
            [_nameLabel.topAnchor constraintEqualToAnchor:_card.topAnchor constant:13],
            [_nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_dlIcon.leadingAnchor constant:-8],

            [_bidLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_bidLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:2],
            [_bidLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_dlIcon.leadingAnchor constant:-8],

            [_verLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_verLabel.topAnchor constraintEqualToAnchor:_bidLabel.bottomAnchor constant:3],

            [_sizeLabel.leadingAnchor constraintEqualToAnchor:_verLabel.trailingAnchor constant:7],
            [_sizeLabel.centerYAnchor constraintEqualToAnchor:_verLabel.centerYAnchor],

            [_dlIcon.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-13],
            [_dlIcon.centerYAnchor constraintEqualToAnchor:_card.centerYAnchor],
            [_dlIcon.widthAnchor constraintEqualToConstant:22],
            [_dlIcon.heightAnchor constraintEqualToConstant:22],
        ]];
    }
    return self;
}

- (void)configureWithItem:(RSAppItem *)item {
    [_icon configureWithURL:item.iconURL seed:item.name cornerRadius:12];
    _nameLabel.text = item.name;
    _bidLabel.text = item.bundleIdentifier;
    _verLabel.text = item.version.length ? [NSString stringWithFormat:@"v%@", item.version] : @"";
    _sizeLabel.text = item.sizeText;
}

@end
