//
//  TunnelController.h
//  scout
//
//  Created by ackerman dudley on 5/11/12.
//  Copyright (c) 2012 __SauceLabs__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class StopConnect;

@interface TunnelController : NSObject
{    
    NSPanel *panel;
    NSButton *closeButton;
    NSButton *hideButton;
    NSTextView *infoTV;
    BOOL hiddenDisplay;
    NSTask *ftask;
    NSFileHandle *fhand;
    NSPipe *fpipe;
    IBOutlet NSProgressIndicator *indicator;    
    IBOutlet NSTextField *connectLabel;
    NSButton *emailLog;
    StopConnect *stopCtlr;
}
@property (assign) IBOutlet NSButton *emailLog;
@property (assign) IBOutlet NSPanel *panel;
@property (assign) IBOutlet NSButton *closeButton;
@property (assign) IBOutlet NSButton *hideButton;
@property (assign) IBOutlet NSTextView *infoTV;
@property (assign) BOOL hiddenDisplay;
@property(nonatomic, retain) NSTask *ftask;
@property(nonatomic, retain) NSFileHandle *fhand;
@property(nonatomic, retain) NSPipe *fpipe;
@property (retain) StopConnect *stopCtlr;

- (id)init;
- (void)terminate;
- (void)runSheetOnWindow:(NSWindow *)window;
- (IBAction)doClose:(id)sender;
- (IBAction)doHide:(id)sender;
- (IBAction)doEmailLog:(id)sender;
-(void)doTunnel;
-(void)tunnelData: (NSNotification *) notif;
-(void)endTunnel: (NSNotification *) notif;
@end
