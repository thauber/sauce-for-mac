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

- (void)settracker:(NSRect)rr
{
    NSTrackingArea *ta = [[NSTrackingArea alloc] initWithRect:rr options:NSTrackingMouseEnteredAndExited+NSTrackingCursorUpdate+NSTrackingActiveAlways owner:self userInfo:nil];
    [self addTrackingArea:ta];    
}

- (void) cursorUpdate:(NSEvent *)theEvent
{
    if([sessionCtlr hoverIndx]>=0 && [sessionCtlr hoverIndx]<30)
        [[NSCursor pointingHandCursor] set];
    else
        [[NSCursor arrowCursor] set];
}

-(void)mouseUp:(NSEvent *)theEvent
{
    [sessionCtlr selectBrowser:self];      // handle click if in a tracking rect
}

- (void)setSessionCtlr:(SessionController *)sc
{
    sessionCtlr = sc;
}


@end
