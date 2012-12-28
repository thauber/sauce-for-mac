//
//  demoConnectController.m
//  scout
//
//  Created by saucelabs on 12/28/12.
//  Copyright (c) 2012 Sauce Labs. All rights reserved.
//

#include "SessionController.h"
#import "demoConnectController.h"
#include "AppDelegate.h"

@implementation demoConnectController

- (id)init:(SessionController*)sessionCtrl
{
    self = [super init];
    if(self)
    {
        [NSBundle loadNibNamed:@"demoConnect"  owner:self];
        [NSApp beginSheet:panel modalForWindow:[sessionCtrl panel] modalDelegate:self  didEndSelector:nil   contextInfo:nil];
    }
    return self;
}

- (void)endPanel
{
    [NSApp endSheet:panel];
    [panel orderOut:nil];
    panel = nil;

}

- (IBAction)visitDemoConnect:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:
     [NSURL URLWithString:@"http://saucelabs.com/mac/connect-demo"]];
    [self endPanel];
}

- (IBAction)demoConnectBack:(id)sender
{
    [self endPanel];
}

@end
