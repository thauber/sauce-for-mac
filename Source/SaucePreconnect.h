//
//  SaucePreconnect.h
//  scout-desktop
//
//  Created by Sauce Labs on 3/12/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SnapProgress.h"

extern NSString *kSauceLabsDomain;
@class TunnelController;

@interface SaucePreconnect : NSObject
{
    NSString *user;
    NSString *ukey;
    NSMutableArray *credArr;   // array of dictionaries with session,secret,jobid,and liveid
    NSTimer *timer;
    int delayedSession;     // 1->adding 2->done adding (but need to abort if in heartbeat loop
    BOOL internetOk;
}

@property(nonatomic,copy) NSString *user;
@property(nonatomic,copy) NSString *ukey;
@property(nonatomic,retain) NSTimer *timer;
@property(assign)BOOL internetOk;

+(SaucePreconnect*)sharedPreconnect;

// use user/password to get live_id from server using
// use live_id to get secret and job-id 
- (void)preAuthorize:(NSMutableDictionary*)sdict;
-(NSString *)jsonVal:(NSString *)json key:(NSString *)key;
- (NSMutableDictionary*)setOptions:(NSString*)os browser:(NSString*)browser 
                    browserVersion:(NSString*)version url:(NSString*)url;
-(void)cancelPreAuthorize:(id)tm;
-(void)sessionClosed:(NSMutableDictionary*)sdict;
-(NSMutableDictionary*)sessionInfo:(id)view;
-(void)setvmsize:(NSSize)size;
-(NSString*)remainingTimeStr:(int)remaining;
-(void)startHeartbeat;
-(void)cancelHeartbeat:(id)tm;
- (NSString*)checkUserLogin:(NSString *)uuser  key:(NSString*)kkey;
- (NSString*)signupNew:(NSString*)uuserNew passNew:(NSString*)upassNew 
        emailNew:(NSString*)uemailNew;
- (NSString*)postSnapshotBug:(NSString *)snapName title:(NSString *)title desc:(NSString *)desc;
- (NSString*)snapshotBug:(NSString *)title desc:(NSString *)desc;
- (NSString*)checkAccountOk;


@end
