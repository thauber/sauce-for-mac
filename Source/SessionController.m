//
//  SessionController.m
//  scout-desktop
//
//  Created by ackerman dudley on 4/2/12.
//  Copyright (c) 2012 __SauceLabs__. All rights reserved.
//

#import "SessionController.h"
#import "SaucePreconnect.h"
#import "RFBConnectionManager.h"
#import "ScoutWindowController.h"
#import "AppDelegate.h"
#import "RegexKitLite.h"
#import "demoConnectController.h"

@implementation SessionController

@synthesize defaultBrowser;
@synthesize panel;
@synthesize view;
@synthesize connectBtn;
@synthesize connectIndicatorText;
@synthesize connectIndicator;
@synthesize url;

- (id)init
{
    self = [super init];
    if(self)
    {
        BOOL bDemo = [[NSApp delegate] isDemoAccount];
        if(bDemo)
            [NSBundle loadNibNamed:@"SessionController_demo"  owner:self];
        else
            [NSBundle loadNibNamed:@"SessionController"  owner:self];
    }
    return self;
}

-(void)runSheet
{
    // use last used values from prefs
    NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
    curTabIndx = [defs integerForKey:kCurTab];
    sessionIndxs[tt_winxp] = MAX(0,[defs integerForKey:kSessionIndxWinxp]); // avoid '-1'
    sessionIndxs[tt_win7] = MAX(0,[defs integerForKey:kSessionIndxWin7]);
    sessionIndxs[tt_win8] = MAX(0,[defs integerForKey:kSessionIndxWin8]);
    sessionIndxs[tt_linux] = MAX(0,[defs integerForKey:kSessionIndxLnx]);
    sessionIndxs[tt_macios] = MAX(0,[defs integerForKey:kSessionIndxIOS]);
    sessionIndxs[tt_macosx] = MAX(0,[defs integerForKey:kSessionIndxOSX]);
    resolutionIndxs[tt_winxp] = [defs integerForKey:kResolutionIndxWin];
    resolutionIndxs[tt_win7] = [defs integerForKey:kResolutionIndxWin];
    resolutionIndxs[tt_win8] = [defs integerForKey:kResolutionIndxWin];
    resolutionIndxs[tt_linux] =   [defs integerForKey:kResolutionIndxLnx];
    resolutionIndxs[tt_macios] =   [defs integerForKey:kResolutionIndxMac];
    resolutionIndxs[tt_macosx] =   [defs integerForKey:kResolutionIndxMac];
    
    NSString *urlstr = [defs stringForKey:kSessionURL];
    if(urlstr)
        [self.url setStringValue:urlstr];
    else        // never connected
    {
        sessionIndxs[curTabIndx] = 0;       
        
        resolutionIndxs[tt_winxp] = 1;          // assume 1024x768 is 2nd item in windows resolution array
        resolutionIndxs[tt_win7] = 1;          // assume 1024x768 is 2nd item in windows resolution array
        resolutionIndxs[tt_win8] = 1;          // assume 1024x768 is 2nd item in windows resolution array
    }
    
    [self setupFromConfig];

    for(int i=0;i<kNumTabs;i++)
    {
        int nactive = [[NSApp delegate] numActiveBrowsers:i];
        if(nactive <= sessionIndxs[i])
            sessionIndxs[i] = 0;
        int nres = [[[configsOS[i]  objectAtIndex:sessionIndxs[i]] objectAtIndex:4] count];
        if( nres <= resolutionIndxs[i])
            resolutionIndxs[i] = nres-1;     // highest res available
    }
    [browserTbl setDoubleAction:@selector(doDoubleClick:)];
    [connectBtn setTitle:@"Navigate"];
    [connectBtn setAction: @selector(connect:)];
    [connectBtn setKeyEquivalent:@"\r"];
    [connectBtn setKeyEquivalentModifierMask:0]; 
    [connectBtn setState:NSOnState];
    [connectIndicator stopAnimation:self];
    [connectIndicatorText setStringValue:@""];
        
    [NSApp beginSheet:panel modalForWindow:[[ScoutWindowController sharedScout] window] modalDelegate:self  didEndSelector:nil   contextInfo:nil];

    // size column 0 row heights
    NSMatrix *mm = [browserTbl matrixInColumn:0];
    NSSize sz = [mm cellSize];
    sz.height = 21;
    [mm setCellSize:sz];
    sz.width=0; sz.height = 8;
    [mm setIntercellSpacing:sz];
    [mm sizeToCells];
        
    [browserTbl selectRow:curTabIndx inColumn:0];
    [self doBrowserClick:nil];      // set browser cells height
    [browserTbl selectRow:sessionIndxs[curTabIndx] inColumn:1];
    [browserTbl selectRow:resolutionIndxs[curTabIndx] inColumn:2];
    // NB: only remembering 1 resolution for each os
    lastpop1 = NO;
    lastpop2 = NO;

}

