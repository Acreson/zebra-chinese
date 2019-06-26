//
//  ZBRepoSectionsListTableViewController.m
//  Zebra
//
//  Created by Wilson Styres on 3/24/19.
//  Copyright © 2019 Wilson Styres. All rights reserved.
//
#import <ZBAppDelegate.h>
#import <ZBDeviceHelper.h>
#import <ZBDarkModeHelper.h>
#import "ZBRepoSectionsListTableViewController.h"
#import <Database/ZBDatabaseManager.h>
#import <Repos/Helpers/ZBRepo.h>
#import <Packages/Controllers/ZBPackageListTableViewController.h>
#import <Repos/Helpers/ZBRepoManager.h>
#import "UIBarButtonItem+blocks.h"
#import "ZBRepoPurchasedPackagesTableViewController.h"
#import "ZBFeaturedCollectionViewCell.h"

#import "UIColor+GlobalColors.h"
@import SDWebImage;

@interface ZBRepoSectionsListTableViewController ()

@end

@implementation ZBRepoSectionsListTableViewController

@synthesize repo;
@synthesize sectionReadout;
@synthesize sectionNames;
@synthesize databaseManager;

- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(darkMode:) name:@"darkMode" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(darkMode:) name:@"lightMode" object:nil];
    _keychain = [UICKeyChainStore keyChainStoreWithService:[ZBAppDelegate bundleID] accessGroup:nil];
    //For iOS 9 and 10 Sileo Purchases
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(authenticationCallBack:) name:@"AuthenticationCallBack" object:nil];
    
    databaseManager = [ZBDatabaseManager sharedInstance];
    sectionReadout = [databaseManager sectionReadoutForRepo:repo];
    sectionNames = [[sectionReadout allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];

    if (@available(iOS 11.0, *)) {
        self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    }
    // Purchased Buttons
    self.login = [[UIBarButtonItem alloc] initWithTitle:@"Login" style:UIBarButtonItemStylePlain actionHandler:^{
        [self setupRepoLogin];
    }];
    
    self.purchased = [[UIBarButtonItem alloc] initWithTitle:@"Purchased" style:UIBarButtonItemStylePlain actionHandler:^{
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        ZBRepoPurchasedPackagesTableViewController *ivc = (ZBRepoPurchasedPackagesTableViewController *)[storyboard instantiateViewControllerWithIdentifier:@"purchasedController"];
        ivc.repoName = self.repo.origin;
        ivc.repoEndpoint = self.repoEndpoint;
        ivc.repoImage = [self->databaseManager iconForRepo:self->repo];
        [self.navigationController pushViewController:ivc animated:YES];
        
    }];
    
    
    UIImage *image = [databaseManager iconForRepo:repo];
    if (image != NULL) {
        UIView *container = [[UIView alloc] initWithFrame:self.navigationItem.titleView.frame];
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
        imageView.center = self.navigationItem.titleView.center;
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.image = image;
        imageView.layer.cornerRadius = 5;
        imageView.layer.masksToBounds = YES;
        [container addSubview:imageView];
        
        self.navigationItem.titleView = container;
    }
    self.title = [repo origin];
    if (@available(iOS 10.0, *)) {
        self.automaticallyAdjustsScrollViewInsets = false;
    }
    else {
        CGFloat top = self.navigationController.navigationBar.bounds.size.height;
        self.tableView.contentInset = UIEdgeInsetsMake(top + 20, 0, 64, 0);
    }
    // This has to be registered anyway due to repo payment support late check
    [self.featuredCollection registerNib:[UINib nibWithNibName:@"ZBFeaturedCollectionViewCell" bundle:nil] forCellWithReuseIdentifier:@"imageCell"];
    [self checkFeaturedPackages];
    if (!self.repoEndpoint && [[_keychain stringForKey:repo.baseURL] length] != 0) {
        self.repoEndpoint = [_keychain stringForKey:repo.baseURL];
    }
    if (self.repoEndpoint) {
        if (![self checkAuthenticated]) {
            [self.navigationItem setRightBarButtonItem:self.login];
        }
        else {
            [self.navigationItem setRightBarButtonItem:self.purchased];
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:TRUE];
    [self.tableView setSeparatorColor:[UIColor cellSeparatorColor]];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"AuthenticationCallBack" object:nil];
}

- (BOOL)checkAuthenticated {
    return [[_keychain stringForKey:self.repoEndpoint] length];
}

