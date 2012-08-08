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
#import "LoginController.h"
#import "SaucePreconnect.h"
#import "SessionController.h"
#import "TunnelController.h"
#import "BugInfoController.h"
#import "ScoutWindowController.h"
#import "Subscriber.h"


@implementation AppDelegate
@synthesize subscribeMenuItem;
@synthesize tunnelMenuItem;
@synthesize noTunnel;

@synthesize optionsCtrlr;
@synthesize loginCtrlr;
@synthesize tunnelCtrlr;
@synthesize bugCtrlr;
@synthesize subscriberCtrl;
@synthesize noShowCloseSession;
@synthesize noShowCloseConnect;

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	// make sure our singleton key equivalent manager is initialized, otherwise, it won't watch the frontmost window
	[KeyEquivalentManager defaultManager];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    if(INAPPSTORE)
        [subscribeMenuItem setHidden:YES];
    [[ScoutWindowController sharedScout] showWindow:nil];
    
    [mInfoVersionNumber setStringValue: [[[NSBundle mainBundle] infoDictionary] objectForKey: @"CFBundleVersion"]];

    if([self checkUserOk])
    {
        // good name/key, so go on to options dialog
        [self showOptionsDlg:self];
    }
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSNotification *)aNotification
{
    if(tunnelCtrlr)
        [tunnelCtrlr terminate];
    return YES;
        
}

// if internet had been down, check if it is back up; returns 0=no user, 1=ok
- (BOOL)checkUserOk
{
   if([[SaucePreconnect sharedPreconnect] internetOk])
       return YES;
    
    // check for username/key in prefs
    NSUserDefaults* user = [NSUserDefaults standardUserDefaults];
    NSString *uname = [user stringForKey:kUsername];
    NSString *akey = [user stringForKey:kAccountkey];
    
    if([uname length] && [akey length])
    {
        NSInteger userOk = [[SaucePreconnect sharedPreconnect] checkUserLogin:uname  key:akey];
        if(userOk == -1)
        {
            [self internetNotOkDlg];
            return NO;      // still no connection
        }
        if(!userOk)
            [self showLoginDlg:self];
        return userOk;      // connection ok, but maybe no valid user
    }
    NSInteger userOk = [[SaucePreconnect sharedPreconnect] checkUserLogin:uname  key:akey];
    if(userOk == -1)
    {
        [self internetNotOkDlg];
        return NO;      // still no connection
    }
    [self showLoginDlg:self];
    return NO;              // no valid user
}

- (void)internetNotOkDlg
{
    NSString *header = NSLocalizedString( @"Connection Status", nil );
    NSString *okayButton = NSLocalizedString( @"Ok", nil );
    NSBeginAlertSheet(header, okayButton, nil, nil, [[ScoutWindowController sharedScout] window], self, nil, 
                      nil, nil, @"Check your internet connection - or Sauce Labs server may be down");
    
}
 
- (IBAction)showOptionsDlg:(id)sender 
{
    if(![self checkUserOk])
        return;
    
    if(loginCtrlr)
        [loginCtrlr doCancelLogin:self];
    loginCtrlr = nil;
    if(!optionsCtrlr)
    {
        
        NSInteger subscribed = [[SaucePreconnect sharedPreconnect] checkAccountOk:YES];  // ask if user is subscribed
        if(subscribed == -1)
        {
            [self internetNotOkDlg];
            return;
        }
        if(!subscribed)
        {
             NSInteger minutesOk = [[SaucePreconnect sharedPreconnect] checkAccountOk:NO];  // ask if user has minutes
            
             if(minutesOk == -1)
             {
                [self internetNotOkDlg];
                return;
             }
             if(!minutesOk)
             {
                 [self promptForSubscribing:NO];   // prompt for subscribing to get more minutes
                 return;
             }
            if([[ScoutWindowController sharedScout] tabCount] > 2)      // user has to be subscribed
            {
                [self promptForSubscribing:YES];   // prompt for subscribing to get more tabs
                return;
            }
        }
        
        self.optionsCtrlr = [[SessionController alloc] init];
        [optionsCtrlr runSheet];
    }
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
    if(err)
        [optionsCtrlr showError:err];
}

