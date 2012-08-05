//
//  StopSession.m
//  scout
//
//  Created by ackerman dudley on 8/4/12.
//  Copyright (c) 2012 Sauce Labs. All rights reserved.
//

#import "StopSession.h"
#import "ScoutWindowController.h"
#import "AppDelegate.h"

@implementation StopSession

- (id)init
{
    self = [super init];
    if(self)
    {
        [NSBundle loadNibNamed:@"stopSession"  owner:self];
        [NSApp beginSheet:panel modalForWindow:[[ScoutWindowController sharedScout] window] modalDelegate:self  didEndSelector:nil   contextInfo:nil];
    }
    return self;
    
}

- (IBAction)closeSession:(id)sender
{
    [self endPanel];
    [[ScoutWindowController sharedScout] closeTab:nil];
}

- (IBAction)keepSession:(id)sender
{
    [self endPanel];
}

- (void)endPanel
{
    [NSApp endSheet:panel];
    [panel orderOut:nil];    
    [[NSApp delegate] setNoShowCloseSession:[againChkbox state]==1];
    [self release];
}

@end
