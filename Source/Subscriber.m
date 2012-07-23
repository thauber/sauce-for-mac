//
//  Subscriber.m
//  scout
//
//  Created by ackerman dudley on 7/19/12.
//  Copyright (c) 2012 Sauce Labs. All rights reserved.
//

#import "Subscriber.h"
#import "ScoutWindowController.h"

@implementation Subscriber
@synthesize panel;
@synthesize firstName;
@synthesize lastName;
@synthesize zipCode;
@synthesize email;
@synthesize cardType;
@synthesize cardNumber;
@synthesize cardCCV;
@synthesize expireMonth;
@synthesize expireYear;
@synthesize subscribeBtn;

- (id)init
{
    self = [super init];
    if(self)
    {
        [NSBundle loadNibNamed:@"subscriber"  owner:self];
        [NSApp beginSheet:panel modalForWindow:[[ScoutWindowController sharedScout] window] modalDelegate:self  didEndSelector:nil   contextInfo:nil];
    }
    return self;
}

-(void)controlTextDidChange:(NSNotification*)aNotification
{
    NSTextView * fldEdtr = [[aNotification userInfo] objectForKey:@"NSFieldEditor"];
    NSString * ss = [[fldEdtr textStorage] string];
    NSInteger len = [ss length];
    if ([aNotification object] == cardCCV) 
    {
        // ccv has changed
        if(len>4)
        {
            NSBeep();
            ss = [ss substringToIndex:4];
            [cardCCV setStringValue:ss];
            return;
        }
        for(NSInteger i=0;i<len;i++)
        {
            NSInteger vv = [ss characterAtIndex:i];
            if(vv<'0' || vv>'9' )     // only digits allowed
            {
                NSBeep();
                ss = [ss substringToIndex:i];
                [cardCCV setStringValue:ss];
                return;
            }
        }
    }
    else if ([aNotification object] == cardNumber)
    {
        // card# has changed
        if(len>19)          // can have 16 digits and 3 dashes
        {
            NSBeep();
            ss = [ss substringToIndex:19];
            [cardNumber setStringValue:ss];
            return;
        }
        for(NSInteger i=0;i<len;i++)
        {
            NSInteger vv = [ss characterAtIndex:i];
            if((vv<48 || vv>57) && vv!=45)      // only digits and dashes allowed
            {
                NSBeep();
                ss = [ss substringToIndex:i];
                [cardNumber setStringValue:ss];
                return;
            }
        }
    }
}

-(void)quitSheet
{
    [NSApp endSheet:panel];
    [panel orderOut:nil];    
}

- (IBAction)doSubscribe:(id)sender
{
    NSLog(@"do subscribe");
}

@end
