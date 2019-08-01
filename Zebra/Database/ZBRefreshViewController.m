//
//  ZBRefreshViewController.m
//  Zebra
//
//  Created by Wilson Styres on 11/30/18.
//  Copyright © 2018 Wilson Styres. All rights reserved.
//

#import <ZBTabBarController.h>
#import <ZBDevice.h>
#import "ZBRefreshViewController.h"
#import <Database/ZBDatabaseManager.h>
#import <Downloads/ZBDownloadManager.h>
#include <Parsel/parsel.h>

typedef enum {
    ZBStateCancel = 0,
    ZBStateDone
} ZBRefreshButtonState;

@interface ZBRefreshViewController () {
    ZBDatabaseManager *databaseManager;
    BOOL hadAProblem;
    ZBRefreshButtonState buttonState;
}
@property (strong, nonatomic) IBOutlet UIButton *completeOrCancelButton;
@property (strong, nonatomic) IBOutlet UITextView *consoleView;
@end

@implementation ZBRefreshViewController

@synthesize messages;

- (void)viewDidLoad {
    [super viewDidLoad];
    if (_dropTables) {
        self.completeOrCancelButton.hidden = YES;
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(disableCancelButton) name:@"disableCancelRefresh" object:nil];
    if ([ZBDevice darkModeEnabled]) {
        [self setNeedsStatusBarAppearanceUpdate];
        [self.view setBackgroundColor:[UIColor tableViewBackgroundColor]];
        [_consoleView setBackgroundColor:[UIColor tableViewBackgroundColor]];
    }
}

- (void)disableCancelButton {
    buttonState = ZBStateDone;
    self.completeOrCancelButton.hidden = YES;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    if ([ZBDevice darkModeEnabled]) {
        return UIStatusBarStyleLightContent;
    } else {
        return UIStatusBarStyleDefault;
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (!messages) {
        databaseManager = [ZBDatabaseManager sharedInstance];
        [databaseManager addDatabaseDelegate:self];
        
        if (_dropTables) {
            [databaseManager dropTables];
        }
        
        [databaseManager updateDatabaseUsingCaching:NO userRequested:YES];
    }
    else {
        hadAProblem = YES;
        for (NSString *message in messages) {
            [self writeToConsole:message atLevel:ZBLogLevelError];
        }
        buttonState = ZBStateDone;
        [self clearProblems];
    }
}

- (IBAction)completeOrCancelButton:(id)sender {
    if (buttonState == ZBStateDone) {
        [self goodbye];
    }
    else {
        if (_dropTables) {
            return;
        }
        [databaseManager setDatabaseBeingUpdated:NO];
        [databaseManager setHaltDatabaseOperations];
        [databaseManager.downloadManager stopAllDownloads];
        [databaseManager removeDatabaseDelegate:self];
        [databaseManager bulkDatabaseCompletedUpdate:-1];
        ((ZBTabBarController *)self.tabBarController).repoBusyList = [NSMutableDictionary new];
        [self writeToConsole:@"已取消刷新\n" atLevel:ZBLogLevelInfo];
        
        buttonState = ZBStateDone;
        [self.completeOrCancelButton setTitle:@"完成" forState:UIControlStateNormal];
    }
}

- (void)clearProblems {
    messages = NULL;
    hadAProblem = NO;
    self->_consoleView.text = nil;
}

- (void)goodbye {
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(goodbye) withObject:nil waitUntilDone:NO];
    }
    else {
        [self clearProblems];
        if ([self presentingViewController] != NULL) {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
        else {
            UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle: nil];
            ZBTabBarController *vc = [storyboard instantiateViewControllerWithIdentifier:@"tabController"];
            [self presentViewController:vc animated:YES completion:nil];
        }
    }
}

- (void)writeToConsole:(NSString *)str atLevel:(ZBLogLevel)level {
    if (str == NULL)
        return;
    __block BOOL isDark = [ZBDevice darkModeEnabled];
    dispatch_async(dispatch_get_main_queue(), ^{
        UIColor *color = [UIColor whiteColor];
        UIFont *font;
        switch (level) {
            case ZBLogLevelDescript ... ZBLogLevelInfo: {
                if (!isDark) {
                    color = [UIColor blackColor];
                }
                font = [UIFont fontWithName:level == ZBLogLevelDescript ? @"CourierNewPSMT" : @"CourierNewPS-BoldMT" size:10.0];
                break;
            }
            case ZBLogLevelError: {
                color = [UIColor redColor];
                font = [UIFont fontWithName:@"CourierNewPS-BoldMT" size:10.0];
                break;
            }
            case ZBLogLevelWarning: {
                color = [UIColor yellowColor];
                font = [UIFont fontWithName:@"CourierNewPSMT" size:10.0];
                break;
            }
            default: {
                break;
            }
        }

        NSDictionary *attrs = @{ NSForegroundColorAttributeName: color, NSFontAttributeName: font };
        
        [self->_consoleView.textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:str attributes:attrs]];

        if (self->_consoleView.text.length) {
            NSRange bottom = NSMakeRange(self->_consoleView.text.length -1, 1);
            [self->_consoleView scrollRangeToVisible:bottom];
        }
    });
}

#pragma mark - Database Delegate

- (void)databaseStartedUpdate {
    hadAProblem = NO;
}

- (void)databaseCompletedUpdate:(int)packageUpdates {
    ZBTabBarController *tabController = (ZBTabBarController *)[[[UIApplication sharedApplication] delegate] window].rootViewController;
    if (packageUpdates != -1) {
        [tabController setPackageUpdateBadgeValue:packageUpdates];
    }
    if (!hadAProblem) {
        [self goodbye];
    }
    else {
        [self.completeOrCancelButton setTitle:@"完成" forState:UIControlStateNormal];
    }
}

- (void)postStatusUpdate:(NSString *)status atLevel:(ZBLogLevel)level {
    if (level == ZBLogLevelError || level == ZBLogLevelWarning) {
        hadAProblem = YES;
    }
    [self writeToConsole:status atLevel:level];
}

@end
