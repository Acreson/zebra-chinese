//
//  ZBConsoleViewController.m
//  Zebra
//
//  Created by Wilson Styres on 2/6/19.
//  Copyright © 2019 Wilson Styres. All rights reserved.
//

#import "ZBConsoleViewController.h"
#import <ZBLog.h>
#import <NSTask.h>
#import <ZBDevice.h>
#import <Queue/ZBQueue.h>
#import <Database/ZBDatabaseManager.h>
#import <ZBAppDelegate.h>
#import <ZBTabBarController.h>
#import <Downloads/ZBDownloadManager.h>
#import <Packages/Helpers/ZBPackage.h>

typedef enum {
    ZBStageInstall = 0,
    ZBStageRemove,
    ZBStageReinstall,
    ZBStageUpgrade,
    ZBStageDone
} ZBStage;

@interface ZBConsoleViewController () {
    int stage;
    BOOL continueWithActions;
    NSArray *akton;
    BOOL needsIconCacheUpdate;
    BOOL needsRespring;
    NSMutableArray *installedIDs;
    NSMutableArray *bundlePaths;
    NSMutableDictionary <NSString *, NSNumber *> *downloadingMap;
    ZBDownloadManager *downloadManager;
    BOOL hasZebraUpdated;
}
@end

@implementation ZBConsoleViewController

@synthesize queue;

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setTitle:@"控制台"];
    [self.navigationController.navigationBar setBarStyle:UIBarStyleBlack];
    
    queue = [ZBQueue sharedInstance];
    stage = -1;
    continueWithActions = true;
    needsIconCacheUpdate = false;
    needsRespring = false;
    installedIDs = [NSMutableArray new];
    bundlePaths = [NSMutableArray new];
    downloadingMap = [NSMutableDictionary new];
    _progressView.progress = 0;
    _progressView.hidden = YES;
    _progressText.text = nil;
    _progressText.hidden = YES;
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"取消" style:UIBarButtonItemStylePlain target:self action:@selector(cancel)];
    self.navigationItem.leftBarButtonItem = cancelButton;
    [self.navigationItem setHidesBackButton:YES animated:NO];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (_externalInstall) {
        akton = @[@[@0], @[@"apt", @"install", @"-y", _externalFilePath]];
        [self performSelectorInBackground:@selector(performActions) withObject:NULL];
    }
    else if ([queue needsHyena]) {
        _progressView.hidden = NO;
        _progressText.hidden = NO;
        [self downloadPackages];
    }
    else {
        [self performSelectorInBackground:@selector(performActions) withObject:NULL];
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)downloadPackages {
    NSArray *packages = [queue packagesToDownload];
    
    [self writeToConsole:@"下载软件包中...安装插件的过程中切勿锁屏/黑屏...\n" atLevel:ZBLogLevelInfo];
    downloadManager = [[ZBDownloadManager alloc] init];
    downloadManager.downloadDelegate = self;
    
    [downloadManager downloadPackages:packages];
}

- (void)performActions {
    [self performActions:NULL];
}

- (BOOL)isValidPackageID:(NSString *)packageID {
    return ![packageID hasPrefix:@"-"] && ![packageID isEqualToString:@"install"] && ![packageID isEqualToString:@"remove"];
}

