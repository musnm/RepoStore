#import <UIKit/UIKit.h>
#import "RSAppItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface RSAppCell : UITableViewCell
- (void)configureWithItem:(RSAppItem *)item;
@end

NS_ASSUME_NONNULL_END
