//
//  demoConnectController.h
//  scout
//
//  Created by saucelabs on 12/28/12.
//  Copyright (c) 2012 Sauce Labs. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SessionController;

@interface demoConnectController : NSObject
{
    IBOutlet NSPanel *panel;    
}
- (id)init:(SessionController*)sessionCtlr;
- (IBAction)visitDemoConnect:(id)sender;
- (IBAction)demoConnectBack:(id)sender;

@end
