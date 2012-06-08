//
//  SessionController.h
//  scout-desktop
//
//  Created by ackerman dudley on 4/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define kNumTrackItems 20

@class OptionBox;

@interface SessionController : NSObject
{
    int selectedTag;
    NSRect selectedFrame;
    NSRect hoverFrame;
    NSView *selectBox;
    NSView *hoverBox;
    NSTextField *url;
    OptionBox *box2;
    NSProgressIndicator *connectIndicator;
    NSTextField *connectIndicatorText;
    NSButton *connectBtn;
    NSPanel *panel;
    NSView *view;
    NSButton *cancelBtn;
    NSButton *defaultBrowser;
    int trarr[kNumTrackItems];      // tracking rect tags
    id barr[kNumTrackItems];        // buttons
    IBOutlet NSImageView *b0;
    IBOutlet NSImageView *b1;
    IBOutlet NSImageView *b2;
    IBOutlet NSImageView *b3;
    IBOutlet NSImageView *b4;
    IBOutlet NSImageView *b5;
    IBOutlet NSImageView *b6;
    IBOutlet NSImageView *b7;
    IBOutlet NSImageView *b8;
    IBOutlet NSImageView *b9;
    IBOutlet NSImageView *b10;
    IBOutlet NSImageView *b11;
    IBOutlet NSImageView *b12;
    IBOutlet NSImageView *b13;
    IBOutlet NSImageView *b14;
    IBOutlet NSImageView *b15;
    IBOutlet NSImageView *b16;
    IBOutlet NSImageView *b17;
    IBOutlet NSImageView *b18;
    IBOutlet NSImageView *b19;
}
@property (assign) IBOutlet NSButton *defaultBrowser;
@property (assign) IBOutlet NSPanel *panel;
@property (assign) IBOutlet NSView *view;
@property (assign) IBOutlet NSButton *cancelBtn;

@property (assign) IBOutlet NSButton *connectBtn;
@property (assign) IBOutlet NSTextField *connectIndicatorText;
@property (assign) IBOutlet NSProgressIndicator *connectIndicator;
@property (assign) IBOutlet OptionBox *box2;
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


