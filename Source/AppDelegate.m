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
#import "RegexKitLite.h"
#import "waitSession.h"

@implementation AppDelegate
@synthesize infoPanel;
@synthesize versionTxt;
@synthesize subscribeMenuItem;
@synthesize tunnelMenuItem;
@synthesize viewConnectMenuItem;
@synthesize separatorMenuItem;
@synthesize myaccountMenuItem;
@synthesize bugsMenuItem;

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
    self.noTunnel = YES;        // no tunnel connection at startup
    NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
    [defs setInteger:0 forKey:@"demoRunSecs"];      // #demo minutes used
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    noShowCloseSession = [[PrefController sharedController] defaultShowWarnings];
    noShowCloseConnect = noShowCloseSession;
    
    [self processCommandLine];
    
    if(INAPPSTORE)
    {
        [subscribeMenuItem setHidden:YES];
        [separatorMenuItem setHidden:YES];
    }
    BOOL bDemo = [self isDemoAccount];
    
    [viewConnectMenuItem setAction:nil];
    [[ScoutWindowController sharedScout] showWindow:nil];

    if(bDemo)
    {
        [[PrefController sharedController] setAlwaysUseTunnel:NO];
    }
        
    [mInfoVersionNumber setStringValue: [[[NSBundle mainBundle] infoDictionary] objectForKey: @"CFBundleVersion"]];

    if([self checkUserOk])
    {
        // good name/key, got browsers, so go on to options dialog
        if([[PrefController sharedController] alwaysUseTunnel] || cmdConnect)
            [self doTunnel:self];
        else
        if(bCommandline)
        {
            NSMutableDictionary *sdict = [[SaucePreconnect sharedPreconnect] setOptions:cmdOS browser:cmdBrowser browserVersion:cmdVersion url:cmdURL resolution:cmdResolution];
            [self startConnecting:sdict];
        }
        else
            [self showOptionsDlg:self];
    }
    [NSEvent addLocalMonitorForEventsMatchingMask:NSKeyDownMask handler:^NSEvent *(NSEvent *evt) {
        bool isRightEvent = [evt type] == NSKeyDown;
        bool isRightKey = [evt keyCode] == 43;
        bool isRightModifier = [evt modifierFlags] & NSCommandKeyMask;
        if (isRightEvent && isRightModifier && isRightKey) {
            [self showPreferences:nil];
            return nil;
        }
        return evt;
    }];
}

- (void)processCommandLine
{
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
    
    // NB: should be checking for browser/version/os matching
    
    cmdOS = [standardDefaults stringForKey:@"o"];
    if(!cmdOS) return;
    if([cmdOS hasPrefix:@"w"] || [cmdOS hasPrefix:@"W"])
    {
        if([cmdOS rangeOfString:@"3"].location != NSNotFound)
            cmdOS = @"Windows 2003";
        else if([cmdOS rangeOfString:@"8"].location != NSNotFound)
            cmdOS = @"Windows 2008";
    }
    else
    if([cmdOS hasPrefix:@"l"] || [cmdOS hasPrefix:@"L"])
        cmdOS = @"Linux";
    else
    if([cmdOS hasPrefix:@"o"] || [cmdOS hasPrefix:@"O"])
        cmdOS = @"OSX";
    
    cmdBrowser = [standardDefaults stringForKey:@"b"];
    if(!cmdBrowser) return;
    if([cmdBrowser hasPrefix:@"i"] || [cmdBrowser hasPrefix:@"I"])
        cmdBrowser = @"iexplore";
    else
    if([cmdBrowser hasPrefix:@"o"] || [cmdBrowser hasPrefix:@"O"])
        cmdBrowser = @"opera";
    else
    if([cmdBrowser hasPrefix:@"f"] || [cmdBrowser hasPrefix:@"F"])
        cmdBrowser = @"firefox";
    else
    if([cmdBrowser hasPrefix:@"s"] || [cmdBrowser hasPrefix:@"S"])
        cmdBrowser = @"safari";
    else
    if([cmdBrowser hasPrefix:@"c"] || [cmdBrowser hasPrefix:@"C"])
        cmdBrowser = @"googlechrome";
    else
    if([cmdBrowser hasPrefix:@"a"] || [cmdBrowser hasPrefix:@"A"])
        cmdBrowser = @"android";
    else
    if([cmdBrowser hasPrefix:@"iph"] || [cmdBrowser hasPrefix:@"IPh"])
        cmdBrowser = @"iphone";
    else
    if([cmdBrowser hasPrefix:@"ipa"] || [cmdBrowser hasPrefix:@"IPa"])
        cmdBrowser = @"ipad";
    else
        return;     // not a valid browser
    
    cmdVersion = [standardDefaults stringForKey:@"v"];
    if(!cmdVersion) return;     // assume it is valid for now
    
    cmdURL = [standardDefaults stringForKey:@"u"];
    if(!cmdURL) return;
    
    cmdConnect = [standardDefaults stringForKey:@"c"];
    
    cmdResolution = [standardDefaults stringForKey:@"res"];
    if(!cmdResolution)
        cmdResolution = @"1024x768";
    
    bCommandline = YES;

    // uncomment 2 lines below to check arguments in alert panel
//    NSString *args = [NSString stringWithFormat:@"-o %@ -b %@ -v %@ -c %@", cmdOS,cmdBrowser,cmdVersion,cmdConnect];
//    NSBeginAlertSheet(@"Command Line Args", @"Okay", nil, nil, [NSApp keyWindow], self,nil, NULL, NULL, @"%@",args);

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
    else
    if(INAPPSTORE)
    {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:kDemoAccountName  forKey:kUsername];
        [defaults setObject:kDemoAccountKey  forKey:kAccountkey];
        [[NSUserDefaults standardUserDefaults] setObject:nil forKey:kSessionURL];
        [[SaucePreconnect sharedPreconnect] checkUserLogin:kDemoAccountName  key:kDemoAccountKey];
        [self prefetchBrowsers];
        [self toggleTunnelDisplay];
        return YES;
    }
    [self showLoginDlg:self];
    return NO;              // no valid user
}

