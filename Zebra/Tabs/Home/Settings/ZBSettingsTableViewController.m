//
//  SettingsTableViewController.m
//  Zebra
//
//  Created by midnightchips on 6/22/19.
//  Copyright © 2019 Wilson Styres. All rights reserved.
//

#import "ZBSettingsTableViewController.h"

enum ZBInfoOrder {
    ZBBugs
};

enum ZBUIOrder {
    ZBChangeTint,
    ZBOledSwitch,
    ZBChangeIcon
};

enum ZBAdvancedOrder {
    ZBDropTables,
    ZBOpenDocs,
    ZBClearImageCache,
    ZBClearKeychain
};

enum ZBSectionOrder {
    ZBInfo,
    ZBGraphics,
    ZBAdvanced
};

@interface ZBSettingsTableViewController () {
    NSMutableDictionary *_colors;
    ZBTintSelection selectedSortingType;
}

@end

@implementation ZBSettingsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = @"设置";
    self.headerView.image = [UIImage imageNamed:@"banner"];
    self.headerView.clipsToBounds = YES;
    [self.tableView setBackgroundColor:[UIColor tableViewBackgroundColor]];
    [self configureNavBar];
    [self configureTitleLabel];
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    [self configureSelectedTint];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:YES];
    [self.tableView reloadData];
    [self.tableView setSeparatorColor:[UIColor cellSeparatorColor]];
    [self configureNavBar];
}

- (void)configureSelectedTint {
    NSNumber *number = [[NSUserDefaults standardUserDefaults] objectForKey:@"tintSelection"];
    if (number) {
        selectedSortingType = (ZBTintSelection)[number integerValue];
    } else {
        selectedSortingType = ZBDefaultTint;
    }
}

- (void)configureNavBar {
    [self.navigationController.navigationBar setBackgroundColor:[UIColor tableViewBackgroundColor]];
    [self.navigationController.navigationBar setBarTintColor:[UIColor tableViewBackgroundColor]];
    [self.navigationController.navigationBar setShadowImage:[UIImage new]];
    //[self.navigationController.navigationBar setTranslucent:YES];
    //[self.navigationController.navigationBar setBarStyle:[ZBDevice darkModeEnabled] ? UIBarStyleBlack : UIBarStyleDefault];
    [self.navigationController.navigationBar setTintColor:[UIColor tintColor]];
    [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor cellPrimaryTextColor]}];
}

- (void)configureTitleLabel {
    NSString *versionString = [NSString stringWithFormat:@"版本: %@", PACKAGE_VERSION];
    NSMutableAttributedString *titleString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"斑马\n%@", versionString]];
    [titleString addAttributes:@{NSFontAttributeName : [UIFont fontWithName:@".SFUIDisplay-Medium" size:36], NSForegroundColorAttributeName: [UIColor whiteColor]} range:NSMakeRange(0,5)];
    [titleString addAttributes:@{NSFontAttributeName : [UIFont fontWithName:@".SFUIDisplay-Medium" size:26], NSForegroundColorAttributeName: [[UIColor whiteColor] colorWithAlphaComponent:0.85]} range:[titleString.string rangeOfString:versionString]];
    [self.titleLabel setAttributedText:titleString];
    [self.titleLabel setTextAlignment:NSTextAlignmentNatural];
    [self.titleLabel setNumberOfLines:0];
    [self.titleLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
    self.titleLabel.layer.shouldRasterize = YES;
    self.titleLabel.layer.shadowColor = [UIColor blackColor].CGColor;
    self.titleLabel.layer.shadowOffset = CGSizeMake(0.0, 0.0);
    self.titleLabel.layer.shadowRadius = 10.0;
    self.titleLabel.layer.shadowOpacity = 1.0;
}

- (IBAction)closeButtonTapped:(UIBarButtonItem *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat offsetY = scrollView.contentOffset.y;
    if(offsetY <= 0){
        CGRect frame = self.headerView.frame;
        frame.size.height = self.tableView.tableHeaderView.frame.size.height - scrollView.contentOffset.y;
        frame.origin.y = self.tableView.tableHeaderView.frame.origin.y + scrollView.contentOffset.y;
        self.headerView.frame = frame;
    }
}

