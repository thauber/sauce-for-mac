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


@implementation AppDelegate


- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	// make sure our singleton key equivalent manager is initialized, otherwise, it won't watch the frontmost window
	[KeyEquivalentManager defaultManager];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // check for username/key in prefs
    NSUserDefaults* user = [NSUserDefaults standardUserDefaults];
    NSString *uname = [user stringForKey:kUsername];
    NSString *akey = [user stringForKey:kAccountkey];
    BOOL bLoginDlg = YES;
    
    if([uname length] && [akey length])
    {
        if([[SaucePreconnect sharedPreconnect] checkUserLogin:uname  key:akey])
        {
            // good name/key, so get job-id and connect
//            [[RFBConnectionManager sharedManager] preconnect];  // TESTING
//            [[RFBConnectionManager sharedManager] connectToServer];
            bLoginDlg = NO;
        }
    }
    if(bLoginDlg)
    {
        [self showLoginDlg:self];
    }

/*		
    RFBConnectionManager *cm = [RFBConnectionManager sharedManager];
    if ( ! [cm runFromCommandLine] && ! [cm launchedByURL] )
		[cm runNormally];
    

	[mRendezvousMenuItem setState: [[PrefController sharedController] usesRendezvous] ? NSOnState : NSOffState];
*/	
    [mInfoVersionNumber setStringValue: [[[NSBundle mainBundle] infoDictionary] objectForKey: @"CFBundleVersion"]];

}


- (IBAction)showLoginDlg:(id)sender 
{
    LoginController *lc = [[LoginController alloc] initWithWindowNibName:@"LoginController"];
    [lc window];        // need this to get window shown
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
	NSString *path = [[NSBundle mainBundle] pathForResource: @"index" ofType: @"html" inDirectory: @"help"];
	[[NSWorkspace sharedWorkspace] openFile: path];
}

- (NSMenuItem *)getFullScreenMenuItem
{
    return fullScreenMenuItem;
}

@end
