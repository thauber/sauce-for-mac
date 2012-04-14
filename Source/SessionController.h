//
//  SessionController.h
//  scout-desktop
//
//  Created by ackerman dudley on 4/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SessionController : NSViewController
{
    int selectedTag;
    NSRect selectedFrame;
    NSView *selectBox;
    NSTextField *url;
    NSBox *box2;
    NSBox *box1;
    NSProgressIndicator *connectIndicator;
    NSTextField *connectIndicatorText;
    NSButton *connectBtn;
}
@property (assign) IBOutlet NSButton *connectBtn;
@property (assign) IBOutlet NSTextField *connectIndicatorText;
@property (assign) IBOutlet NSProgressIndicator *connectIndicator;
@property (assign) IBOutlet NSBox *box1;
@property (assign) IBOutlet NSBox *box2;
@property (assign) IBOutlet NSTextField *url;

- (IBAction)connect:(id)sender;
- (IBAction)cancelConnect: (id)sender;
- (IBAction)selectBrowser:(id)sender;
-(void)connectionSucceeded;
- (void)showError:(NSString *)errStr;


@end
