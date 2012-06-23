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
    selectedFrames = [[[NSMutableArray alloc] initWithCapacity:kNumTabs] retain];    
    
    // use last used values from prefs
    NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
    NSString *urlstr = [defs stringForKey:kSessionURL];
    if(urlstr)
        [self.url setStringValue:urlstr];
    else
        [connectBtn setEnabled:NO];
    [[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(textDidChange:) name: NSTextDidChangeNotification object: nil];
    curTabIndx = [defs integerForKey:kCurTab];
    sessionIndx = [defs integerForKey:kSessionIndx];
    if(!sessionIndx)
        sessionIndx = 3;           // default is windows 9
    
    // create hoverbox
    NSRect frame = NSMakeRect(0,0,0,0);
    hoverBox = [[NSView alloc ] initWithFrame:frame];
    NSTabViewItem *ti = [osTabs  tabViewItemAtIndex:curTabIndx];
    [self tabView:osTabs didSelectTabViewItem:ti];
    [curBox addSubview:hoverBox];
    CALayer *viewLayer = [CALayer layer];
    [viewLayer setBackgroundColor:CGColorCreateGenericRGB(0.0, 0.0, 0.0, 0.1)]; //RGB plus Alpha Channel
    [hoverBox setWantsLayer:YES]; // view's backing store is using a Core Animation Layer
    [hoverBox setLayer:viewLayer];
    
    for(NSInteger i=0;i<1;i++)      // TODO: fix to do multiple tabs
        [self addTrackingAreas:(enum TabType)i];

    [boxLinux setSessionCtlr:self];     // pass mouseclick to 'selectBrowser' method 
    [boxWindows setSessionCtlr:self];     // pass mouseclick to 'selectBrowser' method 
    
    NSTextField *tf = [[ScoutWindowController sharedScout] userStat];
    NSString *uname = [[SaucePreconnect sharedPreconnect] user];
    [tf setStringValue:uname];

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
    hoverIndx = sessionIndx;
    [self handleMouseEntered:nil];
    [self selectBrowser:nil];       // get last selection or default selected

}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    curTabIndx = [tabView indexOfTabViewItem:tabViewItem];
    switch((enum TabType)curTabIndx)
    {
        case tt_windows: curBox = boxWindows; break;
        case tt_linux:   curBox = boxLinux;    break;
        case tt_apple:   break;
        case tt_mobile:  break;
    }
}

- (NSInteger)hoverIndx
{
    return hoverIndx;
}

- (void)addTrackingAreas:(enum TabType)tabIndex
{
    NSRect rr;
    id xarr[kNumTrackItems] = {b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13,b14,b15,b16};

    OptionBox *obox;
    switch(tabIndex)
    {
        case tt_windows: obox = boxWindows; break;
        case tt_linux:   obox = boxLinux;    break;
        case tt_apple:  break;
        case tt_mobile: break;
    }
    
    for(NSInteger i=0;i < kNumTrackItems; i++) // track mouse in/out over all buttons and included area
    {
        barr[i] = xarr[i];      // copy nsimageview objects to ivar array
        rr = [xarr[i] frame];
        rr.origin.x -= 4;
        rr.size.width = 80;     // trackingrect width - NB: careful, 84 is too big
        trarr[i] = [obox settracker:rr];
    }
    hoverFrame.size.width = 0;      // mouse is not within a rect(?guaranteed on startup?)
}

