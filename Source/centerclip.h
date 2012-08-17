//
//  centerclip.h
//  scout
//
//  Created by ackerman dudley on 8/16/12.
//  Copyright (c) 2012 Sauce Labs. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface centerclip : NSClipView
{
    NSPoint viewPoint;      // current scroll point
}
- (id) initWithFrame:(NSRect)frame;
- (void) centerView;
// NSClipView Method Overrides
- (NSPoint) constrainScrollPoint:(NSPoint)proposedNewOrigin;
- (void) viewBoundsChanged:(NSNotification*)notification;
- (void) viewFrameChanged:(NSNotification*)notification;
- (void) setFrame:(NSRect)frameRect;
- (void) setFrameOrigin:(NSPoint)newOrigin;
- (void) setFrameSize:(NSSize)newSize;
- (void) setFrameRotation:(CGFloat)angle;
@end
