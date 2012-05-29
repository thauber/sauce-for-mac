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
@synthesize cancelButton;

- (id)init
{
    if (self = [super init]) 
    {
        [NSBundle loadNibNamed:@"SnapProgress" owner:self];
        [panel setOpaque:YES];
        [panel setAlphaValue:1.0];
        [urlLabel setHidden:YES];
        [cancelButton setFrame:NSMakeRect(0,0,0,0)];       // allow 'esc' to quit
        [indicator startAnimation:self];
        [NSApp beginSheet:panel modalForWindow:[[ScoutWindowController sharedScout] window] modalDelegate:self  didEndSelector:nil   contextInfo:nil];
    }
    return self;
}

- (IBAction)OkBtutton:(id)sender {
    [NSApp endSheet:panel];
    [panel orderOut:nil];
    panel = nil;
    [[ScoutWindowController sharedScout] snapshotDone];
}

- (void)setServerURL:(NSString*)snapId
{
    if(panel)
    {
        if(!snapId)
            snapId = @"Failed to get snap id";
        NSString *surl = snapId; // TODO: construct url

        [url setStringValue:surl];
        [urlLabel setHidden:NO];
        [takingTxt setStringValue:@"Server has taken the snapshot]"];
        [indicator stopAnimation:self];
        [indicator setHidden:YES];
        [self OkBtutton:self];
    }
}
@end
