#import "RSRepoCell.h"
#import "RSTheme.h"
#import "RSIconView.h"

@interface RSRepoCell ()
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) RSIconView *icon;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *subLabel;
@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) UIImageView *lockView;
@property (nonatomic, strong) UIImageView *chevron;
@end

@implementation RSRepoCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _card = [UIView new];
        _card.backgroundColor = [RSTheme card];
        _card.layer.cornerRadius = 20;
        _card.layer.cornerCurve = kCACornerCurveContinuous;
        _card.layer.borderWidth = 1.0;
        _card.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.06].CGColor;
        _card.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_card];

        _icon = [RSIconView new];
        _icon.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_icon];

        _nameLabel = [UILabel new];
        _nameLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        _nameLabel.textColor = [UIColor whiteColor];
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_nameLabel];

        _lockView = [UIImageView new];
        _lockView.tintColor = [UIColor orangeColor];
        _lockView.contentMode = UIViewContentModeScaleAspectFit;
        _lockView.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_lockView];

        _subLabel = [UILabel new];
        _subLabel.font = [UIFont systemFontOfSize:12];
        _subLabel.textColor = [RSTheme textSub];
        _subLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_subLabel];

        _countLabel = [UILabel new];
        _countLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        _countLabel.textColor = [RSTheme textSub];
        _countLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_countLabel];

        _chevron = [UIImageView new];
        _chevron.image = [UIImage systemImageNamed:@"chevron.right"];
        _chevron.tintColor = [[RSTheme textSub] colorWithAlphaComponent:0.6];
        _chevron.contentMode = UIViewContentModeScaleAspectFit;
        _chevron.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_chevron];

        [NSLayoutConstraint activateConstraints:@[
            [_card.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:5],
            [_card.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5],
            [_card.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_card.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],

            [_icon.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:14],
            [_icon.centerYAnchor constraintEqualToAnchor:_card.centerYAnchor],
            [_icon.widthAnchor constraintEqualToConstant:54],
            [_icon.heightAnchor constraintEqualToConstant:54],

            [_nameLabel.leadingAnchor constraintEqualToAnchor:_icon.trailingAnchor constant:12],
            [_nameLabel.topAnchor constraintEqualToAnchor:_icon.topAnchor constant:2],

            [_lockView.leadingAnchor constraintEqualToAnchor:_nameLabel.trailingAnchor constant:5],
            [_lockView.centerYAnchor constraintEqualToAnchor:_nameLabel.centerYAnchor],
            [_lockView.widthAnchor constraintEqualToConstant:11],
            [_lockView.heightAnchor constraintEqualToConstant:11],

            [_subLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_subLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:3],
            [_subLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_chevron.leadingAnchor constant:-8],

            [_countLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_countLabel.topAnchor constraintEqualToAnchor:_subLabel.bottomAnchor constant:4],
            [_countLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_chevron.leadingAnchor constant:-8],

            [_chevron.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-14],
            [_chevron.centerYAnchor constraintEqualToAnchor:_card.centerYAnchor],
            [_chevron.widthAnchor constraintEqualToConstant:12],
            [_chevron.heightAnchor constraintEqualToConstant:18],
        ]];
    }
    return self;
}

- (void)configureWithRepo:(RSRepo *)repo {
    NSString *seed = repo.name.length ? repo.name : repo.url;
    [_icon configureWithURL:repo.iconURL seed:seed cornerRadius:13];

    _nameLabel.text = repo.name.length ? repo.name : @"未命名源";
    _subLabel.text = repo.subtitle.length ? repo.subtitle : repo.url;
    _countLabel.text = [NSString stringWithFormat:@"%lu 个应用", (unsigned long)repo.apps.count];

    if (repo.requiresUnlock) {
        _lockView.hidden = NO;
        _lockView.image = [UIImage systemImageNamed:(repo.isUnlocked ? @"lock.open.fill" : @"lock.fill")];
        _lockView.tintColor = repo.isUnlocked ? [RSTheme accent] : [UIColor orangeColor];
    } else {
        _lockView.hidden = YES;
    }
}

@end
