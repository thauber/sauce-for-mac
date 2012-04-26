//
//  BugIngoController.h
//  scout-desktop
//
//  Created by ackerman dudley on 4/23/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface BugInfoController : NSObject
{
    NSTextField *title;
    NSTextField *fromFld;
    NSTextField *toFld;
    NSTextField *description;
    NSPanel *panel;
}
@property (assign) IBOutlet NSPanel *panel;
- (IBAction)submit:(id)sender;
- (IBAction)cancel:(id)sender;
@property (assign) IBOutlet NSTextField *description;
@property (assign) IBOutlet NSTextField *title;
@property (assign) IBOutlet NSTextField *fromFld;
@property (assign) IBOutlet NSTextField *toFld;

- (void)runSheetOnWindow:(NSWindow *)window;

@end