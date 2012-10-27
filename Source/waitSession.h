//
//  waitSession.h
//  scout
//
//  Created by Sauce Labs on 10/26/12.
//  Copyright (c) 2012 Sauce Labs. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface waitSession : NSObject
{
    NSPanel *panel;
    NSTextField *waitText;
}
@property (assign) IBOutlet NSTextField *waitText;
- (id)init:(NSInteger)minutes;
- (IBAction)keepWaiting:(id)sender;
- (IBAction)visitSauceLabs:(id)sender;

@end
