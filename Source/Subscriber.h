//
//  Subscriber.h
//  scout
//
//  Created by ackerman dudley on 7/19/12.
//  Copyright (c) 2012 Sauce Labs. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface Subscriber : NSObject {
    NSPanel *panel;
    NSTextField *firstName;
    NSTextField *lastName;
    NSTextField *zipCode;
    NSTextField *email;
    NSPopUpButton *cardType;
    NSTextField *cardNumber;
    NSTextField *cardCCV;
    NSPopUpButton *expireMonth;
    NSPopUpButton *expireYear;
    NSButton *subscribeBtn;
    NSTextField *nextMonthLbl;
}
@property (assign) IBOutlet NSTextField *nextMonthLbl;
@property (assign) IBOutlet NSPanel *panel;
@property (assign) IBOutlet NSTextField *firstName;
@property (assign) IBOutlet NSTextField *lastName;
@property (assign) IBOutlet NSTextField *zipCode;
@property (assign) IBOutlet NSTextField *email;
@property (assign) IBOutlet NSPopUpButton *cardType;
@property (assign) IBOutlet NSTextField *cardNumber;
@property (assign) IBOutlet NSTextField *cardCCV;
@property (assign) IBOutlet NSPopUpButton *expireMonth;
@property (assign) IBOutlet NSPopUpButton *expireYear;
@property (assign) IBOutlet NSButton *subscribeBtn;
- (IBAction)doSubscribe:(id)sender;
- (void)quitSheet;

@end
