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

@synthesize defaultBrowser;
@synthesize panel;
@synthesize view;
@synthesize cancelBtn;
@synthesize connectBtn;
@synthesize connectIndicatorText;
@synthesize connectIndicator;
@synthesize box2;
@synthesize url;

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
    [connectIndicatorText setStringValue:@""];
        
    // use last used values from prefs
    NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
    NSString *urlstr = [defs stringForKey:kSessionURL];
    if(urlstr)
        [self.url setStringValue:urlstr];
    else
        [connectBtn setEnabled:NO];
    [[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(textDidChange:) name: NSTextDidChangeNotification object: nil];
    NSRect frame;
    sessionIndx = [defs integerForKey:kSessionIndx];
    if(!sessionIndx)
        sessionIndx = 3;           // default is windows 9
    
    // create hoverbox
    frame = NSMakeRect(0,0,0,0);
    hoverBox = [[NSView alloc ] initWithFrame:frame];
    [[self view] addSubview:hoverBox];
    CALayer *viewLayer = [CALayer layer];
    [viewLayer setBackgroundColor:CGColorCreateGenericRGB(0.0, 0.0, 0.0, 0.1)]; //RGB plus Alpha Channel
    [hoverBox setWantsLayer:YES]; // view's backing store is using a Core Animation Layer
    [hoverBox setLayer:viewLayer];
    
    [self addTrackingAreas];

    [self mouseEntered:nil];
    [self selectBrowser:nil];       // get last selection or default selected
    [box2 setSessionCtlr:self];     // pass mouseclick to 'selectBrowser' method 
    
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

}

- (int)hoverIndx
{
    return hoverIndx;
}

- (void)addTrackingAreas
{
    NSRect rr;
    NSTrackingRectTag tag;
    id xarr[kNumTrackItems] = {b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13,b14,b15,b16,b17,b18,b19};
    for(int i=0;i < kNumTrackItems; i++) // track mouse in/out over all buttons and included area
    {
        barr[i] = xarr[i];      // copy nsimageview objects to ivar array
        rr = [xarr[i] frame];
        rr.origin.x -= 4;
        rr.size.width = 80;     // trackingrect width - NB: careful, 84 is too big
        tag = [box2 addTrackingRect:rr owner:self userData:nil assumeInside:NO];
        trarr[i] = tag;
        [box2 settracker:rr];
    }
    [[NSCursor pointingHandCursor] setOnMouseEntered:YES];
    hoverFrame.size.width = 0;      // mouse is not within a rect(?guaranteed on startup?)
}

- (void)mouseEntered:(NSEvent *)theEvent
{
    int tn = [theEvent trackingNumber];
    if(!theEvent)       // on initial call
        tn = trarr[hoverIndx];
    
    for(int i=0; i < kNumTrackItems; i++)
    {
        if(tn == trarr[i])
        {
            hoverFrame = ((NSView*)barr[i]).frame;
            hoverFrame.origin.x -= 4;
            hoverFrame.size.width = 80;            
            NSPoint pt = [box2 convertPoint:hoverFrame.origin toView:[self view]];
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

- (void)mouseExited:(NSEvent *)theEvent
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
    [[SaucePreconnect sharedPreconnect] setErrStr:@"User cancelled"];
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
    
    if(sender == (id)self)      // on init
        frame = selectedFrame;
    else                        // from mouseEntered
        frame = hoverFrame;
    
    if(!selectBox)
    {
        // create box
        selectBox = [[NSView alloc ] initWithFrame:frame];
        [[self view] addSubview:selectBox];
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
    }
    
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
    NSString *frStr = NSStringFromRect(selectedFrame);
    [defaults setObject:frStr  forKey:kSessionFrame];

    [[SaucePreconnect sharedPreconnect] setOptions:os browser:browser browserVersion:version url:urlstr];
    [NSApp endSheet:panel];

    if(urlstr)
    {
        NSURL *uurl = [NSURL URLWithString:urlstr];
        if(uurl)        // check for localhost
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
    }
}

- (void)tunnelDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    switch (returnCode)
    {
        case NSAlertDefaultReturn:
            [[NSApp delegate] doTunnel:self];
            return;
        case NSAlertAlternateReturn:
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
        case 8: os = @"Windows 2003"; browser = @"safari"; version = @"3"; break;
        case 9: os = @"Windows 2003"; browser = @"safari"; version = @"4"; break;
        case 10: os = @"Windows 2008"; browser = @"safariproxy"; version = @"5"; break;
        case 11: os = @"Windows 2003"; browser = @"opera"; version = @"9"; break;
        case 12: os = @"Windows 2003"; browser = @"opera"; version = @"10"; break;                        
        case 13: os = @"Windows 2003"; browser = @"opera"; version = @"11"; break;                        
        case 14: os = @"Windows 2008"; browser = @"googlechrome"; version = @""; break;

        case 15: os = @"Linux"; browser = @"firefox"; version = @"3.6"; break;
        case 16: os = @"Linux"; browser = @"firefox"; version = @"9"; break;
        case 17: os = @"Linux"; browser = @"firefox"; version = @"10"; break;
        case 18: os = @"Linux"; browser = @"opera"; version = @"11"; break;                        
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
