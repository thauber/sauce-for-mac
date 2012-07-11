//
//  GradientView.m
//  scout
//
//  Created by ackerman dudley on 6/27/12.
//  Copyright (c) 2012 Sauce Labs. All rights reserved.
//

#import "GradientView.h"

@implementation GradientView

// Automatically create accessor methods
@synthesize startingColor;
@synthesize endingColor;
@synthesize angle;

- (id)initWithFrame:(NSRect)frame 
{
    self = [super initWithFrame:frame];
    if (self) {
        // initialize default for toolbar message gradient
        [self setStartingColor:[NSColor colorWithCalibratedWhite:0 alpha:.5]];      // half-transparent black
        [self setEndingColor:[NSColor colorWithCalibratedWhite:0 alpha:0]];         // transparent
        [self setAngle:270];        // top to bottom
    }
    return self;
}

- (void)setColor:(float)start end:(float)end startAlpha:(float)startAlpha endAlpha:(float)endAlpha
{
    [self setStartingColor:[NSColor colorWithCalibratedWhite:start alpha:startAlpha]];   // half-transparent black
    [self setEndingColor:[NSColor colorWithCalibratedWhite:end alpha:endAlpha]];         // transparent    
}

- (void)drawRect:(NSRect)rect 
{
    // Fill view with a top-down gradient
    // from startingColor to endingColor
    NSGradient* aGradient = [[NSGradient alloc]
                             initWithStartingColor:startingColor
                             endingColor:endingColor];
    [aGradient drawInRect:[self bounds] angle:angle];
    [aGradient release];
}

@end
