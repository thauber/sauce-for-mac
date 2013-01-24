//
//  AppDelegate.h
//  Chicken of the VNC
//
//  Created by Jason Harris on 8/18/04.
//  Copyright 2004 Geekspiff. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SaucePreconnect.h"
#import "SessionController.h"

#define INAPPSTORE 1
#define kDemoAccountName @"sauce_for_mac"

@class LoginController;
@class TunnelController;
@class BugInfoController;
@class Subscriber;

@interface AppDelegate : NSObject
{
	IBOutlet NSMenuItem *mRendezvousMenuItem;
	IBOutlet NSTextField *mInfoVersionNumber;
    IBOutlet NSMenuItem *fullScreenMenuItem;
    
    SessionController *optionsCtrlr;
    LoginController *loginCtrlr;
    TunnelController *tunnelCtrlr;
    BugInfoController *bugCtrlr;
    Subscriber *subscriberCtrl;
    
    NSMenuItem *tunnelMenuItem;
    NSMenuItem *viewConnectMenuItem;
    NSMenuItem *separatorMenuItem;
    
    NSMenuItem *myaccountMenuItem;    
    IBOutlet NSMenuItem *bugsMenuItem;
    
    BOOL noTunnel;      // set true after user says no to prompt for tunnel
    NSMenuItem *subscribeMenuItem;
    BOOL noShowCloseSession;
    BOOL noShowCloseConnect;
    NSTextField *versionTxt;
    NSPanel *infoPanel;
    
    NSMutableArray *configsOS[kNumTabs];     // os/browsers for windows
    int activeOS[kNumTabs];
        
    BOOL bCommandline;                      // running from command line
    NSString *cmdOS;                        // command line arguments
    NSString *cmdBrowser;
    NSString *cmdVersion;
    NSString *cmdURL;
    NSString *cmdResolution;
    NSString *cmdConnect;
}
@property (assign) IBOutlet NSPanel *infoPanel;
@property (assign) IBOutlet NSTextField *versionTxt;
@property (assign) IBOutlet NSMenuItem *subscribeMenuItem;
@property (assign) IBOutlet NSMenuItem *tunnelMenuItem;
@property (assign) IBOutlet NSMenuItem *viewConnectMenuItem;
@property (assign) IBOutlet NSMenuItem *separatorMenuItem;
@property (assign) IBOutlet NSMenuItem *myaccountMenuItem;
@property (assign) IBOutlet NSMenuItem *bugsMenuItem;

@property (retain)SessionController *optionsCtrlr;
@property (retain)LoginController *loginCtrlr;
@property (retain)TunnelController *tunnelCtrlr;
@property (retain)BugInfoController *bugCtrlr;
@property (retain)Subscriber *subscriberCtrl;

@property  (assign)BOOL noTunnel;
@property (assign) BOOL noShowCloseSession;
@property (assign) BOOL noShowCloseConnect;

- (IBAction)doAbout:(id)sender;

- (IBAction)bugsAccount:(id)sender;
- (IBAction)myAccount:(id)sender;
- (IBAction)doStopSession:(id)sender;
- (IBAction)doStopConnect:(id)sender;
- (IBAction)viewConnect:(id)sender;
- (void)startConnecting:(NSMutableDictionary*)sdict;
- (void)closeStopConnect;

- (IBAction)toggleToolbar:(id)sender;
- (IBAction)doTunnel:(id)sender;
- (void)toggleTunnelDisplay;
-(BOOL)checkTunnelRunning;

- (IBAction)showOptionsDlg:(id)sender;
- (IBAction)showLoginDlg:(id)sender;
- (IBAction)showSubscribeDlg:(id)sender;

- (IBAction)showPreferences: (id)sender;
- (IBAction)showNewConnectionDialog:(id)sender;
- (IBAction)showConnectionDialog: (id)sender;
- (IBAction)showProfileManager: (id)sender;
- (IBAction)showHelp: (id)sender;
- (IBAction)refreshAllSessions:(id)sender;

- (BOOL)checkaccount;
- (BOOL)isDemoAccount;
- (NSInteger)demoCheckTime;
- (BOOL)checkUserOk;
- (void)connectionSucceeded:(NSMutableDictionary*)sdict;
- (void)cancelOptionsConnect:(id)sender;
- (void)escapeDialog;
- (NSMenuItem *)getFullScreenMenuItem;

- (void)promptForSubscribing:(BOOL)bCause;        // 0=needs more minutes; 1=to get more tabs
- (int)numActiveBrowsers:(ttType)os;
- (NSInteger)prefetchBrowsers;
- (NSArray*)getConfigsOS:(int)indx;

@end