// read config to get os/browsers; create rects; store it all
- (void)setupFromConfig
{
    for(int i=0;i<kNumTabs;i++)
        configsOS[i] = [[NSApp delegate] getConfigsOS:i];           // os/browsers for windows
    for(int i=0;i<kNumTabs;i++)
        brAStrsOs[i] = [[NSMutableArray alloc] init];
    
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
            NSDictionary *asdict = [NSDictionary dictionaryWithObjectsAndKeys:nn,NSBaselineOffsetAttributeName, nil];
            NSAttributedString *bAStr = [[NSAttributedString alloc] initWithString:brver attributes:asdict]; 
            [mas appendAttributedString:bAStr];
            [bAStr release];
            [brAStrsOs[i] addObject:mas];
            [mas release];
        }
    }    
}

-(void)terminateApp
{
    [self cancel:self];
}

-(void)quitSheet
{
    [NSApp endSheet:panel];
    [panel orderOut:nil];    
}

- (IBAction)cancel:(id)sender 
{
    [NSApp endSheet:panel];
    [panel orderOut:nil];
    [[NSApp delegate] setOptionsCtrlr:nil];
}

- (void)textDidChange:(NSNotification *)aNotification
{
    BOOL bchars = [[url stringValue] length] ? YES : NO;
    [connectBtn setEnabled:bchars];
}

-(IBAction)connect:(id)sender 
{
    NSString *urlstr = [self.url stringValue];
    
    if(![urlstr length])
         urlstr = @"http://www.saucelabs.com/welcome";

    if(![[NSApp delegate] checkaccount])
        return;
    
    NSInteger rr = [browserTbl selectedRowInColumn:1];
    NSArray *brarr;

    NSString *sel_os;
    NSString *sel_browser;
    NSString *sel_version;
    NSString *sel_resolution;
    
    sel_resolution = [[browserTbl selectedCellInColumn:2] stringValue];
    if(!sel_resolution)     // TODO: figure out which one is 1024x768
        sel_resolution = @"1024x768";
    
    brarr = [configsOS[curTabIndx] objectAtIndex:rr];
    sel_os      = [brarr objectAtIndex:0];
    sel_browser = [brarr objectAtIndex:1];
    sel_version = [brarr objectAtIndex:2];
    if([sel_version isEqualToString:@"*"])
        sel_version = @"";

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:urlstr  forKey:kSessionURL];
    [defaults setInteger:curTabIndx forKey:kCurTab];
    // save selected browser for all os's
    [defaults setInteger:sessionIndxs[tt_winxp] forKey:kSessionIndxWinxp];
    [defaults setInteger:sessionIndxs[tt_win7] forKey:kSessionIndxWin7];
    [defaults setInteger:sessionIndxs[tt_win8] forKey:kSessionIndxWin8];
    [defaults setInteger:sessionIndxs[tt_linux] forKey:kSessionIndxLnx];
    [defaults setInteger:sessionIndxs[tt_macios] forKey:kSessionIndxIOS];
    [defaults setInteger:sessionIndxs[tt_macosx] forKey:kSessionIndxOSX];

    [defaults setInteger:resolutionIndxs[tt_winxp] forKey:kResolutionIndxWin];
    [defaults setInteger:resolutionIndxs[tt_win7] forKey:kResolutionIndxWin];
    [defaults setInteger:resolutionIndxs[tt_win8] forKey:kResolutionIndxWin];
    [defaults setInteger:resolutionIndxs[tt_linux] forKey:kResolutionIndxLnx];
    [defaults setInteger:resolutionIndxs[tt_macios] forKey:kResolutionIndxMac];
    [defaults setInteger:resolutionIndxs[tt_macosx] forKey:kResolutionIndxMac];

    NSMutableDictionary *sdict = [[SaucePreconnect sharedPreconnect] setOptions:sel_os browser:sel_browser browserVersion:sel_version url:urlstr resolution:sel_resolution];
    [NSApp endSheet:panel];
    [panel orderOut:nil];
    
    if([urlstr hasPrefix:@"file"])
    {
        NSBeginAlertSheet(@"Static File Request", @"Ok", nil, nil, [[ScoutWindowController sharedScout] window], self, nil, @selector(endAndTryAgain:returnCode:contextInfo:), nil, @"Sauce does not yet support manually testing files on disk. However, you can test files by putting them in your 'sites' directory and then turn on sharing in finder > system preferences > sharing");
        return;
    }

    if(![urlstr hasPrefix:@"http://"])
        urlstr = [NSString stringWithFormat:@"http://%@",urlstr];
    NSURL *uurl = [NSURL URLWithString:urlstr];
    BOOL noTunnel = [[NSApp delegate] noTunnel];
    if(uurl && noTunnel)        // check for localhost
    {
        NSString *uhost = [uurl host];
        BOOL isLocalURL;
        if(!uhost)
            uhost = urlstr;
        isLocalURL = [uhost hasPrefix:@"localhost"] || [uhost hasPrefix:@"127.0.0.1"]
                        || [uhost hasPrefix:@"192.168."] || [uhost hasPrefix:@"10."];
        if([uhost hasPrefix:@"172."])
        {
            NSArray *iparr = [uhost componentsSeparatedByString:@"."];
            NSInteger sub = [[iparr objectAtIndex:1] integerValue];
            isLocalURL = sub>= 16 && sub<=31;
        }
        if(isLocalURL)       // prompt for opening tunnel
        {
            if([[NSApp delegate] isDemoAccount])
            {
                [[demoConnectController alloc] init:self];
            }
            else
                NSBeginAlertSheet(@"Are you testing an intranet site?", @"Yes", @"No", nil, [NSApp keyWindow], self,nil, @selector(tunnelDidDismiss:returnCode:contextInfo:), sdict, @"Do you wish to use Sauce Connect, our secure tunnel for accessing your local servers?"); 
        }
        else 
            [[NSApp delegate] startConnecting:sdict];
    }
    else 
        [[NSApp delegate] startConnecting:sdict];
}

