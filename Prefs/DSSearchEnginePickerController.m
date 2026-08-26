#import "DSSearchEnginePickerController.h"
#import <Cephei/HBPreferences.h>
#import <notify.h>

// Ported from the original DockSearch (Ginsu)
@implementation DSSearchEnginePickerController {
    HBPreferences *_preferences;
}

- (id)init {
    if (self = [super init]) {
        _preferences = [[HBPreferences alloc] initWithIdentifier: @"com.brkr1.tweaks.docksearchreborn.hbprefs"];

        _tableView = [[UITableView alloc] initWithFrame: UIScreen.mainScreen.bounds style: UITableViewStyleInsetGrouped];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.allowsSelection = YES;
        _tableView.allowsMultipleSelection = NO;
        self.view = _tableView;
    }

    return self;
}

- (NSString *)title {
    return @"Select Search Engine";
}

- (NSMutableArray *)searchEngines {
    NSMutableArray *arr = [[NSMutableArray alloc] init];
    [arr addObjectsFromArray: @[@"Google",
                               @"BaiDu",
                               @"Bing",
                               @"Yahoo",
                               @"DuckDuckGo",
                               @"YouTube"]];
    return arr;
}

- (NSMutableArray *)searchEnginePrefixes {
    NSMutableArray *arr = [[NSMutableArray alloc] init];
    [arr addObjectsFromArray: @[@"https://www.google.com/search?q=",
                               @"https://www.baidu.com/s?wd=",
                               @"https://www.bing.com/search?q=",
                               @"https://au.search.yahoo.com/search?p=",
                               @"https://duckduckgo.com/?q=",
                               @"youtube:///results?q="]];
    return arr;
}

- (UITableViewCell *)tableView: (UITableView *)tableView cellForRowAtIndexPath: (NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: @"Cell"];

    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle: UITableViewCellStyleSubtitle reuseIdentifier: @"Cell"];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    cell.textLabel.text = [[self searchEngines] objectAtIndex: indexPath.row];
    cell.detailTextLabel.text = [[self searchEnginePrefixes] objectAtIndex: indexPath.row];

    NSString *currentPrefix = [_preferences objectForKey: @"searchPrefix"] ?: @"https://www.google.com/search?q=";
    if ([cell.detailTextLabel.text isEqualToString: currentPrefix]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }

    return cell;
}

- (NSInteger)tableView: (UITableView *)tableView numberOfRowsInSection: (NSInteger)section {
    return [[self searchEngines] count];
}

- (void)tableView: (UITableView *)tableView didSelectRowAtIndexPath: (NSIndexPath *)indexPath {
    for (UITableViewCell *cell in tableView.visibleCells) {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }

    UITableViewCell *selectedCell = [tableView cellForRowAtIndexPath: indexPath];
    selectedCell.accessoryType = UITableViewCellAccessoryCheckmark;

    [_preferences setObject: selectedCell.detailTextLabel.text forKey: @"searchPrefix"];
    notify_post("com.brkr1.tweaks.docksearchreborn.hbprefs/ReloadPrefs");
}

- (void)tableView: (UITableView *)tableView didHighlightRowAtIndexPath: (NSIndexPath *)indexPath {
    UITableViewCell *highlightedCell = [tableView cellForRowAtIndexPath: indexPath];
    [highlightedCell setHighlighted: NO animated: YES];
}

@end
