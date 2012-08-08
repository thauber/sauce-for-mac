//
//  StopSession.h
//  scout
//
//  Created by ackerman dudley on 8/4/12.
//  Copyright (c) 2012 Sauce Labs. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface StopConnect : NSObject
{
    
    IBOutlet NSPanel *panel;
    IBOutlet NSButton *againChkbox;
}

- (IBAction)closeConnect:(id)sender;
- (IBAction)keepConnect:(id)sender;
- (void)endPanel;

@end
