//
//  BugInfoController.m
//  scout-desktop
//
//  Created by ackerman dudley on 4/23/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "BugInfoController.h"
#import "ScoutWindowController.h"
#import "AppDelegate.h"
#import "Session.h"

@implementation BugInfoController
@synthesize panel;
@synthesize description;
@synthesize title;
@synthesize toFld;

-(id)init:(BOOL)snap
{
    if (self = [super init]) 
    {
        [NSBundle loadNibNamed:@"BugInfo" owner:self];
        bSnap = snap;
    }
    return self;
}

- (void)runSheetOnWindow:(NSWindow *)window
{
    if(bSnap)
    {        
        int hrs, mins;
        time_t rawtime;
        struct tm *ptm;    
        time(&rawtime);    
        ptm = localtime(&rawtime);
        int yr = ptm->tm_year+1900;
        int mon = ptm->tm_mon + 1;
        int day = ptm->tm_mday;
        NSString *dateStr = [NSString stringWithFormat:@"Date:%d-%2d-%2d",yr,mon,day];
        hrs = ptm->tm_hour;
        mins = ptm->tm_min;
        NSString *timeStr = [NSString stringWithFormat:@"Time:%d:%d",hrs,mins];
        
        NSView *view = [[[ScoutWindowController sharedScout] curSession] scrollView];
        NSDictionary *sdict = [[SaucePreconnect sharedPreconnect] sessionInfo:view];
        NSString *browserStr = [sdict valueForKey:@"browser"];
        browserStr = [NSString stringWithFormat:@"Browser:%@",browserStr];
        NSString *osStr = [sdict valueForKey:@"os"];
        osStr = [NSString stringWithFormat:@"OS:%@",osStr];
        NSString *urlStr = [sdict valueForKey:@"url"];
        urlStr = [NSString stringWithFormat:@"Start URL:%@",urlStr];
        NSString *user = [sdict valueForKey:@"user"];
        NSString *userStr = [NSString stringWithFormat:@"User:%@",user];
        [description setStringValue:[NSString stringWithFormat:@"%@\n%@\n%@\n%@\n%@",dateStr,timeStr,osStr,urlStr,userStr]];
        [title setStringValue:[NSString stringWithFormat:@"%@-snapshot-%@",dateStr,user]];
        
    }
    [NSApp beginSheet:panel modalForWindow:window modalDelegate:self
       didEndSelector:nil   contextInfo:nil];
}

- (IBAction)submit:(id)sender 
{
    [NSApp endSheet:panel];
    [panel orderOut:nil];
    [[ScoutWindowController sharedScout] performSelectorOnMainThread:@selector(submitBug) withObject:nil waitUntilDone:NO]; 
}

- (IBAction)cancel:(id)sender 
{
    [NSApp endSheet:panel];
    [panel orderOut:nil];
    [[NSApp delegate] setBugCtrlr:nil];
    [[NSApp delegate] performSelectorOnMainThread:@selector(showOptionsIfNoTabs) withObject:nil waitUntilDone:NO ];
}
@end
