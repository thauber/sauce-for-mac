//
//  SessionController.m
//  scout-desktop
//
//  Created by ackerman dudley on 4/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "SessionController.h"
#import "SaucePreconnect.h"
#import "RFBConnectionManager.h"
#import "ScoutWindowController.h"
#import "AppDelegate.h"
#import "OptionBox.h"
#import "RegexKitLite.h"

@implementation SessionController

@synthesize osTabs;
@synthesize defaultBrowser;
@synthesize panel;
@synthesize view;
@synthesize cancelBtn;
@synthesize connectBtn;
@synthesize connectIndicatorText;
@synthesize connectIndicator;
@synthesize url;
@synthesize boxWindows;
@synthesize boxLinux;

- (id)init
{
    self = [super init];
    if(self)
    {
        [NSBundle loadNibNamed:@"SessionController"  owner:self];
    }
    return self;
}

-(void)runSheet
{
    
    // use last used values from prefs
    NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
    NSString *urlstr = [defs stringForKey:kSessionURL];
    if(urlstr)
        [self.url setStringValue:urlstr];
    else
        [connectBtn setEnabled:NO];
    [[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(textDidChange:) name: NSTextDidChangeNotification object: nil];
    curTabIndx = [defs integerForKey:kCurTab];
    sessionIndxs[tt_windows] = [defs integerForKey:kSessionIndxWin];
    sessionIndxs[tt_linux] = [defs integerForKey:kSessionIndxLnx];
    sessionIndxs[tt_apple] = [defs integerForKey:kSessionIndxMac];
    sessionIndxs[tt_mobile] = [defs integerForKey:kSessionIndxMbl];
    
    if(!sessionIndxs[curTabIndx])
        sessionIndxs[curTabIndx] = 3;           // default is windows 9
    
    // create hoverbox
    NSRect frame = NSMakeRect(0,0,0,0);
    hoverBox = [[NSView alloc ] initWithFrame:frame];
    [osTabs selectTabViewItemAtIndex:curTabIndx];
    [curBox addSubview:hoverBox];
    CALayer *viewLayer = [CALayer layer];
    [viewLayer setBackgroundColor:CGColorCreateGenericRGB(0.0, 0.0, 0.0, 0.1)]; //RGB plus Alpha Channel
    [hoverBox setWantsLayer:YES]; // view's backing store is using a Core Animation Layer
    [hoverBox setLayer:viewLayer];
    
    for(enum TabType i=0;i<2;i++)      // setup tracking rects for multiple tabs
        [self addTrackingAreas:i];

    [boxLinux setSessionCtlr:self];       // pass mouseclick to 'selectBrowser' method 
    [boxWindows setSessionCtlr:self];     // pass mouseclick to 'selectBrowser' method 
    
    [connectBtn setTitle:@"Scout!"];
    [connectBtn setAction: @selector(connect:)];
    [connectBtn setKeyEquivalent:@"\r"];
    [connectBtn setKeyEquivalentModifierMask:0]; 
    [connectBtn setState:NSOnState];
    [connectIndicator stopAnimation:self];
    [connectIndicatorText setStringValue:@""];
    
    if([[ScoutWindowController sharedScout] tabCount])      // allow cancel if at least 1 tab running
    {
        [cancelBtn setHidden:NO];
        [cancelBtn setAction:@selector(performClose:)];
    }
    else
    {
        [cancelBtn setHidden:YES];
    }
    
    [NSApp beginSheet:panel modalForWindow:[[ScoutWindowController sharedScout] window] modalDelegate:self  didEndSelector:nil   contextInfo:nil];
    hoverIndx = sessionIndxs[curTabIndx];
    [self handleMouseEntered:nil];
    [self selectBrowser:nil];       // get last selection or default selected

}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    [hoverBox removeFromSuperview];
    [selectBox removeFromSuperview];
    curTabIndx = [tabView indexOfTabViewItem:tabViewItem];
    id *trarr;
    switch((enum TabType)curTabIndx)
    {
        case tt_windows: curBox = boxWindows; trarr = trarrWin ; break;
        case tt_linux:   curBox = boxLinux;  trarr = trarrLnx;  break;
        case tt_apple:   break;
        case tt_mobile:  break;
    }
    [curBox addSubview:hoverBox];
    [curBox addSubview:selectBox];
    NSTrackingArea *ta = trarr[sessionIndxs[curTabIndx]];
    NSRect rr = [ta rect];
    [selectBox setFrame:rr];
    [hoverBox setFrame:rr];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:curTabIndx forKey:kCurTab];
    // save selected item in all tabs
    [defaults setInteger:sessionIndxs[tt_windows] forKey:kSessionIndxWin];
    [defaults setInteger:sessionIndxs[tt_linux] forKey:kSessionIndxLnx];
    [defaults setInteger:sessionIndxs[tt_apple] forKey:kSessionIndxMac];
    [defaults setInteger:sessionIndxs[tt_mobile] forKey:kSessionIndxMbl];
}

