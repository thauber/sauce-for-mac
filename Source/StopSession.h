//
//  StopSession.h
//  scout
//
//  Created by ackerman dudley on 8/4/12.
//  Copyright (c) 2012 Sauce Labs. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface StopSession : NSObject {
    
    IBOutlet NSPanel *panel;
    IBOutlet NSButton *againChkbox;
    NSMutableDictionary *sdict;
}

- (id)init:(NSMutableDictionary*)adict;
- (IBAction)closeSession:(id)sender;
- (IBAction)keepSession:(id)sender;

@end
