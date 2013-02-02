//
//  historyTFCell.m
//  scout
//
//  Created by ackerman dudley on 8/30/12.
//  Copyright (c) 2012 Sauce Labs. All rights reserved.
//

#import "historyTFCell.h"
#import "historyTableView.h"

@implementation historyTFCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    NSTableView *tv = (NSTableView*)controlView;
    int indx = [tv columnAtPoint:[tv convertPoint:cellFrame.origin fromView:nil]];
    if(indx == -1)
    {
        NSLog(@"history draw");
        return;
    }
    NSTableColumn *aCol = [[tv tableColumns] objectAtIndex:indx];

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
        if([colId isEqualToString:@"status"])
        {
            NSInteger aRow = [tv rowAtPoint:cellFrame.origin];
            NSColor *color;
            NSString *status = [[(historyTableView*)tv vwCtlr] tableView:tv objectValueForTableColumn:aCol row:aRow];
            if([status isEqualToString:@"Active"])
                color = [NSColor colorWithCalibratedRed:106/251.0f green:1.0f blue:146/255.0f alpha:1.0f];
            else
                color = [NSColor colorWithCalibratedRed:195/255.0f green:1.0f blue:184/255.0f alpha:1.0f];
                
            
            cellFrame.size.width += 5;
            [color set];
            NSRectFill(cellFrame);
            txtclr = [NSColor grayColor];
        }
        asdict = [NSDictionary dictionaryWithObjectsAndKeys:txtclr,NSForegroundColorAttributeName,nil];        
    }
    [[self title] drawInRect:cellFrame withAttributes:asdict];
}


@end
