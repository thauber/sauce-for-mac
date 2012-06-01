//
//  SessionController.h
//  scout-desktop
//
//  Created by ackerman dudley on 4/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SessionController : NSObject
{
    int selectedTag;
    NSRect selectedFrame;
    NSView *selectBox;
    NSTextField *url;
    NSBox *box2;
    NSProgressIndicator *connectIndicator;
    NSTextField *connectIndicatorText;
    NSButton *connectBtn;
    NSPanel *panel;
    NSView *view;
    NSButton *cancelBtn;
    NSButton *defaultBrowser;
}
@property (assign) IBOutlet NSButton *defaultBrowser;
@property (assign) IBOutlet NSPanel *panel;
@property (assign) IBOutlet NSView *view;
@property (assign) IBOutlet NSButton *cancelBtn;

@property (assign) IBOutlet NSButton *connectBtn;
@property (assign) IBOutlet NSTextField *connectIndicatorText;
@property (assign) IBOutlet NSProgressIndicator *connectIndicator;
@property (assign) IBOutlet NSBox *box2;
@property (assign) IBOutlet NSTextField *url;
- (IBAction)performClose:(id)sender;
- (void)quitSheet;
- (void)terminateApp;
- (void)runSheet;
- (IBAction)connect:(id)sender;
- (void)startConnecting;
- (IBAction)selectBrowser:(id)sender;
- (void)connectionSucceeded;
- (void)showError:(NSString *)errStr;


@end