- (void)performActions:(NSArray *)debs {
    if (akton != NULL) {
        ZBLog(@"[Zebra] Actions: %@", akton);
        for (NSArray *command in akton) {
            if ([command count] == 1) {
                [self updateStatus:[command[0] intValue]];
            }
            else {
                for (int i = 3; i < [command count]; ++i) {
                    NSString *packageID = command[i];
                    if (![self isValidPackageID:packageID]) {
                        continue;
                    }
                    
                    if (stage != ZBStageDone) {
                        if (!needsIconCacheUpdate && [ZBPackage containsApp:packageID]) {
                            needsIconCacheUpdate = true;
                            NSString *path = [ZBPackage pathForApplication:packageID];
                            if (path) {
                                [bundlePaths addObject:path];
                            }
                        }
                        
                        if (!needsRespring) {
                            needsRespring = [ZBPackage containsRespringable:packageID];
                        }
                    }
                    if (stage != ZBStageDone && stage != ZBStageRemove) {
                        [installedIDs addObject:packageID];
                    }
                }
                
                if (![ZBDevice needsSimulation]) {
                    NSTask *task = [[NSTask alloc] init];
                    [task setLaunchPath:@"/usr/libexec/zebra/supersling"];
                    [task setArguments:command];
                    
                    NSPipe *outputPipe = [[NSPipe alloc] init];
                    NSFileHandle *output = [outputPipe fileHandleForReading];
                    [output waitForDataInBackgroundAndNotify];
                    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedData:) name:NSFileHandleDataAvailableNotification object:output];
                    
                    NSPipe *errorPipe = [[NSPipe alloc] init];
                    NSFileHandle *error = [errorPipe fileHandleForReading];
                    [error waitForDataInBackgroundAndNotify];
                    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedErrorData:) name:NSFileHandleDataAvailableNotification object:error];
                    
                    [task setStandardOutput:outputPipe];
                    [task setStandardError:errorPipe];
                    
                    [task launch];
                    [task waitUntilExit];
                }
            }
        }
        [self refreshLocalPackages];
    }
    else {
        if (continueWithActions) {
            _progressText.text = @"执行操作中...";
            self.navigationItem.leftBarButtonItem = nil;
            NSArray *actions = [queue tasks:debs];
            ZBLog(@"[Zebra] Actions: %@", actions);
            
            for (NSArray *command in actions) {
                if ([command count] == 1) {
                    [self updateStatus:[command[0] intValue]];
                }
                else {
                    for (int i = 3; i < [command count]; ++i) {
                        NSString *packageID = command[i];
                        if (![self isValidPackageID:packageID]) {
                            continue;
                        }
                        if (stage != ZBStageDone) {
                            if (!needsIconCacheUpdate && [ZBPackage containsApp:packageID]) {
                                needsIconCacheUpdate = true;
                                NSString *path = [ZBPackage pathForApplication:packageID];
                                if (path) {
                                    [bundlePaths addObject:path];
                                }
                            }
                            
                            if (!needsRespring) {
                                needsRespring = [ZBPackage containsRespringable:packageID];
                            }
                        }
                        if (stage != ZBStageDone && stage != ZBStageRemove) {
                            [installedIDs addObject:packageID];
                        }
                    }
                    
                    if (![ZBDevice needsSimulation]) {
                        NSTask *task = [[NSTask alloc] init];
                        [task setLaunchPath:@"/usr/libexec/zebra/supersling"];
                        [task setArguments:command];
                        
                        NSPipe *outputPipe = [[NSPipe alloc] init];
                        NSFileHandle *output = [outputPipe fileHandleForReading];
                        [output waitForDataInBackgroundAndNotify];
                        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedData:) name:NSFileHandleDataAvailableNotification object:output];
                        
                        NSPipe *errorPipe = [[NSPipe alloc] init];
                        NSFileHandle *error = [errorPipe fileHandleForReading];
                        [error waitForDataInBackgroundAndNotify];
                        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedErrorData:) name:NSFileHandleDataAvailableNotification object:error];
                        
                        [task setStandardOutput:outputPipe];
                        [task setStandardError:errorPipe];
                        
                        [task launch];
                        [task waitUntilExit];
                    }
                }
            }
            [self refreshLocalPackages];
        }
        else {
            [self finishUp];
        }
    }
}

