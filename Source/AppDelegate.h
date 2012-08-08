//
//  AppDelegate.h
//  Chicken of the VNC
//
//  Created by Jason Harris on 8/18/04.
//  Copyright 2004 Geekspiff. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SaucePreconnect.h"

#define INAPPSTORE 1

@class SessionController;
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
    BOOL noTunnel;      // set true after user says no to prompt for tunnel
    NSMenuItem *subscribeMenuItem;
    BOOL noShowCloseSession;
    BOOL noShowCloseConnect;
}
@property (assign) IBOutlet NSMenuItem *subscribeMenuItem;
@property (assign) IBOutlet NSMenuItem *tunnelMenuItem;
@property (retain)SessionController *optionsCtrlr;
@property (retain)LoginController *loginCtrlr;
@property (retain)TunnelController *tunnelCtrlr;
@property (retain)BugInfoController *bugCtrlr;
@property (retain)Subscriber *subscriberCtrl;
@property  (assign)BOOL noTunnel;
@property (assign) BOOL noShowCloseSession;
@property (assign) BOOL noShowCloseConnect;

- (IBAction)bugsAccount:(id)sender;
- (IBAction)myAccount:(id)sender;
- (IBAction)doStopSession:(id)sender;
- (IBAction)doStopConnect:(id)sender;
- (IBAction)viewConnect:(id)sender;
- (void)closeStopConnect;

- (IBAction)toggleToolbar:(id)sender;
- (IBAction)doTunnel:(id)sender;
- (void)toggleTunnelDisplay;

- (IBAction)showOptionsDlg:(id)sender;
- (IBAction)showLoginDlg:(id)sender;
- (IBAction)showSubscribeDlg:(id)sender;

- (IBAction)showPreferences: (id)sender;
- (IBAction)showNewConnectionDialog:(id)sender;
- (IBAction)showConnectionDialog: (id)sender;
- (IBAction)showProfileManager: (id)sender;
- (IBAction)showHelp: (id)sender;

- (BOOL)checkUserOk;
- (void)connectionSucceeded;
- (void)cancelOptionsConnect:(id)sender;
- (void)escapeDialog;
- (NSMenuItem *)getFullScreenMenuItem;

- (void)promptForSubscribing:(BOOL)bCause;        // 0=needs more minutes; 1=to get more tabs

@end
