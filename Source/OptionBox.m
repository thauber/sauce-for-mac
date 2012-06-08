//
//  OptionBox.m
//  scout
//
//  Created by ackerman dudley on 6/7/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "OptionBox.h"
#import "SessionController.h"

@implementation OptionBox

-(void)mouseUp:(NSEvent *)theEvent
{
    NSLog(@"click");
    [sessionCtlr selectBrowser:self];      // handle click if in a tracking rect
}

- (void)setSessionCtlr:(SessionController *)sc
{
    sessionCtlr = sc;
}


@end