// called from optionBox mouseEntered
- (void)handleMouseEntered:(id)tn
{
    if(!tn)     // initial setting
        tn = trarr[hoverIndx];
    
    for(NSInteger i=0; i < kNumTrackItems; i++)
    {
        if(tn == trarr[i])
        {
            hoverFrame = [(NSTrackingArea *)tn rect];
            NSPoint pt = [curBox convertPoint:hoverFrame.origin toView:[curBox superview]];
                
            hoverFrame.origin = pt;
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
        sessionIndx = hoverIndx;
        [selectBox setFrame:frame];
        NSValue *vv = [NSValue valueWithRect:frame];
        [selectedFrames insertObject:vv atIndex:curTabIndx];
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
    [defaults setInteger:sessionIndx  forKey:kSessionIndx];
    [defaults setInteger:curTabIndx forKey:kCurTab];
    // TODO: save selected item in all tabs
    NSRect fr = [[selectedFrames objectAtIndex:curTabIndx] rectValue];
    NSString *frStr = NSStringFromRect(fr);
    [defaults setObject:frStr  forKey:kSessionFrame];

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
                NSBeginAlertSheet(@"Requires Intranet Access", @"Okay", @"No Tunnel", @"Cancel", [NSApp keyWindow], self,nil, @selector(tunnelDidDismiss:returnCode:contextInfo:), NULL, @"Do you want to connect using a tunnel?"); 
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
    
    switch(sessionIndx)
    {
#if 0
        case 0: os = @"OSX"; browser = @"firefox"; version = @"3.6"; break;
        case 1: os = @"OSX"; browser = @"firefox"; version = @"8"; break;
        case 2: os = @"OSX"; browser = @"firefox"; version = @"9"; break;
        case 3: os = @"OSX"; browser = @"firefox"; version = @"10"; break;
        case 4: os = @"OSX"; browser = @"safari"; version = @"3"; break;
        case 5: os = @"OSX"; browser = @"safari"; version = @"4"; break;
        case 6: os = @"OSX"; browser = @"safari"; version = @"5"; break;
        case 7: os = @"OSX"; browser = @"opera"; version = @"9"; break;
        case 8: os = @"OSX"; browser = @"opera"; version = @"10"; break;                        
        case 9: os = @"OSX"; browser = @"opera"; version = @"11"; break;                        
        case 10: os = @"OSX"; browser = @"googlechrome"; version = @""; break;
#endif

        case 0: os = @"Windows 2003"; browser = @"iexplore"; version = @"6"; break;
        case 1: os = @"Windows 2003"; browser = @"iexplore"; version = @"7"; break;
        case 2: os = @"Windows 2003"; browser = @"iexplore"; version = @"8"; break;
        case 3: os = @"Windows 2008"; browser = @"iexplore"; version = @"9"; break;
        case 4: os = @"Windows 2003"; browser = @"firefox"; version = @"3.6"; break;
        case 5: os = @"Windows 2003"; browser = @"firefox"; version = @"8"; break;
        case 6: os = @"Windows 2003"; browser = @"firefox"; version = @"9"; break;
        case 7: os = @"Windows 2008"; browser = @"firefox"; version = @"10"; break;
        case 8: os = @"Linux"; browser = @"firefox"; version = @"3.6"; break;
        case 9: os = @"Linux"; browser = @"firefox"; version = @"9"; break;
        case 10: os = @"Linux"; browser = @"firefox"; version = @"10"; break;
        case 11: os = @"Windows 2003"; browser = @"safari"; version = @"3"; break;
        case 12: os = @"Windows 2003"; browser = @"safari"; version = @"4"; break;
        case 13: os = @"Windows 2008"; browser = @"safariproxy"; version = @"5"; break;
        case 14: os = @"Windows 2003"; browser = @"opera"; version = @"9"; break;
        case 15: os = @"Windows 2003"; browser = @"opera"; version = @"10"; break;                        
        case 16: os = @"Windows 2003"; browser = @"opera"; version = @"11"; break;                        
        case 17: os = @"Linux"; browser = @"opera"; version = @"11"; break;                        
        case 18: os = @"Windows 2008"; browser = @"googlechrome"; version = @""; break;
		case 19: os = @"Linux"; browser = @"googlechrome"; version = @""; break;
    }
    if([type isEqualToString:@"os"])
        return os;
    if([type isEqualToString:@"browser"])        
        return browser;
    if([type isEqualToString:@"version"]) 
        return version;
    return @"";    
}


@end