- (void)internetNotOkDlg
{
    NSString *header = NSLocalizedString( @"Connection Status", nil );
    NSString *okayButton = NSLocalizedString( @"OK", nil );
    NSBeginAlertSheet(header, okayButton, nil, nil, [[ScoutWindowController sharedScout] window], self, nil, nil, nil, @"%@",@"Check your internet connection - or Sauce Labs server may be down");
    
}
 
- (IBAction)showOptionsDlg:(id)sender 
{
    bCommandline = NO;
    
    if(![self checkUserOk])
        return;
    if(![configsOS[tt_winxp] count] && [self prefetchBrowsers] != 1)
        return;
    
    if(loginCtrlr)
        [loginCtrlr doCancelLogin:self];
    loginCtrlr = nil;
    if(!optionsCtrlr)
    {
       if([self checkaccount])
       {
           self.optionsCtrlr = [[SessionController alloc] init];
           [optionsCtrlr runSheet];
       }
    }
}

- (BOOL)checkaccount
{
    NSString *subscribed = [[SaucePreconnect sharedPreconnect] checkAccountOk];  // ask if user is subscribed or has enough minutes
    if([subscribed characterAtIndex:0] == 'F')      // failed internet
    {
        [self internetNotOkDlg];
        return NO;
    }
    if([subscribed characterAtIndex:0] == 'N')      // not subscribed
    {
        if([subscribed characterAtIndex:1] == '-') // not enough minutes
        {
            [self promptForSubscribing:0];   // prompt for subscribing to get more minutes
            return NO;
        }
        if([[ScoutWindowController sharedScout] tabCount] > 2)      // user has to be subscribed
        {
            [self promptForSubscribing:1];   // prompt for subscribing to get more tabs
            return NO;
        }
    }
    else        // demo account says 'true' for being subscribed
    if([self isDemoAccount])
    {
        if([[ScoutWindowController sharedScout] tabCount] > 1)
        {
            [self promptForSubscribing:1];   // prompt for subscribing to get more tabs
            return NO;
        }
#if 0
        else    // no sessions running
        {
            NSInteger tm = [self demoCheckTime];
            if(tm > 0)      // still time left to wait
            {
                [[waitSession alloc] init:tm];    // tell user how many minutes to wait
                return NO;
            }
        }
#endif
    }
    return YES;
}

