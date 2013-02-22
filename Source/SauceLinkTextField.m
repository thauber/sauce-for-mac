//
//  SauceLinkTextField.m
//  scout
//
//  Created by Sauce Labs on 11/10/12.
//  Copyright (c) 2012 Sauce Labs. All rights reserved.
//

#import "SauceLinkTextField.h"

@implementation SauceLinkTextField

-(void)mouseUp:(NSEvent *)theEvent
{
    [self sendAction:[self action] to:[self target]];    
}

- (void)drawRect:(NSRect)dirtyRect
{
    NSColor *txtclr = [NSColor blueColor];
    NSDictionary *asdict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:NSUnderlineStyleSingle], NSUnderlineStyleAttributeName,txtclr,NSForegroundColorAttributeName,nil];
    [[self stringValue] drawInRect:dirtyRect withAttributes:asdict];
}

@end