- (void)finishUp {
    [queue clearQueue];
    [downloadingMap removeAllObjects];
    _progressView.hidden = YES;
    
    NSMutableArray *uicaches = [NSMutableArray new];
    for (NSString *packageID in installedIDs) {
        BOOL update = [ZBPackage containsApp:packageID];
        if (update) {
            needsIconCacheUpdate = true;
            NSString *truePackageID = packageID;
            if ([truePackageID hasSuffix:@".deb"]) {
                // Transform deb-path-like packageID into actual package ID for checking to prevent duplicates
                truePackageID = [[packageID lastPathComponent] stringByDeletingPathExtension];
                // ex., com.xxx.yyy_1.0.0_iphoneos_arm.deb
                NSRange underscoreRange = [truePackageID rangeOfString:@"_" options:NSLiteralSearch];
                if (underscoreRange.location != NSNotFound) {
                    truePackageID = [truePackageID substringToIndex:underscoreRange.location];
                    if (!self->hasZebraUpdated && [truePackageID isEqualToString:@"xyz.willy.zebra"]) {
                        self->hasZebraUpdated = YES;
                    }
                }
                if ([uicaches containsObject:truePackageID])
                    continue;
            }
            if (![uicaches containsObject:truePackageID])
                [uicaches addObject:truePackageID];
        }
        
        if (!needsRespring) {
            needsRespring = [ZBPackage containsRespringable:packageID] ? true : needsRespring;
        }
    }
    
    if (needsIconCacheUpdate) {
        [self writeToConsole:@"更新图标缓存中...\n" atLevel:ZBLogLevelInfo];
        NSMutableArray *arguments = [NSMutableArray new];
        if ([uicaches count] + [bundlePaths count] > 1) {
            [arguments addObject:@"-a"];
            [self writeToConsole:@"这可能需要一段时间，斑马可能会崩溃。\n即便是这样也没关系.\n斑马没那么脆弱.就是那么屌。👍\n" atLevel:ZBLogLevelWarning];
        }
        else {
            [arguments addObject:@"-p"];
            for (NSString *packageID in uicaches) {
                if ([packageID isEqualToString:@"-p"] || [packageID isEqualToString:[ZBAppDelegate bundleID]]) continue;
                
                NSString *bundlePath = [ZBPackage pathForApplication:packageID];
                if (bundlePath != NULL) [bundlePaths addObject:bundlePath];
            }
            [arguments addObjectsFromArray:bundlePaths];
        }
        
        if (![ZBDevice needsSimulation]) {
            [ZBDevice uicache:arguments observer:self];
        }
        else {
            [self writeToConsole:@"刷新图标缓存不适用于模拟器操作\n" atLevel:ZBLogLevelWarning];
        }
    }
    
    [self removeAllDebs];
    [self updateStatus:ZBStageDone];
    [self updateCompleteButton];
}

- (void)updateCompleteButton {
    [self.navigationItem setHidesBackButton:YES animated:NO];
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_completeButton.hidden = false;
        self->_progressText.text = nil;
        
        if (self->hasZebraUpdated) {
            [self addCloseButton];
            [self->_completeButton setTitle:@"关闭 Zebra" forState:UIControlStateNormal];
            [self->_completeButton addTarget:self action:@selector(closeZebra) forControlEvents:UIControlEventTouchUpInside];
        }
        else if (self->needsRespring) {
            [self addCloseButton];
            [self->_completeButton setTitle:@"重启 SpringBoard" forState:UIControlStateNormal];
            [self->_completeButton addTarget:self action:@selector(restartSpringBoard) forControlEvents:UIControlEventTouchUpInside];
        }
        else {
            [self->_completeButton setTitle:@"返回 Zebra" forState:UIControlStateNormal];
        }
    });
}

- (void)addCloseButton {
    if (self->hasZebraUpdated) {
        return;
    }
    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStylePlain target:self action:@selector(goodbye)];
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    self.navigationItem.rightBarButtonItem = closeButton;
}

- (void)cancel {
    [self.navigationItem setHidesBackButton:YES animated:NO];
    [downloadManager stopAllDownloads];
    [downloadingMap removeAllObjects];
    self.navigationItem.leftBarButtonItem = nil;
    _progressView.progress = 1;
    _progressView.hidden = YES;
    _progressText.text = nil;
    _progressText.hidden = YES;
    [self addCloseButton];
    [queue clearQueue];
    [self removeAllDebs];
}