- (NSInteger)hoverIndx
{
    return hoverIndx;
}

// read config to get os/browsers; create rects; store it all
- (void)addTrackingAreas:(enum TabType)tabIndex
{
    NSInteger xcols[5] = {145, 244, 339, 420, 500};
    NSInteger xrows[4] = {127,  105,  83,  60};
    NSImage *ximages[5];
    NSString *path = [[NSBundle mainBundle] pathForResource:@"ie_color" ofType:@"pdf"];
    ximages[0] = [[NSImage alloc] initByReferencingFile:path];
    path = [[NSBundle mainBundle] pathForResource:@"firefox_color" ofType:@"icns"];
    ximages[1] = [[NSImage alloc] initByReferencingFile:path];
    path = [[NSBundle mainBundle] pathForResource:@"safari_color" ofType:@"icns"];
    ximages[2] = [[NSImage alloc] initByReferencingFile:path];
    path = [[NSBundle mainBundle] pathForResource:@"opera_color" ofType:@"pdf"];
    ximages[3] = [[NSImage alloc] initByReferencingFile:path];
    path = [[NSBundle mainBundle] pathForResource:@"chrome_color" ofType:@"pdf"];
    ximages[4] = [[NSImage alloc] initByReferencingFile:path];
    
    [self readConfig];      // fill config arrays with data from config file
    
    id *trarr;
    OptionBox *obox;
    NSMutableArray *configArr;
    switch(tabIndex)
    {
        case tt_windows: obox = boxWindows; configArr = configWindows; trarr = trarrWin; break;
        case tt_linux:   obox = boxLinux;  configArr = configLinux; trarr = trarrLnx; break;
        case tt_apple:  break;
        case tt_mobile: break;
    }
    
    NSInteger num = [configArr count];
    NSRect rr;
    NSInteger row=0, col=0;
    NSString *lastBrowser = @"ie";      // initial column
    
    for(NSInteger i=0;i < num; i++) // track mouse in/out over all buttons and included area
    {
        // check for moving to next column/browser
        NSArray *llArr = [configArr objectAtIndex:i];
        NSString *browser = [[llArr objectAtIndex:1] substringToIndex:2];       // 2 chars to identify browser
        if(![browser isEqualToString:lastBrowser])      // new column
        {            
            if([browser isEqualToString:@"fi"])         // firefox
                col=1;
            else if([browser isEqualToString:@"sa"])    // safari
                col=2;
            else if([browser isEqualToString:@"op"])    // opera
                col=3;
            else if([browser isEqualToString:@"go"])    // google chrome
                col=4;
            
            row=0;
            lastBrowser = [browser substringToIndex:2];
        }
        
        // create image views
        rr = NSMakeRect(xcols[col], xrows[row], 30,20);
        NSImageView *vv = [[NSImageView alloc] initWithFrame:rr];
        [vv setImage:ximages[col]];     // set icon
        BOOL enabled = [[llArr objectAtIndex:3] isEqualToString:@"YES"];
        if(!enabled)
            [vv setEnabled:NO];
        [obox addSubview:vv];
        
        // create text view
        NSRect txtrr = NSMakeRect(rr.origin.x + 30, rr.origin.y + 3, 26, 17); 
        NSTextField *tv = [[NSTextField alloc] initWithFrame:txtrr];
        [tv setBordered:NO];
        [tv setFont:[NSFont fontWithName:@"Arial" size:13]];
        NSString *txt = [llArr objectAtIndex:2];      // version
        [tv setStringValue:txt];
        [tv setBackgroundColor:[NSColor clearColor]];
        [tv setRefusesFirstResponder:YES];
        if(!enabled)
            [tv setEnabled:NO];
        [obox addSubview:tv];
        
        // add tracking area
        if(enabled)
        {
            rr.origin.x -= 4;
            rr.size.width = 80;     // trackingrect width - NB: careful, 84 is too big
            trarr[i] = [obox settracker:rr];
        }
        
        row++;
    }
    hoverFrame.size.width = 0;      // mouse is not within a rect(?guaranteed on startup?)
}

