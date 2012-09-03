//
//  sessionConnect.m
//  scout
//
//  Created by ackerman dudley on 8/31/12.
//  Copyright (c) 2012 Sauce Labs. All rights reserved.
//

#import "sessionConnect.h"

@interface sessionConnect ()

@end

@implementation sessionConnect
@synthesize connectionIndicator;
@synthesize osImage;
@synthesize browserImage;

- (id)init
{
    self = [super init];
    if(self)
    {
        [NSBundle loadNibNamed:@"sessionConnect"  owner:self];
        [connectionIndicator startAnimation:self];
    }
    return self;
}

- (IBAction)cancel:(id)sender
{
    // TODO: remove tab with this view
}

@end
