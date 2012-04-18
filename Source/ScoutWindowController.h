//
//  WindowController.h
//  PSMTabBarControl
//
//  Created by John Pannell on 4/6/06.
//  Copyright 2006 Positive Spin Media. All rights reserved.
//  modified by RDA for SauceLabs 2012.
//

#import <Cocoa/Cocoa.h>

typedef enum { login,options,session } tabType;

@class PSMTabBarControl;


@interface ScoutWindowController : NSWindowController <NSToolbarDelegate> {
	IBOutlet NSTabView					*tabView;
	IBOutlet PSMTabBarControl			*tabBar;
    IBOutlet NSTextField *statusMessage;
    IBOutlet NSSegmentedControl *playstop;
    IBOutlet NSSegmentedControl *bugcamera;
    IBOutlet NSTextField *timeRemainingStat;
    IBOutlet NSTextField *osbrowser;
    IBOutlet NSTextField *userStat;
}

@property (assign)IBOutlet NSTextField *timeRemainingStat;
@property (assign)IBOutlet NSTextField *userStat;
@property (assign)IBOutlet NSTextField *osbrowser;

+(ScoutWindowController*)sharedScout;

- (IBAction)doPlayStop:(id)sender;
- (IBAction)doBugCamera:(id)sender;
- (IBAction)newSession:(id)sender;

// UI
- (void)addNewTab:(tabType)type  view:(NSView*)view; 
- (IBAction)closeTab:(id)sender;
- (void)setTabLabel:(NSString*)lbl;

- (PSMTabBarControl *)tabBar;

// delegate
- (void)tabView:(NSTabView *)aTabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem;
- (BOOL)tabView:(NSTabView *)aTabView shouldCloseTabViewItem:(NSTabViewItem *)tabViewItem;
- (void)tabView:(NSTabView *)aTabView didCloseTabViewItem:(NSTabViewItem *)tabViewItem;

@end
