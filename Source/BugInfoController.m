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

@implementation BugInfoController
@synthesize panel;
@synthesize description;
@synthesize title;
@synthesize toFld;

-(id)init
{
    if (self = [super init]) {
        [NSBundle loadNibNamed:@"BugInfo" owner:self];
    }
    return self;
}

- (void)runSheetOnWindow:(NSWindow *)window
{
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
