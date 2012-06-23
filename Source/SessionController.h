//
//  SessionController.h
//  scout-desktop
//
//  Created by ackerman dudley on 4/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define kNumTrackItems 17
#define kNumTabs 4

@class OptionBox;

enum TabType {tt_windows, tt_linux, tt_apple, tt_mobile};

@interface SessionController : NSObject
{
    NSInteger curTabIndx;
    NSInteger sessionIndx;
    NSInteger hoverIndx;
    NSMutableArray *selectedFrames;     // each tab its own selected browser
    NSView *selectBox;
    NSRect hoverFrame;
    NSView *hoverBox;
    NSTextField *url;
    OptionBox *boxWindows;
    OptionBox *boxLinux;
    OptionBox *curBox;
    NSArray *optionBoxen;
    NSProgressIndicator *connectIndicator;
    NSTextField *connectIndicatorText;
    NSButton *connectBtn;
    NSPanel *panel;
    NSView *view;
    NSButton *cancelBtn;
    NSButton *defaultBrowser;
    id trarr[kNumTrackItems];      // tracking rect tags
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
    NSTabView *osTabs;
}
@property (assign) IBOutlet NSTabView *osTabs;
@property (assign) IBOutlet NSButton *defaultBrowser;
@property (assign) IBOutlet NSPanel *panel;
@property (assign) IBOutlet NSView *view;
@property (assign) IBOutlet NSButton *cancelBtn;

@property (assign) IBOutlet NSButton *connectBtn;
@property (assign) IBOutlet NSTextField *connectIndicatorText;
@property (assign) IBOutlet NSProgressIndicator *connectIndicator;
@property (assign) IBOutlet NSTextField *url;
@property (assign) IBOutlet OptionBox *boxWindows;
@property (assign) IBOutlet OptionBox *boxLinux;
- (IBAction)performClose:(id)sender;
- (void)quitSheet;
- (void)terminateApp;
- (void)runSheet;
- (void)handleMouseEntered:(id)tn;
- (void)handleMouseExited;
- (void) doubleClick;
- (IBAction)connect:(id)sender;
- (void)startConnecting;
- (IBAction)selectBrowser:(id)sender;
- (void)connectionSucceeded;
- (void)showError:(NSString *)errStr;
- (NSInteger)hoverIndx;


@end


