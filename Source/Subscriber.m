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
@synthesize nextMonthLbl;
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

- (id)init:(NSInteger)type
{
    self = [super init];
    if(self)
    {
        NSString *nibname;
        if(type==0)
            nibname = @"subscribe3";
        else if(type==1)
            nibname = @"subscribe5";
        else
            NSLog(@"bad subscribe type");

        
        [NSBundle loadNibNamed:nibname  owner:self];
        
        // make string for next month
        NSDateComponents *components = [[[NSDateComponents alloc] init] autorelease];
        components.month = 7;
        NSDate *oneMonthFromNow = [[NSCalendar currentCalendar] dateByAddingComponents:components toDate:[NSDate date] options:0];
        NSDateFormatter *df = [[[NSDateFormatter alloc] init] autorelease];
        [df setDateFormat:@"MMMM"]; // Full month
        NSString *monthStr = [df stringFromDate:oneMonthFromNow];
        NSString *msg = [NSString stringWithFormat:@"Wait until %@",monthStr];
        [nextMonthLbl setStringValue:msg];
        
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
        if(len>16)          // can have 16 digits
        {
            NSBeep();
            ss = [ss substringToIndex:19];
            [cardNumber setStringValue:ss];
            return;
        }
        for(NSInteger i=0;i<len;i++)
        {
            NSInteger vv = [ss characterAtIndex:i];
            if(vv<'0' || vv>'9')      // only digits allowed
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
    [self quitSheet];
    NSLog(@"do subscribe");
}

- (IBAction)viewSite:(id)sender {
}

- (IBAction)contactSauce:(id)sender {
}

- (IBAction)cancel:(id)sender {
}

@end
