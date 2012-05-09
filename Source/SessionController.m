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

@implementation SessionController

@synthesize panel;
@synthesize view;
@synthesize cancelBtn;
@synthesize connectBtn;
@synthesize connectIndicatorText;
@synthesize connectIndicator;
@synthesize box1;
@synthesize box2;
@synthesize url;

- (id)init
{
    self = [super init];
    if(self)
    {
        [NSBundle loadNibNamed:@"SessionController"  owner:self];
        // recompute position of mswindows/linux sections when osx is hidden
        int h1 = box1.frame.size.height;
        NSRect fr = box2.frame;
        fr.origin.y += h1;
        [box2 setFrame:fr];
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
    selectedTag = [defs integerForKey:kSessionTag];
    if(selectedTag)
    {
        
        NSString *str = [defs stringForKey:kSessionFrame];
        if(str)
        {
            selectedFrame = NSRectFromString(str);
            [self selectBrowser:self];
        }
    }
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
    
    if([[ScoutWindowController sharedScout] tabCount])
    {
        [cancelBtn setHidden:NO];
        [cancelBtn setFrame: NSMakeRect(0,0,0,0)];      // so esc key works
    }
    else
        [cancelBtn setHidden:YES];
    
    [NSApp beginSheet:panel modalForWindow:[[ScoutWindowController sharedScout] window] modalDelegate:self  didEndSelector:nil   contextInfo:nil];        
}

- (IBAction)performClose:(id)sender
{
    [NSApp endSheet:panel];
    [panel orderOut:nil];
}

- (IBAction)selectBrowser:(id)sender 
{
    NSRect frame;
    
    if(sender == (id)self)
        frame = selectedFrame;
    else
    {
        selectedTag = [sender tag];
        // compute new position and width for selection box
        frame = [sender frame];
        NSView *vv = (NSView*)sender;
        NSPoint pt = [vv.superview convertPoint:vv.frame.origin toView:[self view]];
        frame.origin = pt;
        frame.size.width += frame.size.width + 4;
        selectedFrame = frame;
    }
    
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
            
    [connectBtn setState:NSOffState];
    if([os length])
    {
        [url setEnabled:NO];
        [connectIndicator startAnimation:self];
        [connectIndicatorText setStringValue:@"Connecting..."];
        
        [connectIndicatorText display];
        
        [connectBtn setTitle:@"Cancel"];
        [connectBtn setAction: @selector(cancelConnect:)];
        [connectBtn setKeyEquivalent:@"."];
        [connectBtn setKeyEquivalentModifierMask:NSCommandKeyMask];
	    [[SaucePreconnect sharedPreconnect] setOptions:os browser:browser browserVersion:version url:urlstr];
        [NSApp endSheet:panel];

        [NSThread detachNewThreadSelector:@selector(preAuthorize:) toTarget:[SaucePreconnect sharedPreconnect] withObject:nil];
    }
    else 
    {
        NSBeginAlertSheet(@"Session Options Error", @"Okay", nil, nil, [NSApp keyWindow], self,nil, NULL, NULL, @"User Needs to select a browser");    
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:urlstr  forKey:kSessionURL];
    [defaults setInteger:selectedTag  forKey:kSessionTag];
    NSString *frStr = NSStringFromRect(selectedFrame);
    [defaults setObject:frStr  forKey:kSessionFrame];
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

- (IBAction)cancelConnect: (id)sender
{
    // cancel current connection attempt
    [[SaucePreconnect sharedPreconnect] setCancelled:YES];
    [[RFBConnectionManager sharedManager] cancelConnection];
    [panel orderOut:nil];
    [[ScoutWindowController sharedScout] errOnConnect:@"User cancelled"];
    [connectBtn setState:NSOffState];
}

/* Update the interface to indicate the end of the connection attempt. */
- (void)connectionAttemptEnded
{
#if 0    
    if([[ScoutWindowController sharedScout] tabCount])
    {
        [NSApp endSheet:panel];
        [panel orderOut:nil];
        return;
    }
    
    [[SaucePreconnect sharedPreconnect] cancelHeartbeat];
	[connectIndicator stopAnimation:self];
	[connectIndicatorText setStringValue:@""];
	[connectIndicatorText display];
    
    [connectBtn setTitle:@"Scout!"];
    [connectBtn setAction: @selector(connect:)];
    [connectBtn setKeyEquivalent:@"\r"];
    [connectBtn setKeyEquivalentModifierMask:0];
    [connectBtn setState:NSOnState];
#endif
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
