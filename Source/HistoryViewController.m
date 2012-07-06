//
//  HistoryView.m
//  scout
//
//  Created by ackerman dudley on 7/4/12.
//  Copyright (c) 2012 Sauce Labs. All rights reserved.
//

#import "HistoryViewController.h"

@implementation HistoryViewController

- (id)init
{
    self = [super init];
    if(self)
    {
        [NSBundle loadNibNamed:@"history"  owner:self];
        rowArr = [[NSMutableArray arrayWithCapacity:0] retain];
    }
    return self;
}

- (void)addRow:(NSArray*)rarr 
{
    [rowArr addObject:rarr];
    [tableView reloadData];
}

- (void)updateRuntime:(NSView*)view
{
    NSMutableArray *rarr;
    
    NSInteger num = [rowArr count];
    for(NSInteger i=0; i < num; i++)
    {
        rarr = [rowArr objectAtIndex:i];
        if([rarr objectAtIndex:7] == view)
        {
            time_t start = [[rarr objectAtIndex:6] longValue];   // start time of session
            int hrs, mins, secs;
            time_t rawtime, tt;
            time(&rawtime);
            tt = rawtime - start;
            hrs = tt/3600;
            mins =  (tt-(hrs*3600))/60;
            secs = tt-(hrs*3600)-(60*mins);
            NSString *timeStr = [NSString stringWithFormat:@"%02d:%02d:%02d",hrs,mins,secs];

            [rarr replaceObjectAtIndex:5 withObject:timeStr];
            NSIndexSet *rind = [NSIndexSet indexSetWithIndex:i];
            NSIndexSet *cind = [NSIndexSet indexSetWithIndex:5];
            [tableView reloadDataForRowIndexes:rind columnIndexes:cind];
            return;
        }
    }    
    
}

- (void)updateActive:(NSView*)view      // assumes we can only deactivate an active session
{
    NSMutableArray *rarr;
    
    NSInteger num = [rowArr count];
    for(NSInteger i=0; i < num; i++)
    {
        rarr = [rowArr objectAtIndex:i];
        if([rarr objectAtIndex:7] == view)
        {
            [rarr replaceObjectAtIndex:0 withObject:@"x"];
            NSIndexSet *rind = [NSIndexSet indexSetWithIndex:i];
            NSIndexSet *cind = [NSIndexSet indexSetWithIndex:0];
            [tableView reloadDataForRowIndexes:rind columnIndexes:cind];
            return;
        }
    }    
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [rowArr count]; 
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    NSCell *cell = [aTableColumn dataCell];
    
    NSArray *rr = [rowArr objectAtIndex:rowIndex];
    NSString *colId = [aTableColumn identifier];
    if ([colId isEqualToString:@"active"])      // index=0 ->active
        return [rr objectAtIndex:0];
    if ([colId isEqualToString:@"url"])         // index=1 -> url
        return [rr objectAtIndex:1];
    if ([colId isEqualToString:@"osbrver"])     // index=2 -> os/browser/version
        return [rr objectAtIndex:2];
    if ([colId isEqualToString:@"bugs"])        // index=3 -> bugs; TODO: should be a popup with selectable(?) urls
        return [rr objectAtIndex:3];
    if ([colId isEqualToString:@"start_time"])  // index=4 -> start time
    {
        [cell setAlignment:NSCenterTextAlignment];
        return [rr objectAtIndex:4];
    }
    if ([colId isEqualToString:@"run_time"])    // index=7 -> run time
    {
        [cell setAlignment:NSCenterTextAlignment];
        return [rr objectAtIndex:5];
    }
    
    return @"";
}

@end
