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
#import "ScoutWindowController.h"
#import "Session.h"

@implementation SaucePreconnect

@synthesize user;
@synthesize ukey;
@synthesize os;
@synthesize browser;
@synthesize browserVersion;
@synthesize urlStr;
@synthesize secret;
@synthesize jobId;
@synthesize liveId;
@synthesize userNew;
@synthesize passNew;
@synthesize emailNew;

@synthesize remaining;
@synthesize timer;
@synthesize errStr;
@synthesize cancelled;

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

- (void)setOptions:(NSString*)uos browser:(NSString*)ubrowser 
    browserVersion:(NSString*)ubrowserVersion url:(NSString*)uurlStr
{
    os = uos;       
    browser = ubrowser;
    browserVersion = ubrowserVersion;
    urlStr = uurlStr;
}

// use user/password and users selections to get live_id from server
- (void)preAuthorize:(id)param
{    
    NSString *farg = [NSString stringWithFormat:@"curl -X POST 'https://%@:%@@saucelabs.com/rest/v1/users/%@/scout' -H 'Content-Type: application/json' -d '{\"os\":\"%@\", \"browser\":\"%@\", \"browser-version\":\"%@\", \"url\":\"%@\"}'", self.user, self.ukey, self.user, self.os, self.browser, self.browserVersion, self.urlStr];
    self.errStr = @"";
//    NSLog(@"farg:%@",farg);
    
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
            self.errStr = @"Failed to send user options to server";
            return;
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
                self.errStr =@"Failed to retrieve live-id";
                return;
            }
        }
    }
    [self curlGetauth];
    // call error method of app which calls error method of sessionController
    if(self.errStr.length)
    {
        [[RFBConnectionManager sharedManager] 
         performSelectorOnMainThread:@selector(errOnConnect)   
         withObject:nil  waitUntilDone:NO];
    }
}



// return json object for vnc connection
- (NSString *)credStr
{
    NSString *js = [[NSString stringWithFormat:@"{\"job-id\":\"%@\",\"secret\":\"%@\"}\n",self.jobId,self.secret]retain];
    return js;
}


// poll til we get secret/jobid
-(void)curlGetauth
{
	NSString *farg = [NSString stringWithFormat:@"curl 'https://%@:%@@saucelabs.com/scout/live/%@/status?secret&'", self.user, self.ukey, self.liveId ];

    while(1)    // use live-id to get job-id
    {
        if(cancelled)
        {
            self.errStr = @"Connecting was Cancelled";
            return;
        }
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
            self.errStr =  @"Failed to request job-id";
            return;
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
                self.errStr = @"";     //  got job-id ok
                [[RFBConnectionManager sharedManager] performSelectorOnMainThread:@selector(connectToServer)   withObject:nil  waitUntilDone:NO];
                return;
            }
            
        }
    }
}

// remove session being close from heartbeat array
-(void)sessionClosed:(id)connection
{
	int len = [credArr count];
    NSDictionary *sdict;
    
    for(int i=0;i<len;i++)
    {
        sdict = [credArr objectAtIndex:i];
        if([sdict objectForKey:@"connection"] == connection)
        {
            [credArr removeObjectAtIndex:i];
            return;
        }
    }
}

// return get info for a view; also used to determine if tab has an active session
-(NSDictionary *)sessionInfo:(id)view
{
	int len = [credArr count];
    NSDictionary *sdict;
    
    for(int i=0;i<len;i++)
    {
        sdict = [credArr objectAtIndex:i];
        if([sdict objectForKey:@"view"] == view)
        {
            return sdict;
        }
    }
    return nil;
}

-(void)setvmsize:(NSSize)size
{
    NSMutableDictionary *sdict = [credArr lastObject];
    NSString *str = [NSString stringWithFormat:@"%.0fx%.0f",size.width,size.height];
    [sdict setValue:str forKey:@"size"];
    [[[ScoutWindowController sharedScout] vmsize] setStringValue:str];
}

// array for each session/tab - 
//  session for closing session 
//  liveId for heartbeat
//  osbrowserversion string for setting status when switching tabs
//  view to know which tab is becoming active
//  user, authkey, job-id, os, browser, and browserversion taken from most recent preauthorization
-(void)setSessionInfo:(id)connection view:(id)view
{
    NSString *osbvStr = [NSString stringWithFormat:@"%@/%@ %@",os,browser,browserVersion];
    [[[ScoutWindowController sharedScout] osbrowser] setStringValue:osbvStr];
    
    NSMutableDictionary *sdict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                    connection,@"connection", view, @"view", liveId, @"liveId",
                    user, @"user", ukey, @"ukey", jobId, @"jobId",
                    osbvStr, @"osbv", urlStr, @"url", 
                    os, @"os", browser, @"browser", browserVersion, @"browserVersion", nil];
    
    if(!credArr)
    {
        credArr = [[[NSMutableArray alloc] init] retain];
    }
    [credArr addObject:sdict];
}

