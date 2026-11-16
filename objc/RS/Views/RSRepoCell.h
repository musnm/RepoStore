#import <UIKit/UIKit.h>
@class RSRepo;

@interface RSRepoCell : UITableViewCell
- (void)configureWithRepo:(RSRepo *)repo;
@end
