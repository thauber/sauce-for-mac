//
//  HistoryView.m
//  scout
//
//  Created by ackerman dudley on 7/4/12.
//  Copyright (c) 2012 Sauce Labs. All rights reserved.
//

#import "ScoutWindowController.h"
#import "HistoryViewController.h"
#import "SaucePreconnect.h"
#import "AppDelegate.h"
#import "historyTableView.h"

@implementation HistoryViewController

- (id)init
{
    self = [super init];
    if(self)
    {
        [NSBundle loadNibNamed:@"history"  owner:self];
        rowDict  = [[NSMutableDictionary dictionaryWithCapacity:0] retain];     // row info
        indxDict = [[NSMutableDictionary dictionaryWithCapacity:0] retain];     // index for a view 
        [tableView setVwCtlr:self];
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
    time_t start = [[rarr objectAtIndex:5] longValue];   // start time of session
    int hrs, mins, secs;
    time_t rawtime, tt;
    time(&rawtime);
    tt = rawtime - start;
    hrs = tt/3600;
    mins =  (tt-(hrs*3600))/60;
    secs = tt-(hrs*3600)-(60*mins);
    NSString *timeStr = [NSString stringWithFormat:@"%02d:%02d:%02d",hrs,mins,secs];

    [rarr replaceObjectAtIndex:4 withObject:timeStr];       // set runtime
    NSInteger index = [[rarr objectAtIndex:7] longValue];   // row in index=7
    NSIndexSet *rind = [NSIndexSet indexSetWithIndex:index];
    NSIndexSet *cind = [NSIndexSet indexSetWithIndex:4];    // runtime into column=4
    [tableView reloadDataForRowIndexes:rind columnIndexes:cind];
}

- (void)updateActive:(NSView*)view      // assumes we can only deactivate an active session
{
    NSMutableArray *rarr = [rowDict objectForKey:[NSNumber numberWithInteger:(NSInteger)view]];    
    [rarr replaceObjectAtIndex:0 withObject:@"Finished"];
    NSInteger index = [[rarr objectAtIndex:5] longValue];
    NSIndexSet *rind = [NSIndexSet indexSetWithIndex:index];
    NSIndexSet *cind = [NSIndexSet indexSetWithIndex:0];
    [tableView reloadDataForRowIndexes:rind columnIndexes:cind];
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
    if ([colId isEqualToString:@"status"])      // index=0 ->active
        return [rr objectAtIndex:0];
    if ([colId isEqualToString:@"session"])         // index=1 -> url
        return [rr objectAtIndex:1];
    if ([colId isEqualToString:@"osbrver"])     // index=2 -> os/browser/version
        return [rr objectAtIndex:2];
    if ([colId isEqualToString:@"start_time"])  // index=3 -> start time
    {
        [cell setAlignment:NSCenterTextAlignment];
        return [rr objectAtIndex:3];
    }
    if ([colId isEqualToString:@"run_time"])    // index=4 -> run time
    {
        [cell setAlignment:NSCenterTextAlignment];
        return [rr objectAtIndex:4];
    }
    
    return @"";
}

- (void)browseJobs:(NSInteger)row
{
    NSNumber *rindex = [NSNumber numberWithInteger:row];
    NSView *view = [indxDict objectForKey:rindex];
    NSArray *rr = [rowDict objectForKey:[NSNumber numberWithInteger:(NSInteger)view]];
    NSString *jobId = [rr objectAtIndex:6];
    NSString *urlStr = [NSString stringWithFormat:@"http://saucelabs.com/jobs/%@",jobId];
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlStr]];
}


- (IBAction)doNewSession:(id)sender
{
    [[NSApp delegate] showOptionsDlg:self];
    
}

@end