-(NSString *)remainingTimeStr
{
    if(!self.remaining)
        return @"";
    
    int hr = self.remaining / 3600;
    int min = (self.remaining % 3600)/60;
    int sec = self.remaining % 60;

    NSString *hrstr, *minstr, *secstr;

    if(hr)
        hrstr = [NSString stringWithFormat:@"%d",hr];
    else
        hrstr = @"";        
    if(min<10)
        minstr = [NSString stringWithFormat:@"0%d",min];
    else
        minstr = [NSString stringWithFormat:@"%d",min];
    if(sec<10)
        secstr = [NSString stringWithFormat:@"0%d",sec];
    else
        secstr = [NSString stringWithFormat:@"%d",sec];
    NSString *str = [NSString stringWithFormat:@"%@:%@:%@",hrstr,minstr,secstr];
    return str;
}

-(void)startHeartbeat       // 1 minute is ok; at 2 minutes, server times out
{    
    if(!self.timer)    
        self.timer = [NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(heartbeat:) userInfo:nil repeats:YES];
}

-(void)cancelHeartbeat
{
    if(![credArr count])    // only stop heartbeat if no sessions are active
    {
        cancelled = YES;
        [self.timer invalidate];
        self.timer = nil;
    }
}

- (void)heartbeat:(NSTimer*)tm
{    
	NSEnumerator *credEnumerator = [credArr objectEnumerator];
    NSDictionary *sdict;
    
    if(![credArr count])
    {
        [self cancelHeartbeat];
        return;        
    }
    
	while ( sdict = (NSDictionary*)[credEnumerator nextObject] )
    {
        NSString *aliveid = [sdict objectForKey:@"liveId"];
                             
        NSString *farg = [NSString stringWithFormat:@"curl 'https://saucelabs.com/scout/live/%@/status?auth_username=%@&auth_access_key=%@'", aliveid, self.user, self.ukey];
        
        while(1)    
        {
            if(cancelled)
                return;

            NSTask *ftask = [[NSTask alloc] init];
            NSPipe *fpipe = [NSPipe pipe];
            [ftask setStandardOutput:fpipe];
            [ftask setLaunchPath:@"/bin/bash"];
            [ftask setArguments:[NSArray arrayWithObjects:@"-c", farg, nil]];
            [ftask launch];		// fetch job-id and secret server
            [ftask waitUntilExit];
            if([ftask terminationStatus])
            {
                self.errStr = @"failed NSTask in heartbeat";
                [self cancelHeartbeat];
                break;
            }
            else
            {
                NSFileHandle *fhand = [fpipe fileHandleForReading];
                
                NSData *data = [fhand readDataToEndOfFile];		 
                NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSDictionary *jsonDict = [jsonString JSONValue];
                NSString *status = [jsonDict objectForKey:@"status"];
                if([status isEqualToString:@"in progress"])
                {
                    id ssn = [sdict objectForKey:@"connection"];
                    Session *session = [[ScoutWindowController sharedScout] curSession];
                    if(ssn == [session connection])
                    {
                        self.remaining = [[jsonDict valueForKey:@"remaining-time"] intValue];  
                        // show in status
                        NSString *str = [self remainingTimeStr];
                        NSTextField *tf = [[ScoutWindowController sharedScout] timeRemainingStat];
                        [tf setStringValue:str];
                        tf = [[ScoutWindowController sharedScout] timeRemainingMsg];
                        str = [NSString stringWithFormat:@"%@ rem.",str];
                        [tf setStringValue:str];
                    }
                    
                    break;                
                }
                else
                {
                    self.errStr = @"Heartbeat doesn't say 'in progress'";
                    [self cancelHeartbeat];
                    break;
                }
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
        self.errStr = @"Failed NSTask in checkUserLogin";
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
        else 
        {
            self.errStr = @"Failed server authentication";
        }
    }
    return NO;
}

- (void)signupNew:(NSString*)uuserNew passNew:(NSString*)upassNew 
         emailNew:(NSString*)uemailNew
{    
    self.userNew = uuserNew;
    self.passNew = upassNew;
    self.emailNew = uemailNew;
    
    NSString *farg = [NSString stringWithFormat:@"curl -X POST http://saucelabs.com/rest/v1/users -H 'Content-Type: application/json' -d '{\"username\":\"%@\", \"password\":\"%@\",\"name\":\"\",\"email\":\"%@\",\"token\":\"0E44EF6E-B170-4CA0-8264-78FD9E49E5CD\"}'",self.userNew, self.passNew, self.emailNew];
     
    self.errStr = @"";
    while(1)
    {
        if(cancelled)
        {
            self.errStr = @"Connecting was Cancelled";
            break;
        }

        NSTask *ftask = [[NSTask alloc] init];
        NSPipe *fpipe = [NSPipe pipe];
        [ftask setStandardOutput:fpipe];
        [ftask setLaunchPath:@"/bin/bash"];
        [ftask setArguments:[NSArray arrayWithObjects:@"-c", farg, nil]];
        [ftask launch];		// fetch live id
        [ftask waitUntilExit];
        if([ftask terminationStatus])
        {
            self.errStr = @"Failed NSTask in signupNew";
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
                self.user = self.userNew;
                self.ukey = akey;
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setObject:self.user  forKey:kUsername];
                [defaults setObject:self.ukey  forKey:kAccountkey];
                [NSApp performSelectorOnMainThread:@selector(newUserAuthorized:)   
                                        withObject:nil  waitUntilDone:NO];
                break;
            }
        }
    }    
}