-(void)endAndTryAgain:(NSWindow*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
    [self runSheet];
}

- (void)tunnelDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    switch (returnCode)
    {
        case NSAlertDefaultReturn:
            [[NSApp delegate] doTunnel:self];
            return;
        case NSAlertAlternateReturn:
            [[NSApp delegate] setNoTunnel:YES];
            [[NSApp delegate] startConnecting:contextInfo];
            return;
        case NSAlertOtherReturn:
            [self runSheet];
            return;
    }
}
   
- (void)showError:(NSString *)errStr
{
    NSBeginAlertSheet(@"Session Options Error", @"Okay", nil, nil, [NSApp keyWindow], self,nil, NULL, NULL, @"%@",errStr);    
}

- (IBAction)visitSauce:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://saucelabs.com"]];
    [self cancel:nil];
}

// browser delegate methods
- (void)browser:(NSBrowser *)sender willDisplayCell:(id)cell atRow:(NSInteger)row column:(NSInteger)column
{
    if(column==0)
    {
        [cell setAttributedStringValue:osAStrs[row]];
    }
    else
    if(column==1)
    {
        NSAttributedString *brAStr;
        NSArray *obarr;
        brAStr = [brAStrsOs[curTabIndx] objectAtIndex:row];
        obarr = [configsOS[curTabIndx] objectAtIndex:row];
        if(brAStr)
        {
            NSString *active = [obarr objectAtIndex:3];
            BOOL enbld = [active isEqualToString:@"YES"];
            [cell setEnabled:enbld];
            [cell setLeaf:NO];
            [cell setAttributedStringValue:brAStr];
        }
    }
    else
    {
        NSInteger rr = [browserTbl selectedRowInColumn:1];
        NSArray *obarr = [configsOS[curTabIndx] objectAtIndex:rr];
        [cell setLeaf:YES];
        // TODO: for each row take the corresponding resolution
        NSArray *resarr = [obarr objectAtIndex:4];
        NSString *thisRes = [resarr objectAtIndex:row];
        [cell setStringValue:thisRes];
    }
}

- (NSInteger)browser:(NSBrowser *)sender numberOfRowsInColumn:(NSInteger)column
{
    if(column==0)   // size column 0 row heights
    {
        lastpop1 = NO;
        lastpop2 = NO;
        return kNumTabs;
    }
    else
    if(column==1)
    {
        curTabIndx = [sender selectedRowInColumn:0];    // os selected in column 0
        curNumBrowsers = [brAStrsOs[curTabIndx] count];
        lastpop1 = YES;
        lastpop2 = NO;
        return curNumBrowsers;       // num browsers for selected os
    }
    else    // 3rd column is resolutions
    {
        NSInteger rr = [browserTbl selectedRowInColumn:1];
        NSArray *obarr = [configsOS[curTabIndx] objectAtIndex:rr];
        lastpop1 = NO;
        lastpop2 = YES;
        return [[obarr objectAtIndex:4] count];
    }
}

- (IBAction)doBrowserClick:(NSBrowser *)sender
{
    // size column 1 row heights
    NSMatrix *mm = [browserTbl matrixInColumn:1];
    NSSize sz = [mm cellSize];
    sz.height = 18;
    [mm setCellSize:sz];
    sz.width=0; sz.height = 4;
    [mm setIntercellSpacing:sz];
    [mm sizeToCells];
    
    if(sender)      // a real click, not during initialization
    {
        if(lastpop1)        // repopulated -> changed os selection
        {
            [sender selectRow:sessionIndxs[curTabIndx] inColumn:1];
            [sender selectRow:resolutionIndxs[curTabIndx] inColumn:2];
        }
        else
            sessionIndxs[curTabIndx] = [sender selectedRowInColumn:1];
        lastpop1 = NO;
        if(lastpop2)
            [sender selectRow:resolutionIndxs[curTabIndx] inColumn:2];
        else
            resolutionIndxs[curTabIndx] = [sender selectedRowInColumn:2];
        lastpop2 = NO;
    }
}

- (IBAction)doDoubleClick:(id)sender
{
   if([browserTbl selectedRowInColumn:1] != -1)
    [self connect:self];
}

@end
