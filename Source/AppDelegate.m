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
#import "sessionConnect.h"


@implementation AppDelegate
@synthesize infoPanel;
@synthesize versionTxt;
@synthesize subscribeMenuItem;
@synthesize tunnelMenuItem;
@synthesize viewConnectMenuItem;
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
    [viewConnectMenuItem setAction:nil];
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
    // check for username/key in prefs
    NSUserDefaults* user = [NSUserDefaults standardUserDefaults];
    NSString *uname = [user stringForKey:kUsername];
    NSString *akey = [user stringForKey:kAccountkey];
   
    if([uname length] && [akey length])
    {
        NSString *userOk = [[SaucePreconnect sharedPreconnect] checkUserLogin:uname  key:akey];
        if([userOk characterAtIndex:0] == 'F')
        {
            [self internetNotOkDlg];
            return NO;      // still no connection
        }
        if(userOk)      // TODO: display error message
            [self showLoginDlg:self];
        return userOk == nil;      // connection ok, but maybe no valid user
    }
    [self showLoginDlg:self];
    return NO;              // no valid user

}

- (void)internetNotOkDlg
{
    NSString *header = NSLocalizedString( @"Connection Status", nil );
    NSString *okayButton = NSLocalizedString( @"Ok", nil );
    NSBeginAlertSheet(header, okayButton, nil, nil, [[ScoutWindowController sharedScout] window], self, nil, nil, nil, @"Check your internet connection - or Sauce Labs server may be down");
    
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
        
        NSString *subscribed = [[SaucePreconnect sharedPreconnect] checkAccountOk];  // ask if user is subscribed or has enough minutes
        if([subscribed characterAtIndex:0] == 'F')      // failed internet
        {
            [self internetNotOkDlg];
            return;
        }
        if([subscribed characterAtIndex:0] == 'N')      // not subscribed
        {
             if([subscribed characterAtIndex:1] == '-') // not enough minutes
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

- (void)startConnecting:(NSMutableDictionary*)sdict
{
    self.optionsCtrlr = nil;
    sessionConnect *sc = [[sessionConnect alloc] init];
    // link rfbview being created to this sessionconnect obj
    [sdict setObject:sc forKey:@"sessionConnect"];
    // add view as new tab
    NSTabViewItem *newItem = [[[NSTabViewItem alloc] initWithIdentifier:nil] autorelease];
    [newItem setView:[sc view]];
	[newItem setLabel:@"Connecting"];       // TODO: make actual label
	[[[ScoutWindowController sharedScout] tabView] addTabViewItem:newItem];
    
    [NSThread detachNewThreadSelector:@selector(preAuthorize:) toTarget:[SaucePreconnect sharedPreconnect] withObject:sdict];
}

-(void)connectionSucceeded
{
    // TODO: swap new view in for correct sessionConnect obj
}

- (void)newUserAuthorized:(id)param
{
    [loginCtrlr login:nil];
    [self showOptionsDlg:nil];
}

- (void)cancelOptionsConnect:(id)sdict
{
    NSMutableDictionary *theDict = sdict;
    
    [[RFBConnectionManager sharedManager] cancelConnection];
    [[SaucePreconnect sharedPreconnect] cancelPreAuthorize:theDict];
    if(optionsCtrlr)
        [optionsCtrlr quitSheet];
    self.optionsCtrlr = nil;    

    NSString *errMsg = [theDict objectForKey:@"errorString"];
    if(errMsg)
    {
        NSString *header = NSLocalizedString( @"Connection Status", nil );
        NSString *okayButton = NSLocalizedString( @"Ok", nil );
        NSBeginAlertSheet(header, okayButton, nil, nil, [[ScoutWindowController sharedScout] window], self, nil, nil, nil, errMsg);
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

- (IBAction)viewConnect:(id)sender
{
    if(tunnelCtrlr)    // need to create the tunnel object
    {
        NSWindow *win = [[ScoutWindowController sharedScout] window];
        [tunnelCtrlr runSheetOnWindow:win]; 
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
        [optionsCtrlr quitSheet];
        self.optionsCtrlr = nil;
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
        [viewConnectMenuItem setAction:@selector(viewConnect:)];
        [[[ScoutWindowController sharedScout] tunnelButton] setTitle:@"Stop Sauce Connect"];
    }
    else    // no tunnel
    {
        [[ScoutWindowController sharedScout] tunnelConnected:NO];
        [tunnelMenuItem setTitle:@"Start Sauce Connect"];
        [viewConnectMenuItem setAction:nil];
        [[[ScoutWindowController sharedScout] tunnelButton] setTitle:@"Start Sauce Connect"];
    }
}

- (IBAction)myAccount:(id)sender 
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.saucelabs.com/account"]];
}

- (IBAction)doAbout:(id)sender
{
    NSString *vstr = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    NSString *bstr = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"Build"];
    NSString *vtxt = [NSString stringWithFormat:@"Version: %@    Build: %@",vstr, bstr];
    [versionTxt setStringValue:vtxt];
    [infoPanel makeKeyAndOrderFront:self];    
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
