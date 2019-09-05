//
//  ZBSearchViewController.h
//  Zebra
//
//  Created by Wilson Styres on 12/27/18.
//  Copyright © 2018 Wilson Styres. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZBSearchViewController : UITableViewController <UISearchControllerDelegate, UISearchBarDelegate, UIViewControllerPreviewingDelegate>
@property (nonatomic, strong) UISearchController *searchController;
- (void)handleURL:(NSURL *_Nullable)url;
@end

NS_ASSUME_NONNULL_END
