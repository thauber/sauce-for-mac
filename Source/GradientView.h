//
//  GradientView.h
//  scout
//
//  Created by ackerman dudley on 6/27/12.
//  Copyright (c) 2012 Sauce Labs. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface GradientView : NSView
{
    NSColor *startingColor;
    NSColor *endingColor;
    int angle;
    BOOL noDraw;
}

// Define the variables as properties
@property(nonatomic, retain) NSColor *startingColor;
@property(nonatomic, retain) NSColor *endingColor;
@property(assign) int angle;
@property(assign) BOOL noDraw;

- (void)setColor:(float)start end:(float)end startAlpha:(float)startAlpha endAlpha:(float)endAlpha;

@end
