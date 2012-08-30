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
    NSString *colId = [aCol identifier];

    // control hilite color
    NSColor *color;
    if([self isHighlighted])
        color = [NSColor colorWithCalibratedRed:102/255.0f green:1.0f blue:153/255.0f alpha:1.0f];
    else
        color = [self backgroundColor];
    cellFrame.size.width += 5;
    [color set];
    NSRectFill(cellFrame);
    
    // underline the url in the 2nd column
    NSDictionary *asdict = nil;
    if([colId isEqualToString:@"session"])
    {
        asdict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:NSUnderlineStyleSingle], NSUnderlineStyleAttributeName,[NSColor blueColor],NSForegroundColorAttributeName,nil];
    }
    [[self title] drawInRect:cellFrame withAttributes:asdict];
}


@end
