//
//  ZBPackageDepictionViewController.h
//  Zebra
//
//  Created by Wilson Styres on 1/23/19.
//  Copyright © 2019 Wilson Styres. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <Packages/Controllers/ZBPackagesByAuthorTableViewController.h>
#import "ZBInstalledFilesTableViewController.h"
@import SafariServices;
@import MessageUI;

@class ZBPackage;

NS_ASSUME_NONNULL_BEGIN

@interface ZBPackageDepictionViewController : UIViewController <WKNavigationDelegate, WKScriptMessageHandler, UIViewControllerPreviewing, SFSafariViewControllerDelegate, UITableViewDataSource, UITableViewDelegate, MFMailComposeViewControllerDelegate>
@property (nonatomic, strong) ZBPackage *package;
@property (weak, nonatomic) IBOutlet UIImageView *packageIcon;
@property (weak, nonatomic) IBOutlet UILabel *packageName;
@property (strong, nonatomic) IBOutlet UITableView *tableView;
@property BOOL purchased;
@property NSString *authorEmail;
@property (nonatomic, weak) UIViewController *parent;
- (id)initWithPackageID:(NSString *)packageID;
@end

NS_ASSUME_NONNULL_END
