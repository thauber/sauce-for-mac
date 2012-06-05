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
        hiddenDisplay = NO;    
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
    if(!hiddenDisplay)           // tunnel is not connected
    {
        NSString *str = @"Please wait while we launch Sauce Connect, (which allows testing local websites) ...\n\n";
        [[[infoTV textStorage] mutableString] appendString: str];
        [hideButton setHidden:YES];      // don't show b/c we are not connected
        [self doTunnel];
    }

    hiddenDisplay = NO;
    [NSApp beginSheet:panel modalForWindow:window modalDelegate:self
       didEndSelector:nil   contextInfo:nil];
}

- (BOOL)hiddenDisplay
{
    return hiddenDisplay;
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
            [self doHide:self];
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
    NSString *farg = [NSString stringWithFormat:@"java -jar \"%@\" %@ %@", path, user, ukey];
    
    self.ftask = [[NSTask alloc] init];
    self.fpipe = [NSPipe pipe];
    [ftask setStandardOutput:fpipe];
    [ftask setLaunchPath:@"/bin/bash"];
    [ftask setArguments:[NSArray arrayWithObjects:@"-c", farg, nil]];
    NSString *cdir = [NSString stringWithFormat:@"%@/Library/Logs",NSHomeDirectory()];
    [ftask setCurrentDirectoryPath:cdir];
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
}


@end
