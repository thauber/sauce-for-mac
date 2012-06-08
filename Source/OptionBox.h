//
//  OptionBox.h
//  scout
//
//  Created by ackerman dudley on 6/7/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SessionController;

@interface OptionBox : NSBox
{
    SessionController *sessionCtlr;
}

- (void)setSessionCtlr:(SessionController *)sc;

@end
