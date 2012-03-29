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
    NSString *user;
    NSString *ukey;
    NSString *secret;       // from saucelabs server
    NSString *jobId;        // from saucelabs server
    NSString *liveId;
    NSString *remaining;
    NSTimer *timer;
}

@property(nonatomic,copy) NSString *user;
@property(nonatomic,copy) NSString *ukey;
@property(nonatomic,copy) NSString *secret;
@property(nonatomic,copy) NSString *jobId;
@property(nonatomic,copy) NSString *liveId;
@property(nonatomic,copy) NSString *remaining;
@property(nonatomic,assign) NSTimer *timer;


+(SaucePreconnect*)sharedPreconnect;

// use user/password to get live_id from server using
// use live_id to get secret and job-id 
- (void)preAuthorize:(NSString*)os browser:(NSString*)browser 
                    browserVersion:(NSString*)version url:(NSString*)url;

// return json with secret/job_id for server connection
- (NSString *)credStr;
-(void)startHeartbeat;
-(void)cancelHeartbeat;
- (BOOL)checkUserLogin:(NSString *)uuser  key:(NSString*)kkey;

@end
