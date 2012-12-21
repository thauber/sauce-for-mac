//
//  BugIngoController.h
//  scout-desktop
//
//  Created by ackerman dudley on 4/23/12.
//  Copyright (c) 2012 __SauceLabs__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface BugInfoController : NSObject
{
    NSTextField *title;
    NSTextView *description;
    NSPanel *panel;
    BOOL bSnap;      // we're doing a snapshot, not a bug
    NSTextField *header;
}
@property (assign) IBOutlet NSTextField *header;
@property (assign) IBOutlet NSPanel *panel;
- (IBAction)submit:(id)sender;
- (IBAction)cancel:(id)sender;
@property (assign) IBOutlet NSTextView *description;
@property (assign) IBOutlet NSTextField *title;

- (id)init;
- (void)runSheetOnWindow:(NSWindow *)window;

@end
