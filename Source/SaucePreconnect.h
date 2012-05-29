//
//  SaucePreconnect.h
//  scout-desktop
//
//  Created by Sauce Labs on 3/12/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SnapProgress.h"

@class TunnelController;

@interface SaucePreconnect : NSObject
{
    NSString *user;
    NSString *ukey;
    NSString *os;
    NSString *browser;
    NSString *browserVersion;
    NSString *urlStr;
    NSString *secret;       // from saucelabs server
    NSString *jobId;        // from saucelabs server
    NSString *liveId;
    NSMutableArray *credArr;   // array of dictionaries with session,secret,jobid,and liveid
    NSString *userNew;
    NSString *passNew;
    NSString *emailNew;
    NSTimer *timer;
    NSTimer *authTimer;
    NSString *errStr;
    BOOL cancelled;         // yes -> stop the presses!
    int delayedSession;     // 1->adding 2->done adding (but need to abort if in heartbeat loop
}

@property(nonatomic,copy) NSString *user;
@property(nonatomic,copy) NSString *ukey;
@property(nonatomic,copy) NSString *os;
@property(nonatomic,copy) NSString *browser;
@property(nonatomic,copy) NSString *browserVersion;
@property(nonatomic,copy) NSString *urlStr;
@property(nonatomic,copy) NSString *secret;
@property(nonatomic,copy) NSString *jobId;
@property(nonatomic,copy) NSString *liveId;
@property(nonatomic,copy) NSString *userNew;
@property(nonatomic,copy) NSString *passNew;
@property(nonatomic,copy) NSString *emailNew;
@property(nonatomic,retain) NSTimer *timer;
@property(nonatomic,retain) NSTimer *authTimer;
@property(nonatomic,copy) NSString *errStr;
@property(assign)BOOL cancelled;

+(SaucePreconnect*)sharedPreconnect;

// use user/password to get live_id from server using
// use live_id to get secret and job-id 
- (void)preAuthorize:(id)param;
-(NSString *)jsonVal:(NSString *)json key:(NSString *)key;
- (void)setOptions:(NSString*)os browser:(NSString*)browser 
                    browserVersion:(NSString*)version url:(NSString*)url;

// return json with secret/job_id for server connection
- (NSString *)credStr;
-(void)cancelPreAuthorize:(NSTimer*)tm;
-(void)sessionClosed:(id)session;
-(NSDictionary *)sessionInfo:(id)view;
-(void)setvmsize:(NSSize)size;
-(void)setSessionInfo:(id)session view:(id)view;
-(NSString*)remainingTimeStr:(int)remaining;
-(void)startHeartbeat;
-(void)cancelHeartbeat;
- (BOOL)checkUserLogin:(NSString *)uuser  key:(NSString*)kkey;
- (void)signupNew:(NSString*)uuserNew passNew:(NSString*)upassNew 
        emailNew:(NSString*)uemailNew;
- (void)postSnapshotBug:(NSString *)snapName title:(NSString *)title desc:(NSString *)desc;
- (void)snapshotBug:(NSString *)title desc:(NSString *)desc;


@end
