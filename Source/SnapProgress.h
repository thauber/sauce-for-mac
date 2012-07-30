//
//  SnapProgress.h
//  scout
//
//  Created by ackerman dudley on 5/27/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SnapProgress : NSObject 
{
    NSPanel *panel;
    NSTextField *takingTxt;
    NSTextField *urlLabel;
    NSTextField *url;
    NSProgressIndicator *indicator;
    NSButton *cancelButton;
    NSButton *viewSnapshotButton;
    BOOL okEnableView;
    NSTextField *availableLbl;
}
@property (assign) IBOutlet NSTextField *availableLbl;
@property (assign) IBOutlet NSPanel *panel;
@property (assign) IBOutlet NSTextField *takingTxt;
@property (assign) IBOutlet NSTextField *urlLabel;
@property (assign) IBOutlet NSTextField *url;
@property (assign) IBOutlet NSProgressIndicator *indicator;
@property (assign) IBOutlet NSButton *cancelButton;
@property (assign) IBOutlet NSButton *viewSnapshotButton;
@property (assign) BOOL okEnableView;

- (IBAction)OkButton:(id)sender;
- (IBAction)viewSnapshot:(id)sender;
- (void)setServerURL:(NSString*)surl;

@end