// called from optionBox mouseEntered
- (void)handleMouseEntered:(id)tn
{
    id *trarr;
    NSInteger num;
    switch(curTabIndx)
    {
        case tt_windows: trarr = trarrWin; num = kNumWindowsTrackers; break;
        case tt_linux: trarr = trarrLnx; num = kNumLinuxTrackers;  break;
        case tt_apple:  break;
        case tt_mobile: break;
    }

    if(!tn)     // initial setting
        tn = trarr[hoverIndx];
    
    for(NSInteger i=0; i < num; i++)
    {
        if(tn == trarr[i])
        {
            hoverFrame = [(NSTrackingArea *)tn rect];
            [hoverBox setFrame:hoverFrame];
            hoverIndx = i;
            return;
        }
    }
    // didn't enter a trackingrect
    hoverFrame.size.width = 0;
    [hoverBox setFrame:hoverFrame];
    hoverIndx = -1;
}

// called from optionBox mouseExited
- (void)handleMouseExited
{
    [[NSCursor arrowCursor] set];
    hoverFrame.size.width = 0;
    [hoverBox setFrame:hoverFrame];
    hoverIndx = -1;
}

-(void)terminateApp
{
    [NSApp endSheet:panel];
    [panel orderOut:nil];
    [[NSApp delegate] setOptionsCtrlr:nil];
}

- (IBAction)performClose:(id)sender
{
    [[SaucePreconnect sharedPreconnect] setErrStr:nil];
    [[NSApp delegate] cancelOptionsConnect:self];
}

-(void)quitSheet
{
    [NSApp endSheet:panel];
    [panel orderOut:nil];    
}

- (void)textDidChange:(NSNotification *)aNotification
{
    BOOL bchars = [[url stringValue] length] ? YES : NO;
    [connectBtn setEnabled:bchars];
}


- (IBAction)selectBrowser:(id)sender 
{
    NSRect frame;
    
    frame = hoverFrame;

    if(hoverIndx== -1)
        return;
    
    if(!selectBox)
    {
        // create box
        selectBox = [[NSView alloc] initWithFrame:frame];
        [curBox addSubview:selectBox];
        CALayer *viewLayer = [CALayer layer];
        [viewLayer setBackgroundColor:CGColorCreateGenericRGB(0.0, 0.0, 0.0, 0.3)]; //RGB plus Alpha Channel
        [selectBox setWantsLayer:YES]; // view's backing store is using a Core Animation Layer
        [selectBox setLayer:viewLayer];
    }
    else 
    {
        // move selected box over this sender
        sessionIndxs[curTabIndx] = hoverIndx;
        [selectBox setFrame:frame];
    }
    
}

- (void)doubleClick        // from optionBox
{
    if(hoverIndx== -1)
        return;

    NSString *urlstr = [self.url stringValue];
    if(urlstr)
        [self connect:self];
}

