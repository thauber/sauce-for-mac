//
//  SaucePreconnect.m
//  scout-desktop
//
//  Created by Sauce Labs on 3/12/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "SaucePreconnect.h"
#import "SBJson.h"
#import "RFBConnectionManager.h"

@implementation SaucePreconnect

@synthesize user;
@synthesize ukey;
@synthesize secret;
@synthesize jobId;
@synthesize liveId;
@synthesize remaining;
@synthesize timer;

static SaucePreconnect* _sharedPreconnect = nil;

+(SaucePreconnect*)sharedPreconnect
{
	@synchronized([SaucePreconnect class])
	{
		if (!_sharedPreconnect)
			[[self alloc] init];
        
		return _sharedPreconnect;
	}
    
	return nil;
}

+(id)alloc
{
	@synchronized([SaucePreconnect class])
	{
		NSAssert(_sharedPreconnect == nil, @"Attempted to allocate a second instance of a singleton.");
		_sharedPreconnect = [super alloc];
		return _sharedPreconnect;
	}
    
	return nil;
}

// use user/password and users selections to get live_id from server
- (NSString *)preAuthorize:(NSString*)os browser:(NSString*)browser 
                    browserVersion:(NSString*)browserVersion url:(NSString*)url
{    
    NSString *farg = [NSString stringWithFormat:@"curl -X POST 'https://%@:%@@saucelabs.com/rest/v1/users/%@/scout' -H 'Content-Type: application/json' -d '{\"os\":\"%@\", \"browser\":\"%@\", \"browser-version\":\"%@\", \"url\":\"%@\"}'", self.user, self.ukey, self.user, os, browser, browserVersion, url];
    
    while(1)    // TODO: progress display with cancel button
    {
        NSTask *ftask = [[NSTask alloc] init];
        NSPipe *fpipe = [NSPipe pipe];
        [ftask setStandardOutput:fpipe];
        [ftask setLaunchPath:@"/bin/bash"];
        [ftask setArguments:[NSArray arrayWithObjects:@"-c", farg, nil]];
        [ftask launch];		// fetch live id
        [ftask waitUntilExit];
        if([ftask terminationStatus])
        {
            NSLog(@"failed NSTask");
            return @"Failed to send user options to server";
        }
        else
        {
            NSFileHandle *fhand = [fpipe fileHandleForReading];
            
            NSData *data = [fhand readDataToEndOfFile];		 
            NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSDictionary *jsonDict = [jsonString JSONValue];
            self.liveId = [jsonDict objectForKey:@"live-id"];
            if(self.liveId.length)
                break;
            else 
            {
                return @"Failed to retrieve live-id";
            }
        }
    }
    return [self curlGetauth];
 
}



// return json object for vnc connection
- (NSString *)credStr
{
    NSString *js = [[NSString stringWithFormat:@"{\"job-id\":\"%@\",\"secret\":\"%@\"}\n",self.jobId,self.secret]retain];
    return js;
}


// poll til we get secret/jobid
-(NSString *)curlGetauth
{
	NSString *farg = [NSString stringWithFormat:@"curl 'https://%@:%@@saucelabs.com/scout/live/%@/status?secret&'", self.user, self.ukey, self.liveId ];

    while(1)    // TODO: progress display with cancel button
    {
        NSTask *ftask = [[NSTask alloc] init];
        NSPipe *fpipe = [NSPipe pipe];
        [ftask setStandardOutput:fpipe];
        [ftask setLaunchPath:@"/bin/bash"];
        [ftask setArguments:[NSArray arrayWithObjects:@"-c", farg, nil]];
        [ftask launch];		// fetch job-id and secret server
        [ftask waitUntilExit];
        if([ftask terminationStatus])
        {
            NSLog(@"failed NSTask");
            return @"Failed to request job-id";
        }
        else
        {
            NSFileHandle *fhand = [fpipe fileHandleForReading];
            
            NSData *data = [fhand readDataToEndOfFile];		 
            NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSDictionary *jsonDict = [jsonString JSONValue];
            self.secret = [jsonDict objectForKey:@"video-secret"];
            self.jobId  = [jsonDict objectForKey:@"job-id"];
            if(secret.length)
            {
                [[RFBConnectionManager sharedManager] connectToServer];
                return @"";     //  got job-id ok
            }
        }
    }
}

