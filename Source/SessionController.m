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
    selectedTag = [defs integerForKey:kSessionTag];
    if(selectedTag)
    {
        
        NSString *str = [defs stringForKey:kSessionFrame];
        if(str)
            selectedFrame = NSRectFromString(str);
        else
        {
            NSView *vv = (NSView*)defaultBrowser;
            NSRect frame = [vv frame];
            NSPoint pt = [vv.superview convertPoint:vv.frame.origin toView:[self view]];
            pt.x -= 4;
            frame.origin = pt;
            frame.size.width = 84;
            selectedFrame = frame;
        }
        [self selectBrowser:self];
    }
    
    [box2 setSessionCtlr:self];     // pass mouseclick in box here
    
    // create hoverbox
    frame = NSMakeRect(0,0,22,0);
    hoverBox = [[NSView alloc ] initWithFrame:frame];
    [[self view] addSubview:hoverBox];
    CALayer *viewLayer = [CALayer layer];
    [viewLayer setBackgroundColor:CGColorCreateGenericRGB(0.0, 0.0, 0.0, 0.1)]; //RGB plus Alpha Channel
    [hoverBox setWantsLayer:YES]; // view's backing store is using a Core Animation Layer
    [hoverBox setLayer:viewLayer];
    
    [self addTrackingAreas];
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

}

- (void)addTrackingAreas
{
    int indx = 0;
    NSRect rr;
    NSTrackingRectTag tag;
    id xarr[kNumTrackItems] = {b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13,b14,b15,b16,b17,b18,b19};
    for(int i=0;i < kNumTrackItems; i++) // track mouse in/out over all buttons and included area
    {
        barr[i] = xarr[i];      // copy nsimageview objects to ivar array
        rr = [xarr[indx] frame];
        rr.origin.x -= 4;
        rr.size.width = 84;
        tag = [box2 addTrackingRect:rr owner:self userData:nil assumeInside:NO];
        trarr[indx++] = tag;    
    }
    hoverFrame.size.width = 0;      // mouse is not within a rect(?guaranteed on startup?)
}

- (void)mouseEntered:(NSEvent *)theEvent
{
    int tn = [theEvent trackingNumber];
    for(int i=0; i < kNumTrackItems; i++)
    {
        if(tn == trarr[i])
        {
            hoverFrame = ((NSView*)barr[i]).frame;
            hoverFrame.origin.x -= 4;
            hoverFrame.size.width = 84;            
            NSPoint pt = [box2 convertPoint:hoverFrame.origin toView:[self view]];
            hoverFrame.origin = pt;
            [hoverBox setFrame:hoverFrame];
            return;
        }
    }
    hoverFrame.size.width = 0;
    [hoverBox setFrame:hoverFrame];
}

- (void)mouseExited:(NSEvent *)theEvent
{
    hoverFrame.size.width = 0;
    [hoverBox setFrame:hoverFrame];    
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
    
    if(sender == (id)self)
        frame = selectedFrame;
    else
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
    [defaults setInteger:selectedTag  forKey:kSessionTag];
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
    
    switch(selectedTag)
    {
        case 201: os = @"OSX"; browser = @"firefox"; version = @"3.6"; break;
        case 202: os = @"OSX"; browser = @"firefox"; version = @"8"; break;
        case 203: os = @"OSX"; browser = @"firefox"; version = @"9"; break;
        case 204: os = @"OSX"; browser = @"firefox"; version = @"10"; break;
        case 301: os = @"OSX"; browser = @"safari"; version = @"3"; break;
        case 302: os = @"OSX"; browser = @"safari"; version = @"4"; break;
        case 303: os = @"OSX"; browser = @"safari"; version = @"5"; break;
        case 401: os = @"OSX"; browser = @"opera"; version = @"9"; break;
        case 402: os = @"OSX"; browser = @"opera"; version = @"10"; break;                        
        case 403: os = @"OSX"; browser = @"opera"; version = @"11"; break;                        
        case 501: os = @"OSX"; browser = @"googlechrome"; version = @""; break;

        case 105: os = @"Windows 2003"; browser = @"iexplore"; version = @"6"; break;
        case 106: os = @"Windows 2003"; browser = @"iexplore"; version = @"7"; break;
        case 107: os = @"Windows 2003"; browser = @"iexplore"; version = @"8"; break;
        case 108: os = @"Windows 2008"; browser = @"iexplore"; version = @"9"; break;
        case 205: os = @"Windows 2003"; browser = @"firefox"; version = @"3.6"; break;
        case 206: os = @"Windows 2003"; browser = @"firefox"; version = @"8"; break;
        case 207: os = @"Windows 2003"; browser = @"firefox"; version = @"9"; break;
        case 208: os = @"Windows 2008"; browser = @"firefox"; version = @"10"; break;
        case 305: os = @"Windows 2003"; browser = @"safari"; version = @"3"; break;
        case 306: os = @"Windows 2003"; browser = @"safari"; version = @"4"; break;
        case 307: os = @"Windows 2008"; browser = @"safariproxy"; version = @"5"; break;
        case 405: os = @"Windows 2003"; browser = @"opera"; version = @"9"; break;
        case 406: os = @"Windows 2003"; browser = @"opera"; version = @"10"; break;                        
        case 407: os = @"Windows 2003"; browser = @"opera"; version = @"11"; break;                        
        case 505: os = @"Windows 2008"; browser = @"googlechrome"; version = @""; break;

        case 209: os = @"Linux"; browser = @"firefox"; version = @"3.6"; break;
        case 210: os = @"Linux"; browser = @"firefox"; version = @"9"; break;
        case 211: os = @"Linux"; browser = @"firefox"; version = @"10"; break;
        case 409: os = @"Linux"; browser = @"opera"; version = @"11"; break;                        
        case 509: os = @"Linux"; browser = @"googlechrome"; version = @""; break;
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
