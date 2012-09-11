//
//  StopSession.m
//  scout
//
//  Created by ackerman dudley on 8/4/12.
//  Copyright (c) 2012 Sauce Labs. All rights reserved.
//

#import "StopConnect.h"
#import "ScoutWindowController.h"
#import "AppDelegate.h"
#import "PrefController.h"

@implementation StopConnect

- (id)init
{
    self = [super init];
    if(self)
    {
        [NSBundle loadNibNamed:@"stopConnect"  owner:self];
        [NSApp beginSheet:panel modalForWindow:[[ScoutWindowController sharedScout] window] modalDelegate:self  didEndSelector:nil   contextInfo:nil];
    }
    return self;
    
}

- (IBAction)closeConnect:(id)sender
{
    [self endPanel];
    [[NSApp delegate] doStopConnect:nil];
}

- (IBAction)keepConnect:(id)sender
{
    [self endPanel];
    [[NSApp delegate] closeStopConnect];
}

- (void)endPanel
{
    [NSApp endSheet:panel];
    [panel orderOut:nil];
    BOOL bNoShow = [againChkbox state]==1;
    [[NSApp delegate] setNoShowCloseConnect:bNoShow];
    if(bNoShow)
        [[PrefController sharedController] setNoShowWarning];
}

@end