-(IBAction)connect:(id)sender 
{
    NSString *os = [self selected:@"os"];
    NSString *browser = [self selected:@"browser"];
    NSString *version = [self selected:@"version"];
    NSString *urlstr = [self.url stringValue];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:urlstr  forKey:kSessionURL];
    [defaults setInteger:curTabIndx forKey:kCurTab];
    // save selected item in all tabs
    [defaults setInteger:sessionIndxs[tt_windows] forKey:kSessionIndxWin];
    [defaults setInteger:sessionIndxs[tt_linux] forKey:kSessionIndxLnx];
    [defaults setInteger:sessionIndxs[tt_apple] forKey:kSessionIndxMac];
    [defaults setInteger:sessionIndxs[tt_mobile] forKey:kSessionIndxMbl];

    [[SaucePreconnect sharedPreconnect] setOptions:os browser:browser browserVersion:version url:urlstr];
    [NSApp endSheet:panel];

    NSURL *uurl = [NSURL URLWithString:urlstr];
    BOOL noTunnel = [[NSApp delegate] noTunnel];
    if(uurl && !noTunnel)        // check for localhost
    {
        NSString *uhost = [uurl host];
        BOOL isLocalURL = ![uhost length] || [uhost isEqualToString:@"localhost"] || [uhost isEqualToString:@"127.0.0.1"];
        isLocalURL = isLocalURL || [uhost hasPrefix:@"192.168."] || [uhost hasPrefix:@"10."];
        if(![[NSApp delegate] tunnelCtrlr] && isLocalURL)       // prompt for opening tunnel
        {
            if(![uhost length] || [self canReachIP:uhost])
            {
                NSBeginAlertSheet(@"Requires Intranet Access", @"Yes", @"No", nil, [NSApp keyWindow], self,nil, @selector(tunnelDidDismiss:returnCode:contextInfo:), NULL, @"Do you want to start Scout Connect?"); 
            }
            else {
                NSBeginAlertSheet(@"Can't Reach IP", @"Okay", nil, nil, [NSApp keyWindow], self,nil, nil, NULL, @"Check connection and IP address"); 
            }
        }
        else 
            [self startConnecting];
    }
    else 
        [self startConnecting];
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
            [self startConnecting];
            return;
        case NSAlertOtherReturn:
            [self runSheet];
            return;
    }
}

-(BOOL)canReachIP:(NSString*)host
{
    NSTask *ftask = [[NSTask alloc] init];
    NSPipe *fpipe = [NSPipe pipe];
    [ftask setStandardOutput:fpipe];
    [ftask setStandardError:fpipe];
    [ftask setLaunchPath:@"/bin/bash"];
    NSString *arg = [NSString stringWithFormat:@"ping %@",host];
    [ftask setArguments:[NSArray arrayWithObjects:@"-c", arg, nil]];
    NSFileHandle *fhand = [fpipe fileHandleForReading];        
    [ftask launch];
    while(10)       // just a guess to give enough attempts to get yes/no result
    {
        NSData *data = [fhand availableData];		 
        NSString *retStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if([retStr length])
        {
            unichar ch = [retStr characterAtIndex:0];
            if(ch >= '1' && ch <= '9')
                return YES;
            if(ch == 'R')      // Request timeout
                return NO;
            else
            {
                NSRange r = [retStr rangeOfString:@"down"];
                if(r.location != NSNotFound)
                    return NO;
            }
        }
    }
    return NO;
}
   
- (void)startConnecting
{
    [connectBtn setState:NSOffState];
    [url setEnabled:NO];
    [connectIndicator startAnimation:self];
    [connectIndicatorText setStringValue:@"Connecting..."];
    
    [connectIndicatorText display];
    [cancelBtn setAction:@selector(performClose:)];
    [cancelBtn setHidden:NO];
    [connectBtn setEnabled:NO];
    [NSThread detachNewThreadSelector:@selector(preAuthorize:) toTarget:[SaucePreconnect sharedPreconnect] withObject:nil];
}
                                  
-(void)connectionSucceeded
{
    [panel orderOut:nil];
}

- (void)showError:(NSString *)errStr
{
    NSBeginAlertSheet(@"Session Options Error", @"Okay", nil, nil, [NSApp keyWindow], self,nil,     
                      NULL, NULL, errStr);    
}

