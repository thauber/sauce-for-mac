//
//  TBISub.m
//  scout
//
//  Created by saucelabs on 12/31/12.
//  Copyright (c) 2012 Sauce Labs. All rights reserved.
//

#import "TBISub.h"
#include "AppDelegate.h"

@implementation TBISub
- (void)validate
{
    if([[NSApp delegate] isDemoAccount])
    {
        [[[NSApp delegate] tunnelMenuItem] setAction:nil];
        [self setEnabled:NO];
    }
    else
    {
        [[[NSApp delegate] tunnelMenuItem] setAction:@selector(doTunnel:)];
        [self setEnabled:YES];
    }
}
@end
