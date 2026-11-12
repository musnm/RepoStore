#import <UIKit/UIKit.h>
#import "RSRepo.h"

NS_ASSUME_NONNULL_BEGIN

@interface RSRepoCell : UITableViewCell
- (void)configureWithRepo:(RSRepo *)repo;
@end

NS_ASSUME_NONNULL_END
