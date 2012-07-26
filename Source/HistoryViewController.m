//
//  HistoryView.m
//  scout
//
//  Created by ackerman dudley on 7/4/12.
//  Copyright (c) 2012 Sauce Labs. All rights reserved.
//

#import "ScoutWindowController.h"
#import "SnapProgress.h"
#import "HistoryViewController.h"
#import "SaucePreconnect.h"
#import "AppDelegate.h"

@implementation HistoryViewController
@synthesize popbtn;

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
    NSString *colId = [aTableColumn identifier];
    if ([colId isEqualToString:@"bugs"])                // index=3 -> bugs;
        [self setObjectValue:aTableView newValue:anObject row:rowIndex];
}

- (void)setObjectValue:(NSTableView *)aTableView newValue:(id)anObject row:(NSInteger)rowIndex
{
    NSNumber *rindex = [NSNumber numberWithInteger:rowIndex];
    NSView *view = [indxDict objectForKey:rindex];      // get view given row
    NSArray *rr = [rowDict objectForKey:[NSNumber numberWithInteger:(NSInteger)view]];  // get row info
    NSMutableArray *barr = [rr objectAtIndex:3];        // array of bug urls
    [barr replaceObjectAtIndex:0 withObject:anObject];      // put index of selected item at index=0
    NSInteger popindx = [anObject longValue];               // selected item
    if(popindx > 0)       // popup index zero is the popup title
    {
        SnapProgress *sp = [[SnapProgress alloc] init];
        [[ScoutWindowController sharedScout] setSnapProgress:sp];
        NSString *surl = [barr objectAtIndex: popindx+1];
        BOOL isActive =  [[rr objectAtIndex:0] isEqualToString:@"A"];
        if(isActive)
            [sp setOkEnableView:NO];         // snapshot isn't available while job is active
        else    // job is not active, so check if snapshot is available
            [sp setOkEnableView:[self isAvailableSnap:surl]];
        [sp setServerURL:surl];                 // give snapshot sheet the url        
    }    
}


// https://<user>:<acctkey>@saucelabs.com/rest/<username>/jobs/<job_id>/results/<filename>
- (BOOL)isAvailableSnap:(NSString*)surl
{
    NSArray *urlArr = [surl componentsSeparatedByString:@"/"];
    NSString *fname = [urlArr lastObject];
    NSString *jobid = [urlArr objectAtIndex:[urlArr count]-2];
    NSString *user = [[SaucePreconnect sharedPreconnect] user];
    NSString *akey = [[SaucePreconnect sharedPreconnect] ukey];
    NSString *farg = [NSString stringWithFormat:@"curl https://%@:%@@saucelabs.com/rest/%@/jobs/%@/results/%@",user, akey,user,jobid, fname];

    NSTask *ftask = [[NSTask alloc] init];
    NSPipe *fpipe = [NSPipe pipe];
    [ftask setStandardOutput:fpipe];
    [ftask setLaunchPath:@"/bin/bash"];
    [ftask setArguments:[NSArray arrayWithObjects:@"-c", farg, nil]];
    [ftask launch];		// fetch live id
    NSFileHandle *fhand = [fpipe fileHandleForReading];        
    NSData *data = [fhand availableData];		 
    if([data length] > 10)
    {
        [ftask release];
        return YES;
    }
    [ftask release];
    return NO;
}


- (IBAction)doPopSelect:(id)sender 
{
    return; // not able to cause reselect of previous selected popup item
// want to catch a re-selection of an item so we can show the snapprogress dialog again
//  no good - can't get index of item that is being selected, here
    NSTableView *tv = sender;
    NSInteger row = [tv clickedRow];
    NSIndexSet *rind = [NSIndexSet indexSetWithIndex:row];
    NSIndexSet *cind = [NSIndexSet indexSetWithIndex:3];
    [tv reloadDataForRowIndexes:rind columnIndexes:cind];
//    NSPopUpButtonCell *pop = [tcol dataCellForRow:row];
//    NSInteger sel = [pop indexOfSelectedItem];
//    NSLog(@"select:%ld",sel);
//    [self setObjectValue:sender newValue:[NSNumber numberWithInteger:0] row:[(NSTableView*)sender clickedRow]];


}

- (IBAction)doNewSession:(id)sender
{
    [[NSApp delegate] showOptionsDlg:self];
    
}

@end
