//
//  centerclip.m
//  scout
//
//  Created by ackerman dudley on 8/16/12.
//  Copyright (c) 2012 Sauce Labs. All rights reserved.
//

#import "centerclip.h"

@implementation centerclip

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        viewPoint = NSMakePoint(0.0, 1.0);      // have initially scroll so top is displayed
        maxvertical = 0.0;
        [self setAutoresizesSubviews:NO];
    }
    
    return self;
}

- (void) centerView {
    NSRect docRect = [[self documentView] frame];
    NSRect clipRect = [self bounds];
    // Center the clipping rect origin x
    if (docRect.size.width < clipRect.size.width) {
        clipRect.origin.x = roundf((docRect.size.width - clipRect.size.width) / 2.0);
    }
#if 0
    else {
        clipRect.origin.x = roundf(viewPoint.x * docRect.size.width - (clipRect.size.width / 2.0));
    }
#endif
    // Center the clipping rect origin y
    if (docRect.size.height < clipRect.size.height) {
        clipRect.origin.y = roundf((docRect.size.height - clipRect.size.height) / 2.0);
    }
#if 0
    else {
        clipRect.origin.y = roundf(viewPoint.y * docRect.size.height - (clipRect.size.height / 2.0));
    }
#endif
    // Scroll the document to the selected center point
    NSScrollView* scrollView = (NSScrollView*)[self superview];
    [scrollView scrollClipView:self toPoint:[self constrainScrollPoint:clipRect.origin]];
}

- (NSPoint) constrainScrollPoint:(NSPoint)proposedNewOrigin
{
    NSRect docRect = [[self documentView] frame];
    NSRect clipRect = [self bounds];
    CGFloat maxX = docRect.size.width - clipRect.size.width;
    CGFloat maxY = docRect.size.height - clipRect.size.height;
    clipRect.origin = proposedNewOrigin;
    
    if (docRect.size.width < clipRect.size.width) {
        clipRect.origin.x = roundf(maxX / 2.0);
    } else {
        clipRect.origin.x = roundf(MAX(0, MIN(clipRect.origin.x, maxX)));
    }
    if (docRect.size.height < clipRect.size.height) {
        clipRect.origin.y = roundf(maxY / 2.0);
    } else {
        clipRect.origin.y = roundf(MAX(0, MIN(clipRect.origin.y, maxY)));
    }
//    viewPoint.x = NSMidX(clipRect) / docRect.size.width;
//    viewPoint.y = NSMidY(clipRect) / docRect.size.height;
//    if(viewPoint.y > maxvertical)
//        maxvertical = viewPoint.y;
    
    return clipRect.origin;
}


- (void) viewBoundsChanged:(NSNotification*)notification {
    [super viewBoundsChanged:notification];
    [self centerView];
}
- (void) viewFrameChanged:(NSNotification*)notification {
    [super viewBoundsChanged:notification];
    [self centerView];
}
- (void) setFrame:(NSRect)frameRect {
    [super setFrame:frameRect];
    [self centerView];
}
- (void) setFrameOrigin:(NSPoint)newOrigin {
    [super setFrameOrigin:newOrigin];
    [self centerView];
}
- (void) setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    viewPoint.y = maxvertical;
    [self centerView];
}
- (void) setFrameRotation:(CGFloat)angle {
    [super setFrameRotation:angle];
    [self centerView];
}

@end
