//
//  TunnelController.m
//  scout
//
//  Created by ackerman dudley on 5/11/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "TunnelController.h"
#import "ScoutWindowController.h"
#import "SaucePreconnect.h"
#import "AppDelegate.h"

@implementation TunnelController
@synthesize panel;
@synthesize closeButton;
@synthesize hideButton;
@synthesize infoTV;
@synthesize ftask;
@synthesize fhand;
@synthesize fpipe;

-(id)init
{
    if (self = [super init])
    {
        [NSBundle loadNibNamed:@"tunnel" owner:self];
    }
    return self;
}

-(void)terminate
{
    if(ftask)
        [ftask terminate];    
}

- (void)runSheetOnWindow:(NSWindow *)window
{
    [[NSApp delegate] toggleTunnelDisplay];
    NSString *str = @"Now launching Sauce Connect, allowing you to test local websites";
    [[[infoTV textStorage] mutableString] appendString: str];
    [NSApp beginSheet:panel modalForWindow:window modalDelegate:self
       didEndSelector:nil   contextInfo:nil];
    hiddenDisplay = NO;    
}

- (BOOL)hiddenDisplay
{
    return hiddenDisplay;
}

- (void)setHiddenDisplay:(BOOL)hidden;
{
    hiddenDisplay = hidden;
}

-(void)displayInfo:(NSString *)str
{
    if([str length])
    {
        [[[infoTV textStorage] mutableString] appendString: str];
        NSRange range = NSMakeRange([[infoTV string] length], 0);
        [infoTV scrollRangeToVisible: range];
        NSRange textRange =[str rangeOfString:@"Connected!"];        
        if(textRange.location != NSNotFound)    //Does contain the substring
        {
            [[ScoutWindowController sharedScout] tunnelConnected:YES];            
        }           
    }
}

- (IBAction)doClose:(id)sender
{
    if(panel)
    {
        [NSApp endSheet:panel];
        [panel orderOut:self];
    }
    self.panel = nil;
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    [ftask terminate];
    self.ftask = nil;
    self.fhand = nil;
    self.fpipe = nil;
    [[NSApp delegate] setTunnelCtrlr:nil];
    [[NSApp delegate] toggleTunnelDisplay];
}

- (IBAction)doHide:(id)sender
{
    [NSApp endSheet:panel];
    [panel orderOut:self];
    hiddenDisplay = YES;
    [[NSApp delegate] toggleTunnelDisplay];
    [[NSApp delegate] showOptionsIfNoTabs];
}

- (void)doTunnel
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"Sauce-Connect" ofType:@"jar"];
    NSString *user = [[SaucePreconnect sharedPreconnect] user];
    NSString *ukey = [[SaucePreconnect sharedPreconnect] ukey];
    
    NSString *farg = [NSString stringWithFormat:@"java -jar %@ %@ %@", path, user, ukey];
    
    self.ftask = [[NSTask alloc] init];
    self.fpipe = [NSPipe pipe];
    [ftask setStandardOutput:fpipe];
    [ftask setLaunchPath:@"/bin/bash"];
    [ftask setArguments:[NSArray arrayWithObjects:@"-c", farg, nil]];
    self.fhand = [fpipe fileHandleForReading];        
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(endTunnel:)
                                                 name: NSTaskDidTerminateNotification
                                               object: nil];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(tunnelData:)
                                                 name: NSFileHandleReadCompletionNotification
                                               object: fhand];
    [fhand readInBackgroundAndNotify];
    [ftask launch];		// setup tunnel
}

-(void)tunnelData:(NSNotification *)notif
{
    NSData *data = [[notif userInfo] objectForKey: NSFileHandleNotificationDataItem];    
    NSString *str = [[NSString alloc] initWithData: data encoding:NSASCIIStringEncoding];
    [self displayInfo:str];
    [fhand readInBackgroundAndNotify];
}

-(void)endTunnel: (NSNotification *) notif
{
//    [self doClose:self];
}


@end
