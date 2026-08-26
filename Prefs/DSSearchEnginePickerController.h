#import <Preferences/PSViewController.h>
#import <UIKit/UIKit.h>

@interface DSSearchEnginePickerController : PSViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@end