-(void)startHeartbeat       // 1 minute is ok; at 2 minutes, server times out
{
    self.timer = [NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(heartbeat:) userInfo:nil repeats:YES];
}

-(void)cancelHeartbeat
{
    self.timer = nil;
}

- (void)heartbeat:(NSTimer*)tm
{    
	NSString *farg = [NSString stringWithFormat:@"curl 'https://saucelabs.com/scout/live/%@/status?auth_username=%@&auth_access_key=%@'", self.liveId, self.user, self.ukey];
    
    while(1)    
    {
        NSTask *ftask = [[NSTask alloc] init];
        NSPipe *fpipe = [NSPipe pipe];
        [ftask setStandardOutput:fpipe];
        [ftask setLaunchPath:@"/bin/bash"];
        [ftask setArguments:[NSArray arrayWithObjects:@"-c", farg, nil]];
        [ftask launch];		// fetch job-id and secret server
        [ftask waitUntilExit];
        if([ftask terminationStatus])
        {
            NSLog(@"failed NSTask");    // TODO: tell user
            break;
        }
        else
        {
            NSFileHandle *fhand = [fpipe fileHandleForReading];
            
            NSData *data = [fhand readDataToEndOfFile];		 
            NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSDictionary *jsonDict = [jsonString JSONValue];
            NSString *status = [jsonDict objectForKey:@"status"];
            int val = [[jsonDict valueForKey:@"remaining-time"] intValue];  // doesn't work just asking for NSString?
            if([status isEqualToString:@"in progress"])
            {
                self.remaining  = [NSString stringWithFormat:@"%d",val];                
                break;                
            }
            else
            {
                [self cancelHeartbeat];
                NSLog(@"Heartbeat doesn't say 'in progress'");    // TODO: tell user
                break;
            }
        }
    }
}

- (BOOL)checkUserLogin:(NSString *)uuser  key:(NSString*)kkey
{
    NSString *farg = [NSString stringWithFormat:@"curl 'https://%@:%@@saucelabs.com/rest/v1/%@/jobs'", uuser, kkey, uuser];
    
    NSTask *ftask = [[NSTask alloc] init];
    NSPipe *fpipe = [NSPipe pipe];
    [ftask setStandardOutput:fpipe];
    [ftask setLaunchPath:@"/bin/bash"];
    [ftask setArguments:[NSArray arrayWithObjects:@"-c", farg, nil]];
    [ftask launch];		// fetch live id
    [ftask waitUntilExit];
    if([ftask terminationStatus])
    {
        NSLog(@"failed NSTask");
    }
    else
    {
        NSFileHandle *fhand = [fpipe fileHandleForReading];
        
        NSData *data = [fhand readDataToEndOfFile];		 
        NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSRange range = [jsonString rangeOfString:@"error"];
        if(!range.length)
        {
            self.user = uuser;
            self.ukey = kkey;
            return YES;
        }
    }
    return NO;
}

- (NSString*)signupNew:(NSString*)userNew password:(NSString*)passNew email:(NSString*)emailNew
{
    NSString *farg = [NSString stringWithFormat:@"curl -X POST http://saucelabs.com/rest/v1/users -H 'Content-Type: application/json' -d '{\"username\":\"%@\", \"password\":\"%@\",\"name\":\"\",\"email\":\"%@\",\"token\":\"0E44EF6E-B170-4CA0-8264-78FD9E49E5CD\"}'",userNew,passNew,emailNew];
                      
    while(1)
    {
        NSTask *ftask = [[NSTask alloc] init];
        NSPipe *fpipe = [NSPipe pipe];
        [ftask setStandardOutput:fpipe];
        [ftask setLaunchPath:@"/bin/bash"];
        [ftask setArguments:[NSArray arrayWithObjects:@"-c", farg, nil]];
        [ftask launch];		// fetch live id
        [ftask waitUntilExit];
        if([ftask terminationStatus])
        {
            NSLog(@"failed NSTask");
            break;
        }
        else
        {
            NSFileHandle *fhand = [fpipe fileHandleForReading];
            
            NSData *data = [fhand readDataToEndOfFile];		 
            NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSDictionary *jsonDict = [jsonString JSONValue];
            NSString *akey = [jsonDict objectForKey:@"access_key"];
            if(akey.length)
            {
                return akey;
            }
        }
    }
    return @"";
    
}

@end
