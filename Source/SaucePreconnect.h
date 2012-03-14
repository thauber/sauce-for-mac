//
//  SaucePreconnect.h
//  scout-desktop
//
//  Created by Sauce Labs on 3/12/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SaucePreconnect : NSObject
{
    NSString *secret;       // from saucelabs server
    NSString *jobId;       // from saucelabs server
    NSString *liveId;
    NSMutableData *receivedData;
}

@property(nonatomic,copy) NSString *secret;
@property(nonatomic,copy) NSString *jobId;
@property(nonatomic,copy) NSString *liveId;
@property(nonatomic,retain) NSMutableData *receivedData;

// use user/password to get live_id from server using
// use live_id to get secret and job-id 
- (BOOL)preAuthorize:(NSString*)user key:(NSString*)key  
                  os:(NSString*)os browser:(NSString*)browser browserVersion:(NSString*)version url:(NSString*)url;

// return json with secret/job_id for server connection
- (NSString *)json_arg;
@end
