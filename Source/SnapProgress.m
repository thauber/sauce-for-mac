//
//  SnapProgress.m
//  scout
//
//  Created by ackerman dudley on 5/27/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "SnapProgress.h"
#import "ScoutWindowController.h"

@implementation SnapProgress
@synthesize panel;
@synthesize takingTxt;
@synthesize urlLabel;
@synthesize url;
@synthesize indicator;

- (id)init
{
    if (self = [super init]) 
    {
        [NSBundle loadNibNamed:@"snapProgress" owner:self];
        [panel setOpaque:YES];
        [panel setAlphaValue:1.0];
        [urlLabel setHidden:YES];
        [indicator startAnimation:self];
        [NSApp beginSheet:panel modalForWindow:[[ScoutWindowController sharedScout] window] modalDelegate:self  didEndSelector:nil   contextInfo:nil];
    }
    return self;
}

- (IBAction)OkButton:(id)sender {
    [NSApp endSheet:panel];
    [panel orderOut:nil];
    panel = nil;
    [[ScoutWindowController sharedScout] snapshotDone];
}

- (void)setServerURL:(NSString*)surl
{
    if(panel)
    {
        NSString *status = @"taken";
        if(!surl)
        {
            surl = @"";
            status = @"failed to take";
        }
        NSString *tstr = [NSString stringWithFormat:@"Server has %@ the snapshot.", status];
        [url setStringValue:surl];
        [urlLabel setHidden:NO];
        [takingTxt setStringValue:tstr];
        [indicator stopAnimation:self];
        [indicator setHidden:YES];
    }
}
@end
