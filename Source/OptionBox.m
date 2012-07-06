//
//  OptionBox.m
//  scout
//
//  Created by ackerman dudley on 6/7/12.
//  Copyright (c) 2012 Sauce Labs. All rights reserved.
//

#import "OptionBox.h"
#import "SessionController.h"

@implementation OptionBox

- (id)settracker:(NSRect)rr
{
    NSTrackingArea *ta = [[NSTrackingArea alloc] initWithRect:rr options:NSTrackingMouseEnteredAndExited+NSTrackingCursorUpdate+NSTrackingActiveAlways owner:self userInfo:nil];
    [self addTrackingArea:ta]; 
    [[NSCursor pointingHandCursor] setOnMouseEntered:YES];

    return ta;
}

- (void) cursorUpdate:(NSEvent *)theEvent
{
    if([sessionCtlr hoverIndx]>=0 && [sessionCtlr hoverIndx]<30)
        [[NSCursor pointingHandCursor] set];
    else
        [[NSCursor arrowCursor] set];
}

- (void)mouseEntered:(NSEvent *)theEvent
{
/*
    id tn = [theEvent trackingArea];
    if(sessionCtlr)
        [sessionCtlr handleMouseEntered:tn];
*/
}

- (void)mouseExited:(NSEvent *)theEvent
{
//    [sessionCtlr handleMouseExited];
}

/*
-(void)mouseUp:(NSEvent *)theEvent
{
    if([theEvent clickCount] > 1)               // double click
        [sessionCtlr doubleClick];
    else
        [sessionCtlr selectBrowser:self];      // select currently hovered over item
}
*/

- (void)setSessionCtlr:(SessionController *)sc
{
    sessionCtlr = sc;
}


@end
