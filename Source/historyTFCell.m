//
//  historyTFCell.m
//  scout
//
//  Created by ackerman dudley on 8/30/12.
//  Copyright (c) 2012 Sauce Labs. All rights reserved.
//

#import "historyTFCell.h"

@implementation historyTFCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    NSTableView *tv = (NSTableView*)controlView;
    NSTableColumn *aCol = [[tv tableColumns] 
                           objectAtIndex:[tv columnAtPoint:
                                          [tv convertPoint:cellFrame.origin
                                                    fromView:nil]]];

    // underline the url in the 2nd column
    NSDictionary *asdict = nil;
    NSColor *txtclr = [NSColor blackColor];
    if([self isHighlighted])
        txtclr = [NSColor whiteColor];
    NSString *colId = [aCol identifier];
    if([colId isEqualToString:@"session"])
    {
        if(![self isHighlighted])
            txtclr = [NSColor blueColor];
        asdict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:NSUnderlineStyleSingle], NSUnderlineStyleAttributeName,txtclr,NSForegroundColorAttributeName,nil];
    }
    else
    {
        asdict = [NSDictionary dictionaryWithObjectsAndKeys:txtclr,NSForegroundColorAttributeName,nil];        
    }
    [[self title] drawInRect:cellFrame withAttributes:asdict];
}


@end
