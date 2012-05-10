//
//  AppDelegate.m
//  Chicken of the VNC
//
//  Created by Jason Harris on 8/18/04.
//  Copyright 2004 Geekspiff. All rights reserved.
//

#import "AppDelegate.h"
#import "KeyEquivalentManager.h"
#import "PrefController.h"
#import "ProfileManager.h"
#import "RFBConnectionManager.h"
#import "ListenerController.h"
#import "LoginController.h"
#import "SaucePreconnect.h"
#import "SessionController.h"
#import "ScoutWindowController.h"


@implementation AppDelegate

@synthesize optionsCtrlr;
@synthesize loginCtrlr;

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	// make sure our singleton key equivalent manager is initialized, otherwise, it won't watch the frontmost window
	[KeyEquivalentManager defaultManager];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [[ScoutWindowController sharedScout] showWindow:nil];
    
    
    // check for username/key in prefs
    NSUserDefaults* user = [NSUserDefaults standardUserDefaults];
    NSString *uname = [user stringForKey:kUsername];
    NSString *akey = [user stringForKey:kAccountkey];
    BOOL bLoginDlg = YES;
    
    if([uname length] && [akey length])
    {
        if([[SaucePreconnect sharedPreconnect] checkUserLogin:uname  key:akey])
        {
            // good name/key, so go on to options dialog
            [self showOptionsDlg:self];            
            bLoginDlg = NO;
        }
    }
    if(bLoginDlg)
    {
        [self showLoginDlg:self];
    }

    [mInfoVersionNumber setStringValue: [[[NSBundle mainBundle] infoDictionary] objectForKey: @"CFBundleVersion"]];
}

- (IBAction)showOptionsDlg:(id)sender 
{
    if(loginCtrlr)
        [loginCtrlr doCancelLogin:self];
    loginCtrlr = nil;
    self.optionsCtrlr = [[SessionController alloc] init];
    [optionsCtrlr runSheet];
}

-(void)connectionSucceeded
{
    [optionsCtrlr connectionSucceeded];
    self.optionsCtrlr = nil;    
}

- (void)newUserAuthorized:(id)param
{
    [loginCtrlr login:nil];
    [self showOptionsDlg:nil];
}

- (void)preAuthorizeErr
{
    NSString *err = [[SaucePreconnect sharedPreconnect] errStr];
    [optionsCtrlr showError:err];
}

- (void)cancelOptionsConnect:(id)sender
{
    [[RFBConnectionManager sharedManager] cancelConnection];
    if(sender != [ScoutWindowController sharedScout])
        [optionsCtrlr cancelConnect:nil];
    self.optionsCtrlr = nil;    
}

- (IBAction)showLoginDlg:(id)sender 
{
    if(optionsCtrlr)
    {
        [NSApp endSheet:[optionsCtrlr panel]];
        [[optionsCtrlr panel] orderOut:nil]; 
        self.optionsCtrlr = nil;
    }
    self.loginCtrlr = [[LoginController alloc] init];
}

- (IBAction)showPreferences: (id)sender
{
	[[PrefController sharedController] showWindow];
}

- (BOOL) applicationShouldHandleReopen: (NSApplication *) app hasVisibleWindows: (BOOL) visibleWindows
{
	if(!visibleWindows)
	{
		[self showConnectionDialog:nil];
		return NO;
	}
	
	return YES;
}

- (IBAction)changeRendezvousUse:(id)sender
{
	PrefController *prefs = [PrefController sharedController];
	[prefs toggleUseRendezvous: sender];
	
	[mRendezvousMenuItem setState: [prefs usesRendezvous] ? NSOnState : NSOffState];
}


- (IBAction)showConnectionDialog: (id)sender
{  [[RFBConnectionManager sharedManager] showConnectionDialog: nil];  }

- (IBAction)showNewConnectionDialog:(id)sender
{  [[RFBConnectionManager sharedManager] showNewConnectionDialog: nil];  }

- (IBAction)showListenerDialog: (id)sender
{  [[ListenerController sharedController] showWindow: nil];  }


- (IBAction)showProfileManager: (id)sender
{  [[ProfileManager sharedManager] showWindow: nil];  }


- (IBAction)showHelp: (id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://saucelabs.com/scoutdesktop"]]; 
}

- (NSMenuItem *)getFullScreenMenuItem
{
    return fullScreenMenuItem;
}

- (IBAction)toggleToolbar:(id)sender {
    [[ScoutWindowController sharedScout] toggleToolbar];
}
@end
