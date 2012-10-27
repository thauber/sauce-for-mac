//
//  waitSession.m
//  scout
//
//  Created by Sauce Labs on 10/26/12.
//  Copyright (c) 2012 Sauce Labs. All rights reserved.
//

#import "waitSession.h"
#import "ScoutWindowController.h"

@implementation waitSession
@synthesize waitText;

- (id)init:(NSInteger)minutes
{
    self = [super init];
    if(self)
    {
        [NSBundle loadNibNamed:@"waitSession"  owner:self];
        NSString *txt = [NSString stringWithFormat:@"Please Wait %ld more minutes and you can try scout again. Sauce Labs offers a variety of plans, including free testing plans.",minutes];
        [waitText setStringValue:txt];        
        [NSApp beginSheet:panel modalForWindow:[[ScoutWindowController sharedScout] window] modalDelegate:self  didEndSelector:nil   contextInfo:nil];
    }
    return self;
}

-(void)quitSheet
{
    [NSApp endSheet:panel];
    [panel orderOut:nil];
}


- (IBAction)keepWaiting:(id)sender
{
    [self quitSheet];
}

- (IBAction)visitSauceLabs:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://saucelabs.com"]];
    [self quitSheet];
}

@end