- (NSString *)selected:(NSString*)type      // 'browser', 'version' or 'os'
{
    NSString *os=@"";
    NSString *browser=@"";
    NSString *version=@"";
    
    int indx = sessionIndxs[curTabIndx];
    
    if(curTabIndx==tt_apple)
    {
        os = @"OSX";
        switch(indx)
        {
            case 0: browser = @"firefox"; version = @"3.6"; break;
            case 1: browser = @"firefox"; version = @"8"; break;
            case 2: browser = @"firefox"; version = @"9"; break;
            case 3: browser = @"firefox"; version = @"10"; break;
            case 4: browser = @"safari"; version = @"3"; break;
            case 5: browser = @"safari"; version = @"4"; break;
            case 6: browser = @"safari"; version = @"5"; break;
            case 7: browser = @"opera"; version = @"9"; break;
            case 8: browser = @"opera"; version = @"10"; break;                        
            case 9: browser = @"opera"; version = @"11"; break;                        
            case 10: browser = @"googlechrome"; version = @""; break;
        }
    }
    else if(curTabIndx==tt_windows)
    {
        os = @"Windows 2003";
        switch(indx)
        {
            case 0: browser = @"iexplore"; version = @"6"; break;
            case 1: browser = @"iexplore"; version = @"7"; break;
            case 2: browser = @"iexplore"; version = @"8"; break;
            case 3: os = @"Windows 2008"; browser = @"iexplore"; version = @"9"; break;
            case 4: browser = @"firefox"; version = @"3.6"; break;
            case 5: browser = @"firefox"; version = @"8"; break;
            case 6: browser = @"firefox"; version = @"9"; break;
            case 7: os = @"Windows 2008"; browser = @"firefox"; version = @"10"; break;
            case 8: browser = @"safari"; version = @"3"; break;
            case 9: browser = @"safari"; version = @"4"; break;
            case 10: os = @"Windows 2008"; browser = @"safariproxy"; version = @"5"; break;
            case 11: browser = @"opera"; version = @"9"; break;
            case 12: browser = @"opera"; version = @"10"; break;                        
            case 13: browser = @"opera"; version = @"11"; break;                        
            case 14: os = @"Windows 2008"; browser = @"googlechrome"; version = @""; break;
        }
    }
    else if(curTabIndx==tt_linux)
    {
        os = @"Linux";
        switch(indx)
        {
            case 0: browser = @"firefox"; version = @"3.6"; break;
            case 1: browser = @"firefox"; version = @"9"; break;
            case 2: browser = @"firefox"; version = @"10"; break;
            case 3: browser = @"opera"; version = @"11"; break;                        
            case 4: browser = @"googlechrome"; version = @""; break;
        }
    }
    
    if([type isEqualToString:@"os"])
        return os;
    if([type isEqualToString:@"browser"])        
        return browser;
    if([type isEqualToString:@"version"]) 
        return version;
    return @"";    
}

// read data in config file into a dictionary
// NB:  assumes so curly braces wrapping the lines; 
//      assumes sorted by os, and all same browsers grouped together
- (void)readConfig
{
    configOSX     = [[[NSMutableArray alloc] init] retain];     // os/browsers for osx
    configWindows = [[[NSMutableArray alloc] init] retain];     // os/browsers for windows
    configLinux   = [[[NSMutableArray alloc] init] retain];     // os/browsers for linux

    NSString *path = [[NSBundle mainBundle] pathForResource:@"scout" ofType:@"conf"];
    NSData *fdata = [[NSFileManager defaultManager] contentsAtPath:path];
    NSString *jsonStr = [[NSString alloc] initWithData:fdata encoding:NSUTF8StringEncoding];
    // pull out the lines into an array
    NSArray *linesArr = [jsonStr arrayOfCaptureComponentsMatchedByRegex:@"\\{(.*?)\\}"];
    
    NSString *osStr, *ll;
    NSString *browser;
    NSString *version;
    NSString *active;
    for(NSArray *arr in linesArr)
    {
        ll = [arr objectAtIndex:0];
        osStr   = [[SaucePreconnect sharedPreconnect] jsonVal:ll key:@"os"];
        browser = [[SaucePreconnect sharedPreconnect] jsonVal:ll key:@"browser"];
        version = [[SaucePreconnect sharedPreconnect] jsonVal:ll key:@"version"];
        if(![version length])
            version=@"*";
        active  = [[SaucePreconnect sharedPreconnect] jsonVal:ll key:@"active"];
        NSMutableArray *obarr = [NSMutableArray arrayWithCapacity:4];
        [obarr  addObject:osStr];
        [obarr  addObject:browser];
        [obarr  addObject:version];
        [obarr  addObject:active];
        if([osStr hasPrefix:@"Windows"])
            [configWindows addObject:obarr];
        else if([osStr hasPrefix:@"Linux"])
            [configLinux addObject:obarr];            
        else if([osStr hasPrefix:@"OSX"])
            [configOSX addObject:obarr];
    }
    
}

@end
