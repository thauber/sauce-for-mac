//
//  historyTableView.m
//  scout
//
//  Created by ackerman dudley on 8/21/12.
//  Copyright (c) 2012 Sauce Labs. All rights reserved.
//

#import "historyTableView.h"
#import "HistoryViewController.h"

@implementation historyTableView
@synthesize vwCtlr;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

// for click in 'session' column, bring up browser to server jobs page
-(void)mouseDown:(NSEvent *)event
{
    int row = [self rowAtPoint:[self convertPoint:[event locationInWindow] fromView:nil]];
    if(row==-1)
        return;
    NSTableColumn *aCol = [[self tableColumns] 
                        objectAtIndex:[self columnAtPoint:
                                       [self convertPoint:[event  locationInWindow]
                                                 fromView:nil]]];
    NSString *colId = [aCol identifier];
    if([colId isEqualToString:@"session"])
        [vwCtlr browseJobs:row];

    [super mouseDown:event];         
}
                                                                                         
@end
