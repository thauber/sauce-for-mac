//
//  AppDelegate.h
//  Chicken of the VNC
//
//  Created by Jason Harris on 8/18/04.
//  Copyright 2004 Geekspiff. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SaucePreconnect.h"

@class SessionController;
@class LoginController;
@class TunnelController;
@class BugInfoController;

@interface AppDelegate : NSObject {
	IBOutlet NSMenuItem *mRendezvousMenuItem;
	IBOutlet NSTextField *mInfoVersionNumber;
    IBOutlet NSMenuItem *fullScreenMenuItem;
    SessionController *optionsCtrlr;
    LoginController *loginCtrlr;
    TunnelController *tunnelCtrlr;
    BugInfoController *bugCtrlr;
    NSMenuItem *tunnelMenuItem;
    BOOL noTunnel;      // set true after user says no to prompt for tunnel
}
- (IBAction)bugsAccount:(id)sender;
- (IBAction)myAccount:(id)sender;
@property (assign) IBOutlet NSMenuItem *tunnelMenuItem;
- (IBAction)doStopSession:(id)sender;

- (IBAction)toggleToolbar:(id)sender;
- (IBAction)doTunnel:(id)sender;
- (void)toggleTunnelDisplay;

@property (retain)SessionController *optionsCtrlr;
@property (retain)LoginController *loginCtrlr;
@property (retain)TunnelController *tunnelCtrlr;
@property (retain)BugInfoController *bugCtrlr;
@property  (assign)BOOL noTunnel;

- (IBAction)showOptionsDlg:(id)sender;
- (void)showOptionsIfNoTabs;
- (IBAction)showLoginDlg:(id)sender;

- (IBAction)showPreferences: (id)sender;
//- (IBAction)changeRendezvousUse:(id)sender;
- (IBAction)showNewConnectionDialog:(id)sender;
- (IBAction)showConnectionDialog: (id)sender;
//- (IBAction)showListenerDialog: (id)sender;
- (IBAction)showProfileManager: (id)sender;
- (IBAction)showHelp: (id)sender;

-(void)connectionSucceeded;
- (void)cancelOptionsConnect:(id)sender;

- (NSMenuItem *)getFullScreenMenuItem;

@end
