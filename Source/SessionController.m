//
//  SessionController.m
//  scout-desktop
//
//  Created by ackerman dudley on 4/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "SessionController.h"
#import "SaucePreconnect.h"

@implementation SessionController

@synthesize url;

- (IBAction)selectBrowser:(NSImageView *)sender 
{
    selectedTag = [sender tag];
    NSRect frame = [sender frame];
    if(!selectBox)
    {
        // create box
        selectBox = [[NSView alloc ] initWithFrame:frame];
        [[[self window] contentView] addSubview:selectBox];
        CALayer *viewLayer = [CALayer layer];
        [viewLayer setBackgroundColor:CGColorCreateGenericRGB(0.0, 0.0, 0.0, 0.4)]; //RGB plus Alpha Channel
        [selectBox setWantsLayer:YES]; // view's backing store is using a Core Animation Layer
        [selectBox setLayer:viewLayer];
    }
    else 
    {
        // move selected box over this sender
        [selectBox setFrame:frame];
    }
    
}

-(IBAction)Connect:(id)sender 
{
    NSString *os = [self selected:@"os"];
    NSString *browser = [self selected:@"browser"];
    NSString *version = [self selected:@"version"];
    NSString *urlstr = [self.url stringValue];
    
    [[SaucePreconnect sharedPreconnect] preAuthorize:os browser:browser 
                                      browserVersion:version url:urlstr];
}

- (NSString *)selected:(NSString*)type      // 'browser', 'version' or 'os'
{
    NSString *os=@"";
    NSString *browser=@"";
    NSString *version=@"";
    
    switch(selectedTag)
    {
        case 101: os = @"Windows 2003"; browser = @"iexplore"; version = @"6"; break;
        case 102: os = @"Windows 2003"; browser = @"iexplore"; version = @"7"; break;
        case 103: os = @"Windows 2003"; browser = @"iexplore"; version = @"8"; break;
        case 104: os = @"Windows 2008"; browser = @"iexplore"; version = @"9"; break;
    }
    if([type isEqualToString:@"os"])
        return os;
    if([type isEqualToString:@"browser"])        
        return browser;
    if([type isEqualToString:@"version"]) 
        return version;
    return @"";    
}


@end
