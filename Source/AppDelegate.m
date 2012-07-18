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


@implementation AppDelegate
@synthesize tunnelMenuItem;
@synthesize noTunnel;

@synthesize optionsCtrlr;
@synthesize loginCtrlr;
@synthesize tunnelCtrlr;
@synthesize bugCtrlr;


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

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSNotification *)aNotification
{
    if(tunnelCtrlr)
        [tunnelCtrlr terminate];
    return YES;
        
}

- (IBAction)showOptionsDlg:(id)sender 
{
    if(loginCtrlr)
        [loginCtrlr doCancelLogin:self];
    loginCtrlr = nil;
    if(!optionsCtrlr)
    {
        
        BOOL bSubscribed = [[SaucePreconnect sharedPreconnect] checkAccountOk:YES];  // ask if user is subscribed
        if(!bSubscribed)
        {
             BOOL bMinutes = [[SaucePreconnect sharedPreconnect] checkAccountOk:NO];  // ask if user has minutes
             if(!bMinutes)
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

-(void)showOptionsIfNoTabs
{
    if([[ScoutWindowController sharedScout] tabCount] == 1)     // just history tab; no sessions
    {
        [[[ScoutWindowController sharedScout] toolbar] setVisible:NO];
// just show history tab. user has to use menu/shortcut key to start new session
//        [self showOptionsDlg:self];
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
        NSBeginAlertSheet(header, okayButton, nil, nil, [[ScoutWindowController sharedScout] window], self, nil, @selector(errDidDismiss:returnCode:contextInfo:), nil, errMsg);
    }
    else
        [self showOptionsIfNoTabs];
}

- (void)errDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [self showOptionsIfNoTabs];
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
        self.tunnelCtrlr = [[TunnelController alloc] init];
    [tunnelCtrlr runSheetOnWindow:win];
    [self toggleTunnelDisplay];
}

- (void)escapeOptionDlg
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
        [self showOptionsIfNoTabs];
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
    NSString *header = NSLocalizedString( @"Should Subscribe", nil );
    NSString *okayStr = NSLocalizedString( @"Subscribe", nil );
    NSString *noStr = NSLocalizedString( @"Continue Scouting", nil );
    NSString *subscribeMsg;
    if(bCause)
        subscribeMsg = @"You need to subscribe to have more than 2 sessions open";
    else
        subscribeMsg = @"You need to subscribe to have enough minutes for more sessions";
    
    NSBeginAlertSheet(header, okayStr, noStr, nil, [[ScoutWindowController sharedScout] window], self, nil, @selector(subscribeDidDismiss:returnCode:contextInfo:), nil, subscribeMsg);
    
}

- (void)subscribeDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    if(returnCode == NSAlertDefaultReturn)      // go to subscribe page
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.saucelabs.com/pricing"]];

}

@end