- (void)cancelOptionsConnect:(id)sender
{
    [[RFBConnectionManager sharedManager] cancelConnection];
    [[SaucePreconnect sharedPreconnect] setCancelled:YES];
    [[SaucePreconnect sharedPreconnect] cancelPreAuthorize:nil];
    if(optionsCtrlr)
        [optionsCtrlr quitSheet];
    self.optionsCtrlr = nil;    

    NSString *errMsg = [[SaucePreconnect sharedPreconnect] errStr];
    if(errMsg)
    {
        [[SaucePreconnect sharedPreconnect] setErrStr:nil];         // clear error string
        NSString *header = NSLocalizedString( @"Connection Status", nil );
        NSString *okayButton = NSLocalizedString( @"Ok", nil );
        NSBeginAlertSheet(header, okayButton, nil, nil, [[ScoutWindowController sharedScout] window], self, nil, 
                          nil, nil, errMsg);
    }
}

- (IBAction)showLoginDlg:(id)sender 
{
    if(optionsCtrlr)
    {
        [NSApp endSheet:[optionsCtrlr panel]];
        [[optionsCtrlr panel] orderOut:nil]; 
        self.optionsCtrlr = nil;
    }
    
    if(sender != self)
        [self checkUserOk];
    self.loginCtrlr = [[LoginController alloc] init];
}

- (IBAction)showSubscribeDlg:(id)sender
{
    if(self.optionsCtrlr)       // close the options sheet
    {
        [NSApp endSheet:[optionsCtrlr panel]];
        [[optionsCtrlr panel] orderOut:nil];
        self.optionsCtrlr = nil;    
    }
        
    [self promptForSubscribing:2];
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


- (IBAction)showConnectionDialog: (id)sender
{  [[RFBConnectionManager sharedManager] showConnectionDialog: nil];  }

- (IBAction)showNewConnectionDialog:(id)sender
{  [[RFBConnectionManager sharedManager] showNewConnectionDialog: nil];  }


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

- (IBAction)doStopSession:(id)sender
{
    [[ScoutWindowController sharedScout] doPlayStop:self];
}

- (IBAction)doStopConnect:(id)sender
{
    if(tunnelCtrlr)
    {
        [tunnelCtrlr doClose:self];
    }
}

- (void)closeStopConnect
{
    if(tunnelCtrlr)
    {
        [tunnelCtrlr setStopCtlr:nil];
    }
}

- (IBAction)toggleToolbar:(id)sender
{
    [[ScoutWindowController sharedScout] toggleToolbar];
}

- (IBAction)doTunnel:(id)sender
{
    if(self.optionsCtrlr)       // close the options sheet
    {
        [NSApp endSheet:[optionsCtrlr panel]];
        [[optionsCtrlr panel] orderOut:nil];
        self.optionsCtrlr = nil;    
    }
        
    NSWindow *win = [[ScoutWindowController sharedScout] window];
    
    if(!tunnelCtrlr)    // need to create the tunnel object
    {
        self.tunnelCtrlr = [[TunnelController alloc] init];
        [tunnelCtrlr runSheetOnWindow:win];
        [self toggleTunnelDisplay];
    }
    else  // asking to stop tunnel
    {
        [self doStopConnect:self];
    }
}

- (void)escapeDialog
{
    if(optionsCtrlr)
    {
        if([[[optionsCtrlr connectBtn] title] isEqualToString:@"Cancel"])
            [self cancelOptionsConnect:self];
        else
        {
            [optionsCtrlr quitSheet];
            self.optionsCtrlr = nil;
        }
    }
    else if(subscriberCtrl)
    {
        [subscriberCtrl quitSheet];
        self.subscriberCtrl = nil;
    }
}

- (void)toggleTunnelDisplay
{
    if(tunnelCtrlr)
    {
        [tunnelMenuItem setTitle:@"Stop Sauce Connect"];
        [[[ScoutWindowController sharedScout] tunnelButton] setTitle:@"Stop Sauce Connect"];
    }
    else    // no tunnel
    {
        [[ScoutWindowController sharedScout] tunnelConnected:NO];
        [tunnelMenuItem setTitle:@"Start Sauce Connect"];
        [[[ScoutWindowController sharedScout] tunnelButton] setTitle:@"Start Sauce Connect"];
    }
}

- (IBAction)myAccount:(id)sender 
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.saucelabs.com/account"]];
}

- (IBAction)bugsAccount:(id)sender 
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.saucelabs.com/bugs"]];
}

- (void)promptForSubscribing:(BOOL)bCause        // 0=needs more minutes; 1=to get more tabs
{
    if([self checkUserOk])
        subscriberCtrl = [[[Subscriber alloc] init:bCause] retain];
    
}

- (void)subscribeDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    if(returnCode == NSAlertDefaultReturn)      // go to subscribe page
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.saucelabs.com/pricing"]];

}

@end