- (NSString *)sectionTitleForSection:(NSInteger)section {
    switch (section) {
        case ZBInfo:
            return @"信息";
            break;
        case ZBGraphics:
            return @"图形";
            break;
        case ZBAdvanced:
            return @"增加";
            break;
        default:
            return @"错误";
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section){
        case ZBInfo:
            return 1;
            break;
        case ZBGraphics:
            if (@available(iOS 10.3, *)) {
                return 3;
            } else {
                return 2;
            }
            break;
        case ZBAdvanced:
            return 4;
            break;
        default:
            return 0;
            break;
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 0)];
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, tableView.frame.size.width - 10, 18)];
    [view setBackgroundColor:[UIColor tableViewBackgroundColor]];
    [label setFont:[UIFont boldSystemFontOfSize:15]];
    [label setText:[self sectionTitleForSection:section]];
    [label setTextColor:[UIColor cellPrimaryTextColor]];
    [view addSubview:label];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-16-[label]-10-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(label)]];
    [view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[label]-5-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(label)]];
    return view;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if(indexPath.section == ZBInfo){
        static NSString *cellIdentifier = @"infoCells";
        
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        }
        NSString *labelText;
        UIImage *cellImage = [UIImage new];
        if (indexPath.row == ZBBugs) {
            labelText = @"报告错误";
            cellImage = [UIImage imageNamed:@"report"];
        }
        cell.textLabel.text = labelText;
        cell.imageView.image = cellImage;
        CGSize itemSize = CGSizeMake(40, 40);
        UIGraphicsBeginImageContextWithOptions(itemSize, NO, UIScreen.mainScreen.scale);
        CGRect imageRect = CGRectMake(0.0, 0.0, itemSize.width, itemSize.height);
        [cell.imageView.image drawInRect:imageRect];
        cell.imageView.image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        [cell.imageView.layer setCornerRadius:10];
        [cell.imageView setClipsToBounds:YES];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        [cell.textLabel setTextColor:[UIColor cellPrimaryTextColor]];
        return cell;
    }
    else if (indexPath.section == ZBGraphics) {
        static NSString *cellIdentifier = @"uiCells";
        
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        }
        if (indexPath.row == ZBChangeIcon) {
            cell.textLabel.text = @"更改图标";
            if (@available(iOS 10.3, *)) {
                if ([[UIApplication sharedApplication] alternateIconName]) {
                    cell.imageView.image = [UIImage imageNamed:[[UIApplication sharedApplication] alternateIconName]];
                    CGSize itemSize = CGSizeMake(40, 40);
                    UIGraphicsBeginImageContextWithOptions(itemSize, NO, UIScreen.mainScreen.scale);
                    CGRect imageRect = CGRectMake(0.0, 0.0, itemSize.width, itemSize.height);
                    [cell.imageView.image drawInRect:imageRect];
                    cell.imageView.image = UIGraphicsGetImageFromCurrentImageContext();
                    UIGraphicsEndImageContext();
                    [cell.imageView.layer setCornerRadius:10];
                    [cell.imageView setClipsToBounds:YES];
                } else {
                    cell.imageView.image = [UIImage imageNamed:@"AppIcon60x60"];
                    CGSize itemSize = CGSizeMake(40, 40);
                    UIGraphicsBeginImageContextWithOptions(itemSize, NO, UIScreen.mainScreen.scale);
                    CGRect imageRect = CGRectMake(0.0, 0.0, itemSize.width, itemSize.height);
                    [cell.imageView.image drawInRect:imageRect];
                    cell.imageView.image = UIGraphicsGetImageFromCurrentImageContext();
                    UIGraphicsEndImageContext();
                    [cell.imageView.layer setCornerRadius:10];
                    [cell.imageView setClipsToBounds:YES];
                    
                }
                
            }
        }
        else if (indexPath.row == ZBChangeTint) {
            [cell.contentView.subviews makeObjectsPerformSelector: @selector(removeFromSuperview)];
            NSString *forthTint;
            if([ZBDevice darkModeEnabled]) {
                forthTint = @"白色";
            } else {
                forthTint = @"黑色";
            }
            UISegmentedControl *segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"默认", @"蓝色", @"橙色", forthTint]];
            segmentedControl.selectedSegmentIndex = (NSInteger)self->selectedSortingType;
            segmentedControl.tintColor = [UIColor tintColor];
            [segmentedControl addTarget:self action:@selector(segmentedControlValueChanged:) forControlEvents:UIControlEventValueChanged];
            /*segmentedControl.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
            segmentedControl.center = CGPointMake(cell.contentView.bounds.size.width / 2, cell.contentView.bounds.size.height / 2);
            [cell.contentView addSubview:segmentedControl];*/
            cell.accessoryView = segmentedControl;
            cell.textLabel.text = @"色调";
        } else if (indexPath.row == ZBOledSwitch) {
            [cell.contentView.subviews makeObjectsPerformSelector: @selector(removeFromSuperview)];
            UISwitch *darkSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
            darkSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"oledMode"];
            [darkSwitch addTarget:self action:@selector(toggleOledDarkMode:) forControlEvents:UIControlEventValueChanged];
            [darkSwitch setOnTintColor:[UIColor tintColor]];
            cell.accessoryView = darkSwitch;
            cell.textLabel.text = @"OLED专用暗黑模式";
        }
        [cell.textLabel setTextColor:[UIColor cellPrimaryTextColor]];
        return cell;
    }
    else if (indexPath.section == ZBAdvanced) {
        static NSString *cellIdentifier = @"advancedCells";
        
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        }
        NSString *text;
        if (indexPath.row == ZBDropTables) {
            text = @"快速刷新源库";
        } else if (indexPath.row == ZBOpenDocs){
            text = @"打开文档目录";
        } else if (indexPath.row == ZBClearImageCache) {
            text = @"清除图标缓存";
        } else if (indexPath.row == ZBClearKeychain){
            text = @"清除账户密钥";
        }
        cell.textLabel.text = text;
        [cell.textLabel setTextColor:[UIColor tintColor]];
        return cell;
    } else {
        return nil;
    }
    
        
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case ZBInfo:
            switch (indexPath.row) {
                case ZBBugs:
                    [self openWebView:ZBBugs];
                    break;
            }
            break;
        case ZBGraphics:
            switch (indexPath.row) {
                case ZBChangeIcon :
                    [self changeIcon];
                    break;
                case ZBOledSwitch :
                    [self getTappedSwitch:indexPath];
                    break;
            }
            break;
        case ZBAdvanced:
            switch (indexPath.row) {
                case ZBDropTables :
                    [self nukeDatabase];
                    break;
                case ZBOpenDocs :
                    [self openDocumentsDirectory];
                    break;
                case ZBClearImageCache :
                    [self resetImageCache];
                    break;
                case ZBClearKeychain :
                    [self clearKeychain];
                    break;
            }
            break;
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}


