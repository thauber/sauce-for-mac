//
//  SessionController.h
//  scout-desktop
//
//  Created by ackerman dudley on 4/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define kNumTabs 4

@class OptionBox;

enum TabType {tt_windows, tt_linux, tt_apple, tt_mobile};

@interface SessionController : NSObject <NSBrowserDelegate>
{
    enum TabType curTabIndx;
    NSInteger curNumBrowsers;
    NSInteger sessionIndxs[kNumTabs];
    NSInteger hoverIndx;
    NSView *selectBox;
    NSRect hoverFrame;
    NSView *hoverBox;
    NSTextField *url;
    NSProgressIndicator *connectIndicator;
    NSTextField *connectIndicatorText;
    NSButton *connectBtn;
    NSPanel *panel;
    NSView *view;
    NSButton *defaultBrowser;
//    id trarrWin[kNumWindowsTrackers];       // tracking rect areas
//    id trarrLnx[kNumLinuxTrackers];         // tracking rect areas
    IBOutlet NSBrowser *browserTbl;
    NSMutableArray *configWindows;          // os/browsers for windows
    NSMutableArray *configLinux;            // os/browsers for linux
    NSMutableArray *configOSX;              // os/browsers for osx
    NSMutableArray *brAStrsWindows;         // browser attributed strings
    NSMutableArray *brAStrsLinux;
    NSMutableArray *brAStrsApple;
    NSMutableArray *brAStrsMobile;    
    NSAttributedString* osAStrs[4];    
}
@property (assign) IBOutlet NSButton *defaultBrowser;
@property (assign) IBOutlet NSPanel *panel;
@property (assign) IBOutlet NSView *view;

@property (assign) IBOutlet NSButton *connectBtn;
@property (assign) IBOutlet NSTextField *connectIndicatorText;
@property (assign) IBOutlet NSProgressIndicator *connectIndicator;
@property (assign) IBOutlet NSTextField *url;
- (IBAction)doBrowserClick:(NSBrowser *)sender;
- (IBAction)performClose:(id)sender;
- (IBAction)doDoubleClick:(id)sender;
- (void)quitSheet;
- (void)terminateApp;
- (void)runSheet;
//- (void)handleMouseEntered:(id)tn;
//- (void)handleMouseExited;
//- (void) doubleClick;
- (IBAction)connect:(id)sender;
- (void)startConnecting;
//- (IBAction)selectBrowser:(id)sender;
- (void)connectionSucceeded;
- (void)showError:(NSString *)errStr;
- (NSInteger)hoverIndx;


@end


