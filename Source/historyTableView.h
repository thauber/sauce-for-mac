//
//  historyTableView.h
//  scout
//
//  Created by ackerman dudley on 8/21/12.
//  Copyright (c) 2012 Sauce Labs. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class HistoryViewController;

@interface historyTableView : NSTableView
{
    HistoryViewController *vwCtlr;
}
-(void)mouseDown:(NSEvent *)event;
-(void)setVwCtlr:(HistoryViewController*)histVCtlr;

@end
