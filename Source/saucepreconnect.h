//
//  saucepreconnect.h
//  saucevnc
//
//  Created by Sauce Labs on 3/12/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface saucepreconnect : NSObject
{
    NSString *secret;
    NSString *jobid;
}
- (void)collectSauceData;

@end
