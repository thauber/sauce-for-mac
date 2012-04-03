//
//  SessionController.h
//  scout-desktop
//
//  Created by ackerman dudley on 4/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SessionController : NSWindowController
{
    int selectedTag;
    NSView *selectBox;
    NSTextField *url;
}
@property (assign) IBOutlet NSTextField *url;

- (IBAction)Connect:(id)sender;
- (IBAction)selectBrowser:(NSImageView *)sender;

@end
