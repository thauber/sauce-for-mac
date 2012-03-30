//
//  AppDelegate.h
//  Chicken of the VNC
//
//  Created by Jason Harris on 8/18/04.
//  Copyright 2004 Geekspiff. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SaucePreconnect.h"

@interface AppDelegate : NSObject {
	IBOutlet NSMenuItem *mRendezvousMenuItem;
	IBOutlet NSTextField *mInfoVersionNumber;
    IBOutlet NSMenuItem *fullScreenMenuItem;    
}
- (IBAction)showLoginDlg:(id)sender;

- (IBAction)showPreferences: (id)sender;
- (IBAction)changeRendezvousUse:(id)sender;
- (IBAction)showNewConnectionDialog:(id)sender;
- (IBAction)showConnectionDialog: (id)sender;
- (IBAction)showListenerDialog: (id)sender;
- (IBAction)showProfileManager: (id)sender;
- (IBAction)showHelp: (id)sender;

- (NSMenuItem *)getFullScreenMenuItem;

@end