# pragma mark selected cells methods

- (void)openChangelog {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    ZBChangeLogTableViewController *changeLog = [storyboard instantiateViewControllerWithIdentifier:@"changeLogController"];
    [self.navigationController pushViewController:changeLog animated:true];
}


- (void)openCommunityRepos {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    ZBCommunityReposTableViewController *community = [storyboard instantiateViewControllerWithIdentifier:@"communityReposController"];
    [self.navigationController pushViewController:community animated:true];
}


- (void)openWebView:(NSInteger)cellNumber {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    ZBWebViewController *webController = [storyboard instantiateViewControllerWithIdentifier:@"webController"];
    webController.navigationDelegate = webController;
    webController.navigationItem.title = @"加载中...";
    NSURL *url = [NSURL URLWithString:@"https://xtm3x.github.io/repo/depictions/xyz.willy.zebra/bugsbugsbugs.html"];
    [self.navigationController.navigationBar setBackgroundColor:[UIColor tableViewBackgroundColor]];
    [self.navigationController.navigationBar setBarTintColor:[UIColor tableViewBackgroundColor]];
    
    [webController setValue:url forKey:@"_url"];
    
    [[self navigationController] pushViewController:webController animated:true];
}

- (void)showRefreshView:(NSNumber *)dropTables {
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(showRefreshView:) withObject:dropTables waitUntilDone:false];
    }
    else {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        ZBRefreshViewController *console = [storyboard instantiateViewControllerWithIdentifier:@"refreshController"];
        console.dropTables = [dropTables boolValue];
        [self presentViewController:console animated:true completion:nil];
    }
}

