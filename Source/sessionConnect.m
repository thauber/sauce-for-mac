//
//  sessionConnect.m
//  scout
//
//  Created by ackerman dudley on 8/31/12.
//  Copyright (c) 2012 Sauce Labs. All rights reserved.
//

#import "sessionConnect.h"
#import "AppDelegate.h"
#import "ScoutWindowController.h"

@interface sessionConnect ()

@end

@implementation sessionConnect
@synthesize connectionIndicator;
@synthesize osImage;
@synthesize browserImage;
@synthesize sdict;

- (id)initWithDict:(NSMutableDictionary*)adict
{
    self = [super init];
    if(self)
    {
        [NSBundle loadNibNamed:@"sessionConnect"  owner:self];
        
        sdict = adict;
        NSString *os = [sdict objectForKey:@"os"];
        NSString *browser = [sdict objectForKey:@"browser"];
        // set image for os
        NSString *path;
        NSString *pStr;
        // set OS image
        if([os hasPrefix:@"Windows"])
            pStr = @"win28";
        else if([os hasPrefix:@"Linux"])
            pStr = @"lin28";
        else if([os hasPrefix:@"Mac"])
            pStr = @"apple28";

        path = [[NSBundle mainBundle] pathForResource:pStr ofType:@"png"];
        [osImage setImage:[[[NSImage alloc] initByReferencingFile:path] autorelease]];

        // set Browser image
        if([browser hasPrefix:@"ie"] || [browser hasPrefix:@"in"])             // internet explorer
            pStr = @"ie28";
        else if([browser hasPrefix:@"fi"])        // firefox
            pStr = @"firefox28";
        else if([browser hasPrefix:@"sa"])        // safari
            pStr = @"safari28";
        else if([browser hasPrefix:@"op"])        // opera
            pStr = @"opera28";
        else if([browser hasPrefix:@"go"])        // google chrome
            pStr = @"chrome28";
        else if([browser hasPrefix:@"an"])        // android
            pStr = @"an28";
        else if([browser hasPrefix:@"ip"])        // ios mobile
            pStr = @"ios-mobile";
                
        path = [[NSBundle mainBundle] pathForResource:pStr ofType:@"png"];
        [browserImage setImage:[[[NSImage alloc] initByReferencingFile:path] autorelease]];


        [connectionIndicator startAnimation:self];
    }
    return self;
}

- (IBAction)cancel:(id)sender
{
    [sdict setObject:@"User cancelled" forKey:@"errorString"];
    [[NSApp delegate] cancelOptionsConnect:sdict];
}

@end
