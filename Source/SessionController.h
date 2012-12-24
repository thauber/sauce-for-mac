//
//  SessionController.h
//  scout-desktop
//
//  Created by ackerman dudley on 4/2/12.
//  Copyright (c) 2012 __SauceLabs__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define kNumTabs 6

typedef enum {tt_winxp, tt_win7, tt_win8, tt_linux, tt_macios, tt_macosx} ttType;

@interface SessionController : NSObject <NSBrowserDelegate>
{
    ttType curTabIndx;
    NSInteger curNumBrowsers;
    BOOL lastpop1;
    BOOL lastpop2;
    NSInteger sessionIndxs[kNumTabs];
    NSInteger resolutionIndxs[kNumTabs];
    NSTextField *url;
    NSProgressIndicator *connectIndicator;
    NSTextField *connectIndicatorText;
    NSButton *connectBtn;
    NSPanel *panel;
    NSView *view;
    NSButton *defaultBrowser;
    IBOutlet NSBrowser *browserTbl;
    NSArray *configsOS[kNumTabs];         // os/browsers for windows; pointer to appdelegate array
    NSMutableArray *brAStrsOs[kNumTabs];         // browser attributed strings
    NSAttributedString* osAStrs[kNumTabs];       // os attributed strings
}
@property (assign) IBOutlet NSButton *defaultBrowser;
@property (assign) IBOutlet NSPanel *panel;
@property (assign) IBOutlet NSView *view;

@property (assign) IBOutlet NSButton *connectBtn;
@property (assign) IBOutlet NSTextField *connectIndicatorText;
@property (assign) IBOutlet NSProgressIndicator *connectIndicator;
@property (assign) IBOutlet NSTextField *url;

- (IBAction)doBrowserClick:(NSBrowser *)sender;
- (IBAction)doDoubleClick:(id)sender;
- (void)quitSheet;
- (void)terminateApp;
- (void)runSheet;
- (IBAction)connect:(id)sender;
- (IBAction)cancel:(id)sender;
- (void)showError:(NSString *)errStr;
- (IBAction)visitSauce:(id)sender;



@end