- (void)startConnecting:(NSMutableDictionary*)sdict
{
    self.optionsCtrlr = nil;
    sessionConnect *sc = [[sessionConnect alloc] initWithDict:sdict];
    // link rfbview being created to this sessionconnect obj
    [sdict setObject:sc forKey:@"sessionConnect"];
    [sdict setObject:[sc view] forKey:@"scview"];
    // add view as new tab
    NSTabViewItem *newItem = [[[NSTabViewItem alloc] initWithIdentifier:nil] autorelease];
    [newItem setView:[sc view]];
	[newItem setLabel:@"Connecting"];       // TODO: make actual label
    [[ScoutWindowController sharedScout] addTabItem:newItem];
    
    [NSThread detachNewThreadSelector:@selector(preAuthorize:) toTarget:[SaucePreconnect sharedPreconnect] withObject:sdict];
}

-(void)connectionSucceeded:(NSMutableDictionary*)sdict
{
    [[SaucePreconnect sharedPreconnect] cancelPreAuthorize:sdict];
    if([self isDemoAccount])
    {
        // set 'last time' value to now
        time_t tm;
        time(&tm);
        NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
        [defs setInteger:tm forKey:@"demoLastTime"];
        NSInteger runSecs = [defs integerForKey:@"demoRunSecs"];
        if(runSecs >= 600)   // we allowed this session even though used 10 minutes run time,
            [defs setInteger:0 forKey:@"demoRunSecs"];      // means we have waited long enough

        // track demo account version
        NSString *job = [sdict objectForKey:@"jobId"];
        NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
        [[SaucePreconnect sharedPreconnect] sendDemoVersion:job version:version];
    }
}

- (void)newUserAuthorized:(id)param
{
    [loginCtrlr login:nil];
    [self showOptionsDlg:nil];
}

- (void)cancelOptionsConnect:(id)sdict
{
    NSMutableDictionary *theDict = sdict;
    
    [[ScoutWindowController sharedScout] closeTab:sdict];
    
    NSString *errMsg = [theDict objectForKey:@"errorString"];
    if(errMsg)
    {
        NSString *header = NSLocalizedString( @"Connection Status", nil );
        NSString *okayButton = NSLocalizedString( @"OK", nil );
        NSBeginAlertSheet(header, okayButton, nil, nil, [[ScoutWindowController sharedScout] window], self, nil, nil, nil, @"%@",errMsg);
    }
}

- (IBAction)showLoginDlg:(id)sender 
{
    if(subscriberCtrl)
    {
        [subscriberCtrl quitSheet];
    }
    else
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
    BOOL bCause=2;      // default is 'from menu'
    if(!sender)     // from SaucePreconnect when no time left on account
    {
        [[ScoutWindowController sharedScout] closeAllTabs];
        bCause = 0;     // out of minutes
    }
        
    [self promptForSubscribing:bCause];
}

- (IBAction)showPreferences: (id)sender
{
	[[PrefController sharedController] showWindow];
}

- (BOOL)isDemoAccount
{
    NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
    NSString *uname = [defs stringForKey:kUsername];
    BOOL bDemo = [uname isEqualToString:kDemoAccountName];
    [myaccountMenuItem setAction:bDemo?nil:@selector(myAccount:)];
    [bugsMenuItem setAction:bDemo?nil:@selector(bugsAccount:)];

    return bDemo;
}
    
- (NSInteger)demoCheckTime
{
    NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
    NSInteger lastTime = [defs integerForKey:@"demoLastTime"];
    NSInteger runSecs = [defs integerForKey:@"demoRunSecs"];
    if(lastTime==0)     // not recorded a time, so its ok
        return -1;
    if(runSecs < 600)    // haven't used up the allotted 10 minutes before having to wait
        return -1;
    time_t rawtime, tt;
    time(&rawtime);
    tt = rawtime - lastTime;
    int mins = 30 - (tt/60);       // #seconds divided by 60 is #minutes since last run
    return mins;
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
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://saucelabs.com/mac/help"]]; 
}

- (IBAction)refreshAllSessions:(id)sender
{
    [[ScoutWindowController sharedScout] refreshAllTabs];
}

