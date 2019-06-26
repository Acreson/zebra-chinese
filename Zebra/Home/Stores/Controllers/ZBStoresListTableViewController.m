//
//  ZBStoresListTableViewController.m
//  Zebra
//
//  Created by va2ron1 on 6/2/19.
//  Copyright © 2019 Wilson Styres. All rights reserved.
//

#import "ZBStoresListTableViewController.h"
#import <Repos/Helpers/ZBRepo.h>
#import <Repos/Helpers/ZBRepoTableViewCell.h>
#import <Database/ZBDatabaseManager.h>
#import <Repos/Helpers/ZBRepoManager.h>
#import <Repos/Controllers/ZBRepoPurchasedPackagesTableViewController.h>
#import <ZBAppDelegate.h>
#import <ZBDeviceHelper.h>

@import SDWebImage;

@interface ZBStoresListTableViewController () {
    NSMutableArray *sources;
    NSString *currentRepoEndpoint;
}
@end

@implementation ZBStoresListTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    _keychain = [UICKeyChainStore keyChainStoreWithService:[ZBAppDelegate bundleID] accessGroup:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(authenticationCallBack:) name:@"AuthenticationCallBack" object:nil];
    currentRepoEndpoint = @"";
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    [self refreshTable];
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:TRUE];
    [self refreshTable];
}

- (void)refreshTable {
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(refreshTable) withObject:nil waitUntilDone:false];
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateStores];
            [self.tableView reloadData];
        });
    }
}

- (void)updateStores {
    ZBDatabaseManager *databaseManager = [ZBDatabaseManager sharedInstance];
    sources = [[databaseManager repos] mutableCopy];
    
    self.tableData = [[NSMutableArray alloc] init];
    
    for (ZBRepo *repo in sources) {
        if ([[self.keychain stringForKey:repo.baseURL] length] != 0) {
            [self.tableData addObject:repo];
        }
    }
}

#pragma mark - Table view data source


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.tableData.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ZBRepoTableViewCell *cell = (ZBRepoTableViewCell*)[tableView dequeueReusableCellWithIdentifier:@"repoTableViewCell" forIndexPath:indexPath];
    
    ZBRepo *source = [self.tableData objectAtIndex:indexPath.row];
    
    cell.repoLabel.text = [source origin];

    if (![self checkAuthenticatedRepo:[_keychain stringForKey:[source baseURL]]]) {
        cell.urlLabel.text = @"Login";
    }
    else {
        cell.urlLabel.text = @"Purchases";
    }
    [cell.iconImageView sd_setImageWithURL:[source iconURL] placeholderImage:[UIImage imageNamed:@"Unknown"]];
 
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    ZBRepo *source = [self.tableData objectAtIndex:indexPath.row];
    currentRepoEndpoint = [_keychain stringForKey:[source baseURL]];
    if (![self checkAuthenticatedRepo:currentRepoEndpoint]) {
        NSString *urlString = [NSString stringWithFormat:@"%@authenticate?udid=%@&model=%@", currentRepoEndpoint, [ZBDeviceHelper UDID], [ZBDeviceHelper deviceModelID]];
        NSURL *destinationUrl = [NSURL URLWithString:urlString];
        if (destinationUrl == nil) {
            return;
        }
        if (@available(iOS 11.0, *)) {
            static SFAuthenticationSession *session;
            session = [[SFAuthenticationSession alloc]
                       initWithURL:destinationUrl
                       callbackURLScheme:@"sileo"
                       completionHandler:^(NSURL * _Nullable callbackURL, NSError * _Nullable error) {
                           // TODO: Nothing to do here?
                           //NSLog(@"URL %@", callbackURL);
                           if (callbackURL) {
                               NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:callbackURL resolvingAgainstBaseURL:NO];
                               NSArray *queryItems = urlComponents.queryItems;
                               NSMutableDictionary *queryByKeys = [NSMutableDictionary new];
                               for (NSURLQueryItem *q in queryItems) {
                                   [queryByKeys setValue:[q value] forKey:[q name]];
                               }
                               NSString *token = queryByKeys[@"token"];
                               NSString *payment = queryByKeys[@"payment_secret"];
                               /*NSError *error;
                                [self->_keychain setString:token forKey:self.repoEndpoint error:&error];
                                if (error) {
                                NSLog(@"MIDNIGHTZEBRA %@", error.localizedDescription);
                                
                                }*/
                               self->_keychain[self->currentRepoEndpoint] = token;
                               UICKeyChainStore *securedKeychain = [UICKeyChainStore keyChainStoreWithService:[ZBAppDelegate bundleID] accessGroup:nil];
                               securedKeychain[[self->currentRepoEndpoint stringByAppendingString:@"payment"]] = nil;
                               dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                                   [securedKeychain setAccessibility:UICKeyChainStoreAccessibilityWhenPasscodeSetThisDeviceOnly
                                                authenticationPolicy:UICKeyChainStoreAuthenticationPolicyUserPresence];
                                   
                                   securedKeychain[[self->currentRepoEndpoint stringByAppendingString:@"payment"]] = payment;
                               });
                               [self refreshTable];
                           }
                           else {
                               return;
                           }
                           
                           
                       }];
            [session start];
        }
        else {
            SFSafariViewController *safariVC = [[SFSafariViewController alloc] initWithURL:destinationUrl];
            safariVC.delegate = self;
            [self presentViewController:safariVC animated:TRUE completion:nil];
        }
    }
    else {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        ZBRepoPurchasedPackagesTableViewController *ivc = (ZBRepoPurchasedPackagesTableViewController *)[storyboard instantiateViewControllerWithIdentifier:@"purchasedController"];
        ivc.repoName = source.origin;
        ivc.repoEndpoint = currentRepoEndpoint;
        ivc.repoImage = [[ZBDatabaseManager sharedInstance] iconForRepo:source];
        [self.navigationController pushViewController:ivc animated:YES];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 65;
}

- (BOOL)checkAuthenticatedRepo:(NSString *)repo {
    return [[_keychain stringForKey:repo] length];
}

- (void)safariViewController:(SFSafariViewController *)controller didCompleteInitialLoad:(BOOL)didLoadSuccessfully {
    
}

- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller {
    [self refreshTable];
}

- (void)authenticationCallBack:(NSNotification *)notif {
    [self dismissViewControllerAnimated:TRUE completion:nil];

    NSURL *callbackURL = [notif.userInfo objectForKey:@"callBack"];
    NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:callbackURL resolvingAgainstBaseURL:NO];
    NSArray *queryItems = urlComponents.queryItems;
    NSMutableDictionary *queryByKeys = [NSMutableDictionary new];
    for (NSURLQueryItem *q in queryItems) {
        [queryByKeys setValue:[q value] forKey:[q name]];
    }
    NSString *token = queryByKeys[@"token"];
    NSString *payment = queryByKeys[@"payment_secret"];
    self->_keychain[currentRepoEndpoint] = token;
    UICKeyChainStore *securedKeychain = [UICKeyChainStore keyChainStoreWithService:[ZBAppDelegate bundleID] accessGroup:nil];
    securedKeychain[[currentRepoEndpoint stringByAppendingString:@"payment"]] = nil;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [securedKeychain setAccessibility:UICKeyChainStoreAccessibilityWhenPasscodeSetThisDeviceOnly
                     authenticationPolicy:UICKeyChainStoreAuthenticationPolicyUserPresence];
        securedKeychain[[self->currentRepoEndpoint stringByAppendingString:@"payment"]] = payment;
    });
    [self refreshTable];
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
