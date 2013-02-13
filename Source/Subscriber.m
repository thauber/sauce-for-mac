//
//  Subscriber.m
//  scout
//
//  Created by ackerman dudley on 7/19/12.
//  Copyright (c) 2012 Sauce Labs. All rights reserved.
//

#import "Subscriber.h"
#import "ScoutWindowController.h"
#import "AppDelegate.h"

@implementation Subscriber
@synthesize restartTxt;
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
        NSString *nibname=nil;
        BOOL bDemo = [[NSApp delegate] isDemoAccount];
        
        if(INAPPSTORE)              // appstore version
        {
            if(bDemo)
            {
                if(type==0)
                    nibname = @"subscriber-3_demo";      // out of minutes
                else if(type==1)
                    nibname = @"subscriber-5_demo";      // out of tabs
            }
            else
            {
                if(type==0)
                    nibname = @"subscriber-3";      // out of minutes
                else if(type==1)
                    nibname = @"subscriber-5";      // out of tabs
            }
        }
        else
        {
            if(type==0)             // non-appstore version
                nibname = @"subscriber";        // out of minutes
            else if(type==1)
                nibname = @"subscriber-4";      // out of tabs
            else if(type==2)
                nibname = @"subscriber-2";      // subscribe (from menu)
        }

        if(!nibname)
        {
            NSLog(@"bad subscriber type:%ld",type);
            return nil;
        }
        
        [NSBundle loadNibNamed:nibname  owner:self];
        
        // make string for next month
        if(!bDemo && (type==1 || type==2 || type==4))
        {
            NSDateComponents *components = [[[NSDateComponents alloc] init] autorelease];
            components.month = 7;
            NSDate *oneMonthFromNow = [[NSCalendar currentCalendar] dateByAddingComponents:components toDate:[NSDate date] options:0];
            NSDateFormatter *df = [[[NSDateFormatter alloc] init] autorelease];
            [df setDateFormat:@"MMMM"]; // Full month
            NSString *monthStr = [df stringFromDate:oneMonthFromNow];
            NSString *msg = [NSString stringWithFormat:@"Wait until %@",monthStr];
            [nextMonthLbl setStringValue:msg];
        }
        else if(bDemo)
        {
            NSInteger minutes = [[NSApp delegate] demoCheckTime];
            NSString *txt = [NSString stringWithFormat:@"Restart in %ld minutes",minutes];
            [restartTxt setStringValue:txt];
        }
        
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
}

- (IBAction)viewSite:(id)sender 
{
    NSString *str;
    if(INAPPSTORE)
        str = @"https://saucelabs.com/signup?s4m";
    else
        str = @"http://saucelabs.com";
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:str]];
    [self doSubscribe:self];
}

- (IBAction)contactSauce:(id)sender 
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"mailto:support@saucelabs.com"]];
    [self doSubscribe:self];
}

- (IBAction)cancel:(id)sender 
{
    [self quitSheet];
    [[NSApp delegate] showLoginDlg:nil];
}

@end