- (void)goodbye {
    [self clearConsole];
    [self dismissViewControllerAnimated:true completion:nil];
}

- (void)closeZebra {
    if (![ZBDevice needsSimulation]) {
        [ZBDevice uicache:@[@"-p", @"/Applications/Zebra.app"] observer:self];
    }
    exit(1); // Correct?
}

- (void)restartSpringBoard {
    [ZBDevice sbreload];
}

- (void)refreshLocalPackages {
    ZBDatabaseManager *databaseManager = [ZBDatabaseManager sharedInstance];
    [databaseManager addDatabaseDelegate:self];
    [databaseManager importLocalPackagesAndCheckForUpdates:YES sender:self];
}

- (void)removeAllDebs {
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:[ZBAppDelegate debsLocation]];
    NSString *file;

    while (file = [enumerator nextObject]) {
        NSError *error = nil;
        BOOL result = [[NSFileManager defaultManager] removeItemAtPath:[[ZBAppDelegate debsLocation] stringByAppendingPathComponent:file] error:&error];

        if (!result && error) {
            NSLog(@"[Zebra] Error while removing %@: %@", file, error);
        }
    }
}

- (void)updateStatus:(int)s {
    stage = s;
    switch (s) {
        case 0:
            [self setTitle:@"安装中"];
            [self writeToConsole:@"安装软件包中...\n" atLevel:ZBLogLevelInfo];
            break;
        case 1:
            [self setTitle:@"移除中"];
            [self writeToConsole:@"移除软件包中...\n" atLevel:ZBLogLevelInfo];
            break;
        case 2:
            [self setTitle:@"重装中"];
            [self writeToConsole:@"重装软件包中...\n" atLevel:ZBLogLevelInfo];
            break;
        case 3:
            [self setTitle:@"更新中"];
            [self writeToConsole:@"更新软件包中...\n" atLevel:ZBLogLevelInfo];
            break;
        case 4:
            [self setTitle:@"完成!"];
            [self writeToConsole:@"完成!\n" atLevel:ZBLogLevelInfo];
            break;
        default:
            break;
    }
}

- (void)receivedData:(NSNotification *)notif {
    NSFileHandle *fh = [notif object];
    NSData *data = [fh availableData];

    if (data.length) {
        [fh waitForDataInBackgroundAndNotify];
        NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        [self writeToConsole:str atLevel:ZBLogLevelDescript];
    }
}

///检测dpkg错误的
- (void)receivedErrorData:(NSNotification *)notif {
    NSFileHandle *fh = [notif object];
    NSData *data = [fh availableData];
    
    if (data.length) {
        [fh waitForDataInBackgroundAndNotify];
        NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if ([str rangeOfString:@"无视错误"].location != NSNotFound) {
            str = [str stringByReplacingOccurrencesOfString:@"dpkg: " withString:@""];
            [self writeToConsole:str atLevel:ZBLogLevelWarning];
        }
        else if ([str rangeOfString:@"error"].location != NSNotFound) {
            str = [str stringByReplacingOccurrencesOfString:@"dpkg: " withString:@""];
            [self writeToConsole:str atLevel:ZBLogLevelError];
        }
    }
}

- (void)writeToConsole:(NSString *)str atLevel:(ZBLogLevel)level {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIColor *color;
        UIFont *font;
        switch (level) {
            case ZBLogLevelDescript:
                color = [UIColor whiteColor];
                font = [UIFont fontWithName:@"CourierNewPSMT" size:12.0];
                break;
            case ZBLogLevelInfo:
                color = [UIColor whiteColor];
                font = [UIFont fontWithName:@"CourierNewPS-BoldMT" size:12.0];
                break;
            case ZBLogLevelError:
                color = [UIColor redColor];
                font = [UIFont fontWithName:@"CourierNewPS-BoldMT" size:12.0];
                break;
            case ZBLogLevelWarning:
                color = [UIColor yellowColor];
                font = [UIFont fontWithName:@"CourierNewPSMT" size:12.0];
                break;
            default:
                color = [UIColor whiteColor];
                break;
        }

        NSDictionary *attrs = @{ NSForegroundColorAttributeName: color, NSFontAttributeName: font };

        [self->_consoleView.textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:str attributes:attrs]];

        if (self->_consoleView.text.length) {
            NSRange bottom = NSMakeRange(self->_consoleView.text.length - 1, 1);
            [self->_consoleView scrollRangeToVisible:bottom];
        }
    });
}