- (IBAction)resetSauce:(id)sender
{
    NSBeginAlertSheet(@"Reset Sauce", @"OK", @"Cancel", nil, [NSApp keyWindow], self, nil, @selector(doReset:returnCode:contextInfo:), nil, @"%@",@"Do you want to remove all your data and send the app back to it's original state");

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:kDemoAccountName  forKey:kUsername];
    [defaults setObject:kDemoAccountKey  forKey:kAccountkey];
    [defaults setObject:@"" forKey:kUserPassword];
    [[NSApp delegate] prefetchBrowsers];
    [[NSApp delegate] toggleTunnelDisplay];
}

-(void)doReset:(NSWindow*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
    if(returnCode==NSOKButton)
    {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:kDemoAccountName  forKey:kUsername];
        [defaults setObject:kDemoAccountKey  forKey:kAccountkey];
        [defaults setObject:@"" forKey:kUserPassword];
        [[NSApp delegate] prefetchBrowsers];
        [[NSApp delegate] toggleTunnelDisplay];
        if(optionsCtrlr)
        {
            [optionsCtrlr quitSheet];
            [self showOptionsDlg:self];
        }
    }
}

- (NSMenuItem *)getFullScreenMenuItem
{
    return fullScreenMenuItem;
}

- (IBAction)doStopSession:(id)sender
{
    [[ScoutWindowController sharedScout] doPlayStop:sender];
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
    if(tunnelCtrlr)    // need to display the tunnel object
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
    if(!tunnelCtrlr && [self checkTunnelRunning])       // tunnel was run externally
        return;
    
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

-(BOOL)checkTunnelRunning
{
    NSString *farg = @"ps ax |grep Sauce-Connect.jar";
    NSTask *ftask = [[[NSTask alloc] init] autorelease];
    NSPipe *fpipe = [NSPipe pipe];
    [ftask setStandardOutput:fpipe];
    [ftask setLaunchPath:@"/bin/bash"];
    [ftask setArguments:[NSArray arrayWithObjects:@"-c", farg, nil]];
    [ftask launch];		// NB: hangs if call 'waitUntilExit'
    NSFileHandle *fhand = [fpipe fileHandleForReading];
    NSData *data = [fhand readDataToEndOfFile];
    NSString *rstr = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    return [rstr rangeOfString:@"/Sauce"].location != NSNotFound;
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
    BOOL bDemo = [self isDemoAccount];
    if(bDemo)
    {
        [tunnelMenuItem setAction:nil];
        return;
    }

    if(tunnelCtrlr)
    {
        [tunnelMenuItem setTitle:@"Stop Sauce Connect"];
        [viewConnectMenuItem setAction:@selector(viewConnect:)];
        [[[ScoutWindowController sharedScout] tunnelButton] setTitle:@"Stop Sauce Connect"];
        if(bCommandline)
        {
            NSMutableDictionary *sdict = [[SaucePreconnect sharedPreconnect] setOptions:cmdOS browser:cmdBrowser browserVersion:cmdVersion url:cmdURL resolution:cmdResolution];
            [self startConnecting:sdict];            
        }
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
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.saucelabs.com/snapshots"]];
}

- (void)promptForSubscribing:(BOOL)bCause        // 0=needs more minutes; 1=to get more tabs
{
    if(optionsCtrlr)
    {
        [NSApp endSheet:[optionsCtrlr panel]];
        [[optionsCtrlr panel] orderOut:nil];
        self.optionsCtrlr = nil;
    }
    if([self checkUserOk])
            subscriberCtrl = [[[Subscriber alloc] init:bCause] retain];
}

- (void)subscribeDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    if(returnCode == NSAlertOtherReturn)      // go to subscribe page
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://saucelabs.com/signup?s4m"]];

}

-(NSArray*)data2json:(NSData*)data
{
    NSMutableArray *jarr = [[NSMutableArray alloc] init];
    NSString *jstr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray *barr = [jstr componentsSeparatedByString:@"{"];
    [jstr release];
    NSEnumerator *ee = [barr objectEnumerator];
    NSString *jbrwsr;
    while (jbrwsr = [ee nextObject])
    {
        if([jbrwsr length] < 4)     // skip leading left bracket
            continue;
        NSMutableDictionary *bdict = [[NSMutableDictionary alloc] init];
        NSArray *qarr = [jbrwsr componentsSeparatedByString:@":"];
        int qcount = [qarr count];
        int indx = 0;
        NSString *qvalkey = [qarr objectAtIndex:indx++];     // first key
        NSArray *valkey = [qvalkey componentsSeparatedByString:@"\""];
        NSString *key = [valkey objectAtIndex:1];
        while(indx<qcount)
        {
            NSString *qvalkey = [qarr objectAtIndex:indx++];
            if([qvalkey hasPrefix:@" ["])     // value is an array
            {
                valkey = [qvalkey componentsSeparatedByString:@"\""];
                NSMutableArray *rarr = [[NSMutableArray alloc] init];
                int rcount = [valkey count];
                int rindx = 1;
                while(rindx<rcount)
                {
                    [rarr addObject:[valkey objectAtIndex:rindx]];
                    if([[valkey objectAtIndex:++rindx] hasPrefix:@"]"])
                        break;
                     rindx++;
                }
                [bdict setObject:rarr forKey:key];
                [rarr release];
                key = [valkey objectAtIndex:++rindx];
            }
            else
            {
                valkey = [qvalkey componentsSeparatedByString:@"\""];
                NSString *val = [valkey objectAtIndex:1];
                [bdict setObject:val forKey:key];
                if([valkey count]<4)
                    break;
                key = [valkey objectAtIndex:3];
            }
        }
        [jarr addObject:bdict];
        [bdict release];
    }

    return jarr;
}

// get json data for browsers from server
- (NSInteger)prefetchBrowsers
{
    NSInteger bres = -1;

    NSString *farg = [NSString stringWithFormat:@"curl 'http://%@/rest/v1.1/info/scout' -H 'Content-Type: application/json'", kSauceLabsDomain];
    
    NSTask *ftask = [[[NSTask alloc] init] autorelease];
    NSPipe *fpipe = [NSPipe pipe];
    [ftask setStandardOutput:fpipe];
    [ftask setLaunchPath:@"/bin/bash"];
    [ftask setArguments:[NSArray arrayWithObjects:@"-c", farg, nil]];
    [ftask launch];		// fetch json browser data  NB: hangs if call 'waitUntilExit'
    NSFileHandle *fhand = [fpipe fileHandleForReading];        
    NSData *data = [fhand readDataToEndOfFile];
    NSArray *jsonArr = [self data2json:data];
    if(jsonArr)
    {
        [self parseBrowsers:jsonArr];
        [jsonArr release];
        return 1;       // get valid data
    }
    else 
        bres = 0;   // didn't get valid data
    
    NSString *msg;
    if(bres==-1)        // NB: not getting this value anymore
        msg = @"Failed connection to server";
    else
        msg = @"Can't retrieve browser data";
    NSBeginAlertSheet(@"Browser Data", @"Ok", nil, nil, [[ScoutWindowController sharedScout] window], self, nil, nil, nil, @"%@",msg);
    return bres;
}


NSComparisonResult dcmp(id arg1, id arg2, void *dummy)
{
    NSComparisonResult res = NSOrderedSame;
    NSDictionary *dict1 = arg1;
    NSDictionary *dict2 = arg2;
    NSString *OS1 = [dict1 objectForKey:@"os"];
    NSString *OS2 = [dict2 objectForKey:@"os"];
    res = [OS1 compare:OS2];
    if(res != NSOrderedSame)
        return res;
    NSString *name1 = [dict1 objectForKey:@"name"];
    NSString *name2 = [dict2 objectForKey:@"name"];

    res = [name1 compare:name2];
    if(res != NSOrderedSame)
        return res;
    NSString *ver1 = [dict1 objectForKey:@"short_version"];
    NSString *ver2 = [dict2 objectForKey:@"short_version"];
    NSInteger iv1 = [ver1 integerValue];
    NSInteger iv2 = [ver2 integerValue];
    if(iv1<iv2)
        return NSOrderedAscending;
    if(iv1>iv2)
        return NSOrderedDescending;
    res = [ver1 compare:ver2];
    if(res != NSOrderedSame)
        return res;    
    OS1 = [dict1 objectForKey:@"os"];
    OS2 = [dict2 objectForKey:@"os"];
    res = [OS1 compare:OS2];    
    return res;
    
}

- (int)numActiveBrowsers:(ttType)os
{
    return activeOS[os];
}

// read data ifrom server into dictionaries
- (void)parseBrowsers:(NSArray*)jsonArr
{
    for(int i=0;i<kNumTabs;i++)        // release old values
    {
        [configsOS[i] release];
    }
    for(int i=0;i<kNumTabs;i++)                 // create new set of arrays
    {
        configsOS[i] = [[[NSMutableArray alloc] init] retain];     // os/browsers for osx
        activeOS[i] = 0;        // track active browsers for each os
    }
    
    // pull out the lines into an array
    NSArray *sarr = [jsonArr sortedArrayUsingFunction:dcmp context:nil];

    BOOL bDemo = [self isDemoAccount];

    NSInteger inserts[kNumTabs];
    for(int i=0;i<kNumTabs;i++)
        inserts[i] = 0; 

    NSString *osStr;
    NSString *browser;
    NSString *version;
    NSString *resolutions;
    NSString *active;
    BOOL bMacgoogleVer = NO;
    
    for(NSDictionary *dict in sarr)
    {
        osStr   = [dict objectForKey:@"os"];
        browser = [dict objectForKey:@"name"];
        version = [dict objectForKey:@"short_version"];
        resolutions = [dict objectForKey:@"resolutions"];
                        
        if(![version length])       // only retain 1 mac chrome browser in list
        {
            if([osStr hasPrefix:@"M"] && ([browser hasPrefix:@"g"] || [browser hasPrefix:@"c"]))
            {
                if(!bMacgoogleVer)
                {
                    bMacgoogleVer = YES;    // only have 1 mac google item
                    version=@"*";
                }
                else
                    continue;
            }
        }
        
        BOOL bActive = YES;
        if(bDemo)
        {
            if([osStr hasPrefix:@"W"])
            {
                if([osStr rangeOfString:@"3"].location != NSNotFound)
                {
                    if([browser hasPrefix:@"i"])
                    {
                        if(![version isEqualToString:@"6"]
                           && ![version isEqualToString:@"7"]
                           && ![version isEqualToString:@"8"])
                            bActive = NO;
                    }
                    else
                        bActive = NO;
                }
                else
                if([osStr rangeOfString:@"8"].location != NSNotFound)
                {
                    if([browser hasPrefix:@"i"])
                    {
                           
                       if(![version isEqualToString:@"9"])
                           bActive = NO;
                    }
                    else
                        bActive = NO;
                }
                else
                if([osStr rangeOfString:@"12"].location != NSNotFound)
                {
                    if([browser hasPrefix:@"i"])
                    {
                       if(![version isEqualToString:@"10"])
                           bActive = NO;
                    }
                    else
                       bActive = NO;
                }
            }
            else
            if([osStr hasPrefix:@"M"])
            {                   
                if([browser hasPrefix:@"i"])
                {
                    if([browser hasPrefix:@"ipa"])      // only iphone for ios
                        bActive = NO;
                }
                else        // assume it is osx browser
                if([browser hasPrefix:@"s"])
                {
                   if(![version isEqualToString:@"5"])
                       bActive = NO;
                }
                else
                    bActive = NO;
            }
            else
            if([osStr hasPrefix:@"L"] && ![version isEqualToString:@"17"])
                bActive = NO;        
        }
        
        active  = bActive ? @"YES" : @"NO";

        NSMutableArray *obarr = [NSMutableArray arrayWithCapacity:5];
        [obarr  addObject:osStr];
        [obarr  addObject:browser];
        [obarr  addObject:version];
        [obarr  addObject:active];
        [obarr  addObject:resolutions];
        
        if([osStr hasPrefix:@"Windows"])
        {
            ttType indx = tt_winxp;
            if([osStr rangeOfString:@"8"].location != NSNotFound)
                indx = tt_win7;
            else
            if([osStr rangeOfString:@"12"].location != NSNotFound)
                indx = tt_win8;
            
            if(bDemo && bActive)
                [configsOS[indx] insertObject:obarr atIndex:inserts[indx]++];
            else
                [configsOS[indx] addObject:obarr];
        }
        else
        if([osStr hasPrefix:@"Linux"])
        {
            if(bDemo && bActive)
                [configsOS[tt_linux] insertObject:obarr atIndex:inserts[tt_linux]++];
            else
                [configsOS[tt_linux] addObject:obarr];
        }
        else
        if([osStr hasPrefix:@"Mac"])
        {
            ttType indx = tt_macosx;
            if([browser hasPrefix:@"i"])
                indx = tt_macios;
            
            if(bDemo && bActive)
                [configsOS[indx] insertObject:obarr atIndex:inserts[indx]++];
            else
                [configsOS[indx] addObject:obarr];
        }
    }
    for(int i=0;i<kNumTabs;i++)
        activeOS[i] = bDemo ? inserts[i] : [configsOS[i] count];
    [self setupFromConfig];
}

- (NSArray*)getConfigsOS:(int)indx
{
    return configsOS[indx];
}

- (NSArray*)getBrAStrsOs:(int)indx
{
    return brAStrsOs[indx];
}

- (NSAttributedString*)getOsAStrs:(int)indx
{
    return osAStrs[indx];
}

// read config to get os/browsers; create rects; store it all
- (void)setupFromConfig
{
    for(int i=0;i<kNumTabs;i++)
        brAStrsOs[i] = [[[NSMutableArray alloc] init] retain];
    for(int i=0;i<kNumTabs;i++)
        osAStrs[i] = [[[NSAttributedString alloc] init] retain];
    
    // create attributed strings for os's (column 0)
    // os images
    NSImage *oimgs[kNumTabs];
    NSSize isz = NSMakeSize(21,21);
    NSString *path = [[NSBundle mainBundle] pathForResource:@"win28" ofType:@"png"];
    oimgs[0] = [[NSImage alloc] initByReferencingFile:path];
    [oimgs[0] setSize:isz];
    oimgs[1] = oimgs[2] = oimgs[0];
    path = [[NSBundle mainBundle] pathForResource:@"lin28" ofType:@"png"];
    oimgs[3] = [[NSImage alloc] initByReferencingFile:path];
    [oimgs[3] setSize:isz];
    path = [[NSBundle mainBundle] pathForResource:@"ios-mobile" ofType:@"png"];
    oimgs[4] = [[NSImage alloc] initByReferencingFile:path];
    [oimgs[4] setSize:isz];
    path = [[NSBundle mainBundle] pathForResource:@"apple28" ofType:@"png"];
    oimgs[5] = [[NSImage alloc] initByReferencingFile:path];
    [oimgs[5] setSize:isz];
    
    NSString *osStr[kNumTabs] = {@"  Windows XP", @"  Windows 7", @"  Windows 8", @"  Linux", @"  Apple IOS", @"  Apple OSX"};
    
    for(int i=0; i < kNumTabs; i++)
    {
        NSTextAttachment* ta = [[NSTextAttachment alloc] init];
        NSTextAttachmentCell* tac = [[NSTextAttachmentCell alloc] init];
        [tac setImage: oimgs[i]];
        [oimgs[i] release];
        [ta setAttachmentCell: tac];
        NSAttributedString* as = [NSAttributedString attributedStringWithAttachment: ta];
        [ta release];
        [tac release];
        // NSBaselineOffsetAttributeName
        NSNumber *nn = [NSNumber numberWithInteger:6];
        NSDictionary *asdict = [NSDictionary dictionaryWithObjectsAndKeys:nn,NSBaselineOffsetAttributeName, nil];
        NSMutableAttributedString* mas = [[[NSMutableAttributedString alloc] initWithAttributedString:as ] retain];
        NSAttributedString *osAStr = [[NSAttributedString alloc] initWithString:osStr[i] attributes:asdict];
        [mas appendAttributedString: osAStr];
        [osAStr release];
        osAStrs[i] = mas;
    }
    
    // browser images for column 1
    NSImage *bimgs[7];
    isz = NSMakeSize(14,14);
    path = [[NSBundle mainBundle] pathForResource:@"ie28" ofType:@"png"];
    bimgs[0] = [[[NSImage alloc] initByReferencingFile:path] autorelease];
    [bimgs[0] setSize:isz];
    path = [[NSBundle mainBundle] pathForResource:@"firefox28" ofType:@"png"];
    bimgs[1] = [[[NSImage alloc] initByReferencingFile:path] autorelease];
    [bimgs[1] setSize:isz];
    path = [[NSBundle mainBundle] pathForResource:@"safari28" ofType:@"png"];
    bimgs[2] = [[[NSImage alloc] initByReferencingFile:path] autorelease];
    [bimgs[2] setSize:isz];
    path = [[NSBundle mainBundle] pathForResource:@"opera28" ofType:@"png"];
    bimgs[3] = [[[NSImage alloc] initByReferencingFile:path] autorelease];
    [bimgs[3] setSize:isz];
    path = [[NSBundle mainBundle] pathForResource:@"chrome28" ofType:@"png"];
    bimgs[4] = [[[NSImage alloc] initByReferencingFile:path] autorelease];
    [bimgs[4] setSize:isz];
    path = [[NSBundle mainBundle] pathForResource:@"an28" ofType:@"png"];
    bimgs[5] = [[[NSImage alloc] initByReferencingFile:path] autorelease];
    [bimgs[5] setSize:isz];
    path = [[NSBundle mainBundle] pathForResource:@"ios-mobile" ofType:@"png"];
    bimgs[6] = [[[NSImage alloc] initByReferencingFile:path] autorelease];
    [bimgs[6] setSize:isz];
    
    for(int i=0; i < kNumTabs; i++)    // setup browsers for each os
    {
        NSInteger num = [configsOS[i] count];
        
        NSString *lastBrowser = @"xx";      // initial column
        NSImage *bimg = bimgs[0];
        
        for(NSInteger j=0;j < num; j++)     // setup browsers
        {
            NSMutableArray *llArr = [configsOS[i] objectAtIndex:j];
            //            NSString *osstr = [llArr objectAtIndex:0];
            NSString *browser = [llArr objectAtIndex:1];
            NSString *version = [llArr objectAtIndex:2];
            NSString *enabled = [llArr objectAtIndex:3];
            NSString *twoch = [browser substringToIndex:2];     // 2 chars to identify browser
            if(![twoch isEqualToString:lastBrowser])      // different browser than previous
            {
                if([twoch isEqualToString:@"ie"])         // internet explorer
                    bimg = bimgs[0];
                if([twoch isEqualToString:@"in"])         // internet explorer
                    bimg = bimgs[0];
                if([twoch isEqualToString:@"fi"])         // firefox
                    bimg = bimgs[1];
                else if([twoch isEqualToString:@"sa"])    // safari
                    bimg = bimgs[2];
                else if([twoch isEqualToString:@"op"])    // opera
                    bimg = bimgs[3];
                else if([twoch isEqualToString:@"go"])    // google chrome
                    bimg = bimgs[4];
                if([twoch isEqualToString:@"ch"])         // firefox named 'chrome' in selenium
                    bimg = bimgs[4];
                else if([twoch isEqualToString:@"an"])    // android
                    bimg = bimgs[5];
                else if([twoch isEqualToString:@"ip"])    // iphone/ipad
                    bimg = bimgs[6];
                lastBrowser = [browser substringToIndex:2];
            }
            
            NSTextAttachment* ta = [[NSTextAttachment alloc] init];
            NSTextAttachmentCell* tac = [[NSTextAttachmentCell alloc] init];
            [tac setImage: bimg];
            [ta setAttachmentCell: tac];
            NSAttributedString* as = [NSAttributedString attributedStringWithAttachment: ta];
            [ta release];
            [tac release];
            NSMutableAttributedString* mas = [[NSMutableAttributedString alloc] initWithAttributedString: as];
            if([browser isEqualToString:@"iphone"])
                browser = @"IPhone";
            else if([browser isEqualToString:@"ipad"])
                browser = @"IPad";
            else if([browser isEqualToString:@"googlechrome"] || [browser isEqualToString:@"chrome"])
                browser = @"Google Chrome";
            else
                browser = [browser capitalizedString];
            NSString *brver = @"";
            brver = [NSString stringWithFormat:@" %@ %@",browser, version];
            NSNumber *nn = [NSNumber numberWithInteger:2];
            NSColor *clr = [enabled hasPrefix:@"Y"] ? [NSColor blackColor] : [NSColor grayColor];
            NSDictionary *asdict = [NSDictionary dictionaryWithObjectsAndKeys:nn,NSBaselineOffsetAttributeName, clr, NSForegroundColorAttributeName, nil];
            NSAttributedString *bAStr = [[NSAttributedString alloc] initWithString:brver attributes:asdict];
            [mas appendAttributedString:bAStr];
            [bAStr release];
            [brAStrsOs[i] addObject:mas];
            [mas release];
        }
    }    
}

@end