- (void)postSnapshotBug:(id)view snapName:(NSString *)snapName  
               title:(NSString *)title desc:(NSString *)desc
{    
    NSDictionary *sdict = [self sessionInfo:view];
    NSString *aliveid = [sdict objectForKey:@"liveId"];
    NSString *auser = [sdict objectForKey:@"user"];
    NSString *akey = [sdict objectForKey:@"ukey"];


    NSString *farg = [NSString stringWithFormat:@"curl 'https://%@:%@@saucelabs.com/scout/live/%@/reportbug?&ssname=%@&title=%@&description=%@'", auser, akey, aliveid, snapName, title, desc];
    
    self.errStr = @"";
    while(1)
    {
        if(cancelled)
        {
            self.errStr = @"Post snapshotbug was cancelled";
            break;
        }
        
        NSTask *ftask = [[NSTask alloc] init];
        NSPipe *fpipe = [NSPipe pipe];
        [ftask setStandardOutput:fpipe];
        [ftask setLaunchPath:@"/bin/bash"];
        [ftask setArguments:[NSArray arrayWithObjects:@"-c", farg, nil]];
        [ftask launch];		// fetch live id
        [ftask waitUntilExit];
        if([ftask terminationStatus])
        {
            self.errStr = @"Failed NSTask in postSnapshotBug";
            break;
        }
        else
        {
            NSFileHandle *fhand = [fpipe fileHandleForReading];
            
            NSData *data = [fhand readDataToEndOfFile];		 
            NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSDictionary *jsonDict = [jsonString JSONValue];
            NSString *snapId = [jsonDict objectForKey:@"c"];
            if(snapId)
            {
                NSLog(@"got snap id:%@",snapId);
            }
            else {
                self.errStr = @"Failed to get snapshot id";
            }
            break;
        }
    }        
}

- (void)snapshotBug:(id)view  title:(NSString *)title desc:(NSString *)desc
{
    NSDictionary *sdict = [self sessionInfo:view];
    NSString *aliveid = [sdict objectForKey:@"liveId"];
    NSString *auser = [sdict objectForKey:@"user"];
    NSString *akey = [sdict objectForKey:@"ukey"];
    NSString *ajobid = [sdict objectForKey:@"jobId"];
    
    NSString *farg = [NSString stringWithFormat:@"curl 'https://%@:%@@saucelabs.com/scout/live/%@/sendcommand?&1=getScreenshotName&sessionId=%@&cmd=captureScreenshot'", 
                      auser, akey, aliveid, ajobid];

    self.errStr = @"";
    while(1)
    {
        if(cancelled)
        {
            self.errStr = @"SnapshotBug was Cancelled";
            break;
        }
        
        NSTask *ftask = [[NSTask alloc] init];
        NSPipe *fpipe = [NSPipe pipe];
        [ftask setStandardOutput:fpipe];
        [ftask setLaunchPath:@"/bin/bash"];
        [ftask setArguments:[NSArray arrayWithObjects:@"-c", farg, nil]];
        [ftask launch];		// fetch live id
        [ftask waitUntilExit];
        if([ftask terminationStatus])
        {
            self.errStr = @"Failed NSTask in snapshotBug";
            break;
        }
        else
        {
            NSFileHandle *fhand = [fpipe fileHandleForReading];
            
            NSData *data = [fhand readDataToEndOfFile];		 
            NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSDictionary *jsonDict = [jsonString JSONValue];
            BOOL res = (BOOL)[jsonDict valueForKey:@"success"];
            if(res)
            {
                NSString *msg = [jsonDict objectForKey:@"message"];
                [self postSnapshotBug:view snapName:msg title:title desc:desc];
                break;
            }
            else
            {
                self.errStr = @"Failed to get snapshot name";
                break;
            }                
        }
    }    
}


@end