- (void)clearConsole {
    _consoleView.text = nil;
}

- (IBAction)complete:(id)sender {
    [self goodbye];
}

#pragma mark - Hyena Delegate

- (void)predator:(nonnull ZBDownloadManager *)downloadManager progressUpdate:(CGFloat)progress forPackage:(ZBPackage *)package {
    downloadingMap[package.identifier] = @(progress);
    CGFloat totalProgress = 0;
    for (NSString *packageID in downloadingMap) {
        totalProgress += [downloadingMap[packageID] doubleValue];
    }
    totalProgress /= downloadingMap.count;
    [_progressView setProgress:totalProgress animated:YES];
    _progressText.text = [NSString stringWithFormat:@"下载中: %.1f%%", totalProgress * 100];
}

- (void)predator:(nonnull ZBDownloadManager *)downloadManager finishedAllDownloads:(NSDictionary *)filenames {
    _progressText.text = nil;
    if (filenames.count) {
        NSArray *debs = [filenames objectForKey:@"debs"];
        [self performSelectorInBackground:@selector(performActions:) withObject:debs];
    }
    else {
        continueWithActions = false;
        [self cancel];
        [self writeToConsole:@"没有下载任何东西.\n\n\n如果上面红字提示你与互联网断开链接.\n说明你的zebra没有网络权限.\n根据系统修复网络权限.\n本源网络分区有修复工具\n\n\n如果是你Electra/Chimera越狱工具越狱的.\n那就说明这个源不适配Sileo请放弃在Sileo/Zebra中下载.\n请安装本源的Electra/Chimera专用的Cydia下载即可.\n" atLevel:ZBLogLevelWarning];
        [self updateStatus:4];
        [self updateCompleteButton];
    }
}

- (void)predator:(nonnull ZBDownloadManager *)downloadManager startedDownloadForFile:(nonnull NSString *)filename {
    [self writeToConsole:[NSString stringWithFormat:@"下载中 %@\n", filename] atLevel:ZBLogLevelDescript];
}

- (void)predator:(nonnull ZBDownloadManager *)downloadManager finishedDownloadForFile:(NSString *_Nullable)filename withError:(NSError * _Nullable)error {
    if (error != NULL) {
        continueWithActions = false;
        [self writeToConsole:[error.localizedDescription stringByAppendingString:@"\n"] atLevel:ZBLogLevelError];
    }
    else if (filename) {
        [self writeToConsole:[NSString stringWithFormat:@"完成 %@\n", filename] atLevel:ZBLogLevelDescript];
    }
}

#pragma mark - Database Delegate

- (void)postStatusUpdate:(NSString *)status atLevel:(ZBLogLevel)level {
    [self writeToConsole:status atLevel:level];
}

- (void)databaseStartedUpdate {
    [self writeToConsole:@"导入软件包中.\n" atLevel:ZBLogLevelInfo];
}

- (void)databaseCompletedUpdate:(int)packageUpdates {
    [self writeToConsole:@"导入完成.\n" atLevel:ZBLogLevelInfo];
    
    NSLog(@"[Zebra] %d 更新可用。", packageUpdates);
    
    if (packageUpdates != -1) {
        ZBTabBarController *tabController = (ZBTabBarController *)[[[UIApplication sharedApplication] delegate] window].rootViewController;
        [tabController setPackageUpdateBadgeValue:packageUpdates];
    }
    
    [self finishUp];
}

@end

