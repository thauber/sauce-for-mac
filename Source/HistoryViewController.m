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
        rowDict  = [[NSMutableDictionary dictionaryWithCapacity:0] retain];     // row info
        indxDict = [[NSMutableDictionary dictionaryWithCapacity:0] retain];     // index for a view        
    }
    return self;
}

- (void)addRow:(NSView*)view rowArr:(NSMutableArray*)rarr 
{
    NSNumber *index = [NSNumber numberWithInteger:[rowDict count]];
    [indxDict setObject:view forKey:index];     // will return a view given a row#
    [rarr addObject:index];     // so we know what row the info is in;    index=7
    [rowDict setObject:rarr forKey:[NSNumber numberWithInteger:(NSInteger)view]];       // will return an info array given a view
    [tableView reloadData];
}

- (void)updateRuntime:(NSView*)view
{
    NSMutableArray *rarr = [rowDict objectForKey:[NSNumber numberWithInteger:(NSInteger)view]];
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
    NSInteger index = [[rarr objectAtIndex:7] longValue];
    NSIndexSet *rind = [NSIndexSet indexSetWithIndex:index];
    NSIndexSet *cind = [NSIndexSet indexSetWithIndex:5];
    [tableView reloadDataForRowIndexes:rind columnIndexes:cind];
}

- (void)updateActive:(NSView*)view      // assumes we can only deactivate an active session
{
    NSMutableArray *rarr = [rowDict objectForKey:[NSNumber numberWithInteger:(NSInteger)view]];    
    [rarr replaceObjectAtIndex:0 withObject:@"x"];
    NSInteger index = [[rarr objectAtIndex:7] longValue];
    NSIndexSet *rind = [NSIndexSet indexSetWithIndex:index];
    NSIndexSet *cind = [NSIndexSet indexSetWithIndex:0];
    [tableView reloadDataForRowIndexes:rind columnIndexes:cind];
}

- (void)addSnapbug:(NSView*)view bug:(NSString*)bugUrl
{
    NSMutableArray *rarr = [rowDict objectForKey:[NSNumber numberWithInteger:(NSInteger)view]];    
    NSMutableArray *barr = [rarr objectAtIndex:3];   // array of bug urls
    [barr addObject:bugUrl];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [rowDict count]; 
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{    
    NSCell *cell = [aTableColumn dataCell];
    NSNumber *rindex = [NSNumber numberWithInteger:rowIndex];
    NSView *view = [indxDict objectForKey:rindex];
    NSArray *rr = [rowDict objectForKey:[NSNumber numberWithInteger:(NSInteger)view]];
    NSString *colId = [aTableColumn identifier];
    if ([colId isEqualToString:@"active"])      // index=0 ->active
        return [rr objectAtIndex:0];
    if ([colId isEqualToString:@"url"])         // index=1 -> url
        return [rr objectAtIndex:1];
    if ([colId isEqualToString:@"osbrver"])     // index=2 -> os/browser/version
        return [rr objectAtIndex:2];
    if ([colId isEqualToString:@"bugs"])        // index=3 -> bugs; a popup with bug/snapshot urls
    {
        NSPopUpButtonCell *popcell = (NSPopUpButtonCell *)cell;
        [popcell removeAllItems];
        NSArray *barr = [rr objectAtIndex:3];   // array of bug urls
        NSInteger count = [barr count]-1;
        for(NSInteger i=1; i <= count; i++)
        {
            [popcell addItemWithTitle:[barr objectAtIndex:i]]; 
        }
        return [NSNumber numberWithInt:[[barr objectAtIndex:0] intValue]];   // return selected popup item
    }
    if ([colId isEqualToString:@"start_time"])  // index=4 -> start time
    {
        [cell setAlignment:NSCenterTextAlignment];
        return [rr objectAtIndex:4];
    }
    if ([colId isEqualToString:@"run_time"])    // index=5 -> run time
    {
        [cell setAlignment:NSCenterTextAlignment];
        return [rr objectAtIndex:5];
    }
    
    return @"";
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    NSNumber *rindex = [NSNumber numberWithInteger:rowIndex];
    NSView *view = [indxDict objectForKey:rindex];
    NSArray *rr = [rowDict objectForKey:[NSNumber numberWithInteger:(NSInteger)view]];
    NSString *colId = [aTableColumn identifier];
    NSMutableArray *barr = [rr objectAtIndex:3];   // array of bug urls
    if ([colId isEqualToString:@"bugs"])        // index=3 -> bugs; TODO: should be a popup with selectable(?) urls
    {
        [barr replaceObjectAtIndex:0 withObject:anObject]; 
    }
}

@end