- (void)nukeDatabase {
    [self showRefreshView:@(YES)];
}

- (void)openDocumentsDirectory {
    NSString *documents = [ZBAppDelegate documentsDirectory];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"filza://view%@", documents]]];
}

- (void)resetImageCache {
    [[SDImageCache sharedImageCache] clearMemory];
    [[SDImageCache sharedImageCache] clearDiskOnCompletion:nil];
}

- (void)clearKeychain {
    NSArray *secItemClasses = @[(__bridge id)kSecClassGenericPassword,
                                (__bridge id)kSecClassInternetPassword,
                                (__bridge id)kSecClassCertificate,
                                (__bridge id)kSecClassKey,
                                (__bridge id)kSecClassIdentity];
    for (id secItemClass in secItemClasses) {
        NSDictionary *spec = @{(__bridge id)kSecClass: secItemClass};
        SecItemDelete((__bridge CFDictionaryRef)spec);
    }
}

- (void)changeIcon {
    if (@available(iOS 10.3, *)) {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        ZBAlternateIconController *altIcon = [storyboard instantiateViewControllerWithIdentifier:@"alternateIconController"];
        [self.navigationController.navigationBar setBackgroundColor:[UIColor tableViewBackgroundColor]];
        [self.navigationController.navigationBar setBarTintColor:[UIColor tableViewBackgroundColor]];
        [self.navigationController pushViewController:altIcon animated:YES];
    }
}

- (void)getTappedSwitch:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    UISwitch *switcher = (UISwitch *)cell.accessoryView;
    [switcher setOn:!switcher.on animated:YES];
    [self toggleOledDarkMode:switcher];
    
}

- (void)toggleOledDarkMode:(id)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    UISwitch *switcher = (UISwitch *)sender;
    BOOL oled = [defaults boolForKey:@"oledMode"];
    oled = switcher.isOn;
    [defaults setBool:oled forKey:@"oledMode"];
    [defaults synchronize];
    [self hapticButton];
    [self oledAnimation];
}

- (void)oledAnimation {
    [self.tableView reloadData];
    [self.tableView setBackgroundColor:[UIColor tableViewBackgroundColor]];
    [self configureNavBar];
    self.headerView.backgroundColor = [UIColor tableViewBackgroundColor];
    [ZBDevice darkModeEnabled] ? [ZBDevice configureDarkMode] : [ZBDevice configureLightMode];
    [ZBDevice refreshViews];
    [self setNeedsStatusBarAppearanceUpdate];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"darkMode" object:self];
    CATransition *transition = [CATransition animation];
    transition.type = kCATransitionFade;
    transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    transition.fillMode = kCAFillModeForwards;
    transition.duration = 0.35;
    transition.subtype = kCATransitionFromTop;
    [self.view.layer addAnimation:transition forKey:nil];
    [self.navigationController.navigationBar.layer addAnimation:transition forKey:nil];
}

- (void)hapticButton {
    if (@available(iOS 10.0, *)) {
        UISelectionFeedbackGenerator *feedback = [[UISelectionFeedbackGenerator alloc] init];
        [feedback prepare];
        [feedback selectionChanged];
        feedback = nil;
    }
}

- (void)segmentedControlValueChanged:(UISegmentedControl *)segmentedControl {
    selectedSortingType = (ZBTintSelection)segmentedControl.selectedSegmentIndex;
    [[NSUserDefaults standardUserDefaults] setObject:@(selectedSortingType) forKey:@"tintSelection"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self hapticButton];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"darkMode" object:self];
    [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:1 initialSpringVelocity:1 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        [self.tableView reloadData];
        [self configureNavBar];
        [ZBDevice darkModeEnabled] ? [ZBDevice configureDarkMode] : [ZBDevice configureLightMode];
        [ZBDevice refreshViews];
        [self setNeedsStatusBarAppearanceUpdate];
    } completion:nil];
}

- (IBAction)doneButtonPressed:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end
