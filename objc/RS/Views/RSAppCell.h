#import <UIKit/UIKit.h>
@class RSAppItem;

@interface RSAppCell : UITableViewCell
- (void)configureWithItem:(RSAppItem *)item;
@end
