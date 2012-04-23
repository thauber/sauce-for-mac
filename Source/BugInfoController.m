//
//  BugInfoController.m
//  scout-desktop
//
//  Created by ackerman dudley on 4/23/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "BugInfoController.h"
#import "ScoutWindowController.h"

@implementation BugInfoController
@synthesize panel;
@synthesize description;
@synthesize title;

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
    [self retain];
}

- (IBAction)submit:(id)sender 
{
    [[ScoutWindowController sharedScout] submitBug:[title stringValue] desc:[description stringValue]];
    [NSApp endSheet:panel];
    [panel orderOut:nil];
}

- (IBAction)cancel:(id)sender 
{
    [NSApp endSheet:panel];
    [panel orderOut:nil];
}
@end