- (void)checkFeaturedPackages {
    [self.featuredCollection removeFromSuperview];
    UIView *blankHeader = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, CGFLOAT_MIN)];
    self.tableView.tableHeaderView = blankHeader;
    [self.tableView layoutIfNeeded];
    if (repo.supportsFeaturedPackages) {
        NSString *requestURL;
        if ([repo.baseURL hasSuffix:@"/"]) {
            requestURL = [NSString stringWithFormat:@"https://%@sileo-featured.json", repo.baseURL];
        }
        else {
            requestURL = [NSString stringWithFormat:@"https://%@/sileo-featured.json", repo.baseURL];
        }
        NSURL *checkingURL = [NSURL URLWithString:requestURL];
        NSURLSession *session = [NSURLSession sharedSession];
        [[session dataTaskWithURL:checkingURL
                completionHandler:^(NSData *data,
                                    NSURLResponse *response,
                                    NSError *error) {
                    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
                    if (data != nil && (long)[httpResponse statusCode] != 404) {
                        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
                        //NSLog(@"Downloaded %@", json);
                        self.fullJSON = json;
                        self.featuredPackages = json[@"banners"];
                        //NSLog(@"BANNERS %@", self.featuredPackages);
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self setupFeaturedPackages];
                        });
                    }
                    
                }] resume];
        
    }
}

- (void)setupFeaturedPackages {
    [self.tableView beginUpdates];
    self.tableView.tableHeaderView = self.featuredCollection;
    self.tableView.tableHeaderView.frame = CGRectZero;
    self.featuredCollection.delegate = self;
    self.featuredCollection.dataSource = self;
    [self.featuredCollection setContentInset:UIEdgeInsetsMake(0.f, 15.f, 0.f, 15.f)];
    self.featuredCollection.backgroundColor = [UIColor clearColor];
    CGFloat height = CGSizeFromString(_fullJSON[@"itemSize"]).height + 10;
    //self.featuredCollection.collectionViewLayout.collectionViewContentSize.height = height;
    /*self.featuredCollection.frame = CGRectMake (self.featuredCollection.frame.origin.x,self.featuredCollection.frame.origin.y,self.featuredCollection.frame.size.width,height);*/ //objective c
    //[self.featuredCollection setNeedsLayout];
    //[self.featuredCollection reloadData];
    [UIView animateWithDuration:.25f animations:^{
        self.tableView.tableHeaderView.frame = CGRectMake (self.featuredCollection.frame.origin.x,self.featuredCollection.frame.origin.y,self.featuredCollection.frame.size.width,height);
    }];
    [self.tableView endUpdates];
    //[self.tableView reloadData];
}

- (void)setupRepoLogin {
    if (self.repoEndpoint) {
        NSURL *destinationUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@authenticate?udid=%@&model=%@", self.repoEndpoint, [ZBDeviceHelper UDID], [ZBDeviceHelper deviceModelID]]];
        if (@available(iOS 11.0, *)) {
            static SFAuthenticationSession *session;
            session = [[SFAuthenticationSession alloc]
                            initWithURL:destinationUrl
                            callbackURLScheme:@"sileo"
                            completionHandler:^(NSURL * _Nullable callbackURL, NSError * _Nullable error) {
                                // TODO: Nothing to do here?
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
                                    self->_keychain[self.repoEndpoint] = token;
                                    UICKeyChainStore *securedKeychain = [UICKeyChainStore keyChainStoreWithService:[ZBAppDelegate bundleID] accessGroup:nil];
                                    securedKeychain[[self.repoEndpoint stringByAppendingString:@"payment"]] = nil;
                                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                                        [securedKeychain setAccessibility:UICKeyChainStoreAccessibilityWhenPasscodeSetThisDeviceOnly
                                              authenticationPolicy:UICKeyChainStoreAuthenticationPolicyUserPresence];
                                        
                                        securedKeychain[[self.repoEndpoint stringByAppendingString:@"payment"]] = payment;
                                    });
                                    //[self.repo setLoggedIn:TRUE];
                                    [self.navigationItem setRightBarButtonItem:self.purchased];
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
    self->_keychain[self.repoEndpoint] = token;
    //self->_keychain[[self.repoEndpoint stringByAppendingString:@"payment"]] = payment;
    UICKeyChainStore *securedKeychain = [UICKeyChainStore keyChainStoreWithService:[ZBAppDelegate bundleID] accessGroup:nil];
    securedKeychain[[self.repoEndpoint stringByAppendingString:@"payment"]] = nil;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [securedKeychain setAccessibility:UICKeyChainStoreAccessibilityWhenPasscodeSetThisDeviceOnly
                     authenticationPolicy:UICKeyChainStoreAuthenticationPolicyUserPresence];
        
        securedKeychain[[self.repoEndpoint stringByAppendingString:@"payment"]] = payment;
        
    });
    [self.navigationItem setRightBarButtonItem:self.purchased];
}

- (void)safariViewController:(SFSafariViewController *)controller didCompleteInitialLoad:(BOOL)didLoadSuccessfully {
    // Load finished
}

- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller {
    // Done button pressed
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [sectionNames count] + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"repoSectionCell" forIndexPath:indexPath];
    
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    numberFormatter.locale = [NSLocale currentLocale];
    numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
    numberFormatter.usesGroupingSeparator = YES;
    
    if (indexPath.row == 0) {
        cell.textLabel.text = @"All Packages";
        
        NSNumber *numberOfPackages = [NSNumber numberWithInt:[databaseManager numberOfPackagesInRepo:repo section:NULL]];
        cell.detailTextLabel.text = [numberFormatter stringFromNumber:numberOfPackages];
    }
    else {
        NSString *section = [sectionNames objectAtIndex:indexPath.row - 1];
        cell.textLabel.text = [section stringByReplacingOccurrencesOfString:@"_" withString:@" "];
        
        cell.detailTextLabel.text = [numberFormatter stringFromNumber:(NSNumber *)[sectionReadout objectForKey:section]];
    }
    if ([ZBDarkModeHelper darkModeEnabled]) {
        UIView *dark = [[UIView alloc] init];
        dark.backgroundColor = [UIColor selectedCellBackgroundColorDark];
        [cell setSelectedBackgroundView:dark];
    }
    return cell;
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"segueFeaturedToPackageDepiction"]) {
        ZBPackageDepictionViewController *destination = (ZBPackageDepictionViewController *)[segue destinationViewController];
        NSString *packageID = sender;
        ZBDatabaseManager *databaseManager = [ZBDatabaseManager sharedInstance];
        destination.package = [databaseManager topVersionForPackageID:packageID];
        [databaseManager closeDatabase];
    }
    else {
        ZBPackageListTableViewController *destination = [segue destinationViewController];
        UITableViewCell *cell = (UITableViewCell *)sender;
        destination.repo = repo;
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        
        if (indexPath.row != 0) {
            NSString *section = [sectionNames objectAtIndex:indexPath.row - 1];
            destination.section = section;
            destination.title = section;
        }
        else {
            destination.title = @"All Packages";
        }
    }
}

//3D Touch Actions

- (NSArray *)previewActionItems {
    UIPreviewAction *refresh = [UIPreviewAction actionWithTitle:@"Refresh" style:UIPreviewActionStyleDefault handler:^(UIPreviewAction * _Nonnull action, UIViewController * _Nonnull previewViewController) {
//        ZBDatabaseManager *databaseManager = [[ZBDatabaseManager alloc] init];
//        [databaseManager updateDatabaseUsingCaching:true singleRepo:self->repo completion:^(BOOL success, NSError * _Nonnull error) {
//            NSLog(@"Updated repo %@", self->repo);
//        }];
    }];
    
    if ([repo canDelete]) {
        UIPreviewAction *delete = [UIPreviewAction actionWithTitle:@"Delete" style:UIPreviewActionStyleDestructive handler:^(UIPreviewAction * _Nonnull action, UIViewController * _Nonnull previewViewController) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"deleteRepoTouchAction" object:self userInfo:@{@"repo": self->repo}];
        }];
        
        return @[refresh, delete];
    }
    
    return @[refresh];
}

#pragma mark UICollectionView delegates
- (ZBFeaturedCollectionViewCell *)collectionView:(nonnull UICollectionView *)collectionView cellForItemAtIndexPath:(nonnull NSIndexPath *)indexPath {
    ZBFeaturedCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"imageCell" forIndexPath:indexPath];
    NSDictionary *currentBanner = [self.featuredPackages objectAtIndex:indexPath.row];
    [cell.imageView sd_setImageWithURL:currentBanner[@"url"] placeholderImage:[UIImage imageNamed:@"Unknown"]];
    cell.packageID = currentBanner[@"package"];
    [cell.titleLabel setText:currentBanner[@"title"]];
    
    //dispatch_async(dispatch_get_main_queue(), ^{
        if ([[self.fullJSON objectForKey:@"itemCornerRadius"] doubleValue]) {
            cell.layer.cornerRadius = [self->_fullJSON[@"itemCornerRadius"] doubleValue];
        }
    //});
    
    return cell;
}

- (NSInteger)collectionView:(nonnull UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [_featuredPackages count];
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeFromString(_fullJSON[@"itemSize"]);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
   ZBFeaturedCollectionViewCell *cell = (ZBFeaturedCollectionViewCell *)[collectionView cellForItemAtIndexPath:indexPath];
    [self performSegueWithIdentifier:@"segueFeaturedToPackageDepiction" sender:cell.packageID];
}

- (void)darkMode:(NSNotification *)notif {
    [self.tableView reloadData];
    self.tableView.sectionIndexColor = [UIColor tintColor];
    [self.navigationController.navigationBar setTintColor:[UIColor tintColor]];
}

@end
