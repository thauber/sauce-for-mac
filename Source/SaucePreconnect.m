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
#import "RFBConnection.h"
#import "ScoutWindowController.h"
#import "Session.h"
#import "TunnelController.h"

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

@synthesize timer;
@synthesize authTimer;
@synthesize errStr;
@synthesize cancelled;
@synthesize internetOk;

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
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    // timeout if can't get creditions from server
    self.authTimer = [NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(cancelPreAuthorize:) userInfo:nil repeats:NO];

    NSString *farg = [NSString stringWithFormat:@"curl -X POST 'https://%@:%@@saucelabs.com/rest/v1/users/%@/scout' -H 'Content-Type: application/json' -d '{\"os\":\"%@\", \"browser\":\"%@\", \"browser-version\":\"%@\", \"url\":\"%@\"}'", self.user, self.ukey, self.user, self.os, self.browser, self.browserVersion, self.urlStr];
    cancelled = NO;
    self.errStr = nil;

    while(1)
    {
        if(cancelled)
            break;

        NSTask *ftask = [[[NSTask alloc] init] autorelease];
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
            internetOk = NO;
            break;;
        }
        else
        {
            internetOk = YES;
            NSFileHandle *fhand = [fpipe fileHandleForReading];
            
            NSData *data = [fhand readDataToEndOfFile];	
            NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            self.liveId = [self jsonVal:jsonString key:@"live-id"];
            [jsonString release];
            if(self.liveId.length)
                break;
            else 
            {
                self.errStr =@"Failed to retrieve live-id";
                break;
            }
        }
    }
    if(!cancelled && !errStr)
        [self curlGetauth];
    [authTimer invalidate];
    self.authTimer = nil;    

    if(errStr)      // call error method of app
    {
        [self cancelPreAuthorize:nil];
    }
    [pool release];
}

// retrieve value for a key out of json formatted data
-(NSString *)jsonVal:(NSString *)json key:(NSString *)key
{
    if([json hasPrefix:@"<html>"])
        return @"";
    const char *str = [json UTF8String];
    const char *kk = [key UTF8String];
    const char *kstr = strstr(str,kk);
    if(!kstr)
        return @"";
    
    kstr += [key length] + 2;   // skip over the key, end quote and colon
    if(*kstr == ' ')
        kstr++;
    char *cstr = malloc(100);
    int indx=0;
    if(*kstr == '"')
    {
        // gather chars up to end quote
        kstr++;     // skip leading quote
        while(*kstr != '"')
        {
            cstr[indx] = *kstr;
            indx++; kstr++;
        }
    }
    else    // value is an int or boolean (true/false)
    {
        // gather chars up to end comma or right brace
        while(*kstr != ',' && *kstr != '}')
        {
            cstr[indx] = *kstr;
            indx++; kstr++;
        }
    }
    cstr[indx] = 0;
    NSString *ret = [NSString stringWithCString:cstr encoding:NSUTF8StringEncoding];
    free(cstr);
    return ret;
}

-(void)cancelPreAuthorize:(NSTimer*)tm
{
    BOOL wasCancelled = self.cancelled;     // called from appdelegate
    
    [authTimer invalidate];
    self.authTimer = nil;
       
    if(wasCancelled)        // don't go circular
        return;
    
    self.cancelled = YES;       // make sure any loops break out

    if(tm)
        self.errStr = @"Connection attempt timed out";
    else 
    if(!errStr)
        self.errStr = @"Connection error";
    [[NSApp delegate]
     performSelectorOnMainThread:@selector(cancelOptionsConnect:)   
     withObject:errStr  waitUntilDone:NO];
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
            break;
        NSTask *ftask = [[[NSTask alloc] init] autorelease];
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
            internetOk = NO;
            break;
        }
        else
        {
            internetOk = YES;
            if(cancelled)
                break;
            else
            {
                NSFileHandle *fhand = [fpipe fileHandleForReading];
                
                NSData *data = [fhand readDataToEndOfFile];		 
                NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                self.secret = [self jsonVal:jsonString key:@"video-secret"];
                self.jobId  = [self jsonVal:jsonString key:@"job-id"];
                [jsonString release];
                if(secret.length)
                {
                    [[RFBConnectionManager sharedManager] performSelectorOnMainThread:@selector(connectToServer)   withObject:nil  waitUntilDone:NO];
                    break;
                }
                
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
            NSString *ajobid = [sdict objectForKey:@"jobId"];
            [credArr removeObjectAtIndex:i];
            NSString *farg = [NSString stringWithFormat:@"curl -X POST 'https://%@:%@@saucelabs.com/rest/v1/%@/jobs/%@' -H 'Content-Type: application/json' -d '{\"tags\":[\"test\",\"example\",taggable\"],\"public\":true,\"name\":\"changed-job-name\"}'", self.user, self.ukey, self.user, ajobid];
            NSTask *ftask = [[[NSTask alloc] init] autorelease];
            NSPipe *fpipe = [NSPipe pipe];
            [ftask setStandardOutput:fpipe];
            [ftask setLaunchPath:@"/bin/bash"];
            [ftask setArguments:[NSArray arrayWithObjects:@"-c", farg, nil]];
            [ftask launch];
            // no need to check for success
            [ftask waitUntilExit];
            if([ftask terminationStatus])
                NSLog(@"failed to close job");
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
                    os, @"os", browser, @"browser", browserVersion, @"browserVersion", 
                    @"2:00:00", @"remainingTime", nil];
    
    delayedSession=1;    // adding a new tab

    if(!credArr)
    {
        credArr = [[[NSMutableArray alloc] init] retain];
    }
    [credArr addObject:sdict];
    [sdict release];
    delayedSession = 2;     // done adding
}

-(NSString *)remainingTimeStr:(int)remaining
{
    if(!remaining)
        return @"";
    
    int hr = remaining / 3600;
    int min = (remaining % 3600)/60;
    int sec = remaining % 60;

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

-(void)startHeartbeat       // has to be 30 seconds at most
{    
    if(!self.timer)    
        self.timer = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(heartbeat:) userInfo:nil repeats:YES];
}

-(void)cancelHeartbeat
{
    if(![credArr count])    // only stop heartbeat if no sessions are active
    {
        [self.timer invalidate];
        self.timer = nil;
    }
    if(errStr)      // lost connection - 
    {
        [self cancelPreAuthorize:nil];
        // close all sessions
        
        [[ScoutWindowController sharedScout] performSelectorOnMainThread:@selector(closeAllTabs) withObject:nil waitUntilDone:NO];
    }
}

- (void)heartbeat:(NSTimer*)tm
{    
    if(delayedSession == 1)     // about to add a session
        return;

	NSEnumerator *credEnumerator = [credArr objectEnumerator];
    NSMutableDictionary *sdict;
    
    if(![credArr count])
    {
        [self cancelHeartbeat];
        return;        
    }
    
    
	while ( sdict = (NSMutableDictionary*)[credEnumerator nextObject] )
    {
        NSString *aliveid = [sdict objectForKey:@"liveId"];
                             
        NSString *farg = [NSString stringWithFormat:@"curl 'https://saucelabs.com/scout/live/%@/status?auth_username=%@&auth_access_key=%@' 2>/dev/null", aliveid, self.user, self.ukey];
        
        while(1)    
        {
            if(![credArr count])        // if all sessions closed while in heartbeat
            {
                [self cancelHeartbeat];
                return;        
            }
            NSTask *ftask = [[[NSTask alloc] init] autorelease];
            NSPipe *fpipe = [NSPipe pipe];
            [ftask setStandardOutput:fpipe];
            [ftask setLaunchPath:@"/bin/bash"];
            [ftask setArguments:[NSArray arrayWithObjects:@"-c", farg, nil]];
            [ftask launch];		// fetch job-id and secret server
            [ftask waitUntilExit];
            if([ftask terminationStatus])
            {
                self.errStr = @"failed NSTask in heartbeat";
                internetOk = NO;
                [self cancelHeartbeat];
                return;
            }
            else
            {
                internetOk = YES;
                NSFileHandle *fhand = [fpipe fileHandleForReading];
                
                NSData *data = [fhand readDataToEndOfFile];		 
                NSString *jsonString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
                NSString *status = [self jsonVal:jsonString key:@"status"];
                if([status isEqualToString:@"in progress"])
                {
                    id ssn = [sdict objectForKey:@"connection"];
                    Session *session = [[ScoutWindowController sharedScout] curSession];
                    NSString *remaining = [self jsonVal:jsonString key:@"remaining-time"];
                    // show in status
                    if([remaining length])
                    {
                        NSString *str = [self remainingTimeStr:[remaining intValue]];
                        [sdict setObject:str forKey:@"remainingTime"];
                        if(ssn == [session connection])
                        {
                            NSTextField *tf = [[ScoutWindowController sharedScout] timeRemainingStat];
                            [tf setStringValue:str];
                        }
                    }
                    break;                
                }
                else
                {
                    self.errStr = @"Heartbeat doesn't say 'in progress'";
                    // TODO: call closetabwithsession
//                    [self cancelHeartbeat];
                    break;
                }
            }
        }
        if(delayedSession)
            break;
        // update run time for session in history tab view
        NSView *vv = [sdict objectForKey:@"view"];
        [[ScoutWindowController sharedScout] performSelectorOnMainThread:@selector(updateHistoryRunTime:) withObject:vv waitUntilDone:NO];

    }
    if(delayedSession == 2)     // done adding, so clear flag
        delayedSession = 0;
}

// 0->bad login 1->good user  -1->bad internet connection
- (NSInteger)checkUserLogin:(NSString *)uuser  key:(NSString*)kkey
{
    NSString *farg = [NSString stringWithFormat:@"curl 'https://%@:%@@saucelabs.com/rest/v1/%@/jobs'", uuser, kkey, uuser];
    
    NSTask *ftask = [[[NSTask alloc] init] autorelease];
    NSPipe *fpipe = [NSPipe pipe];
    [ftask setStandardOutput:fpipe];
    [ftask setLaunchPath:@"/bin/bash"];
    [ftask setArguments:[NSArray arrayWithObjects:@"-c", farg, nil]];
    [ftask launch];		// fetch live id
    [ftask waitUntilExit];
    if([ftask terminationStatus])
    {
        self.errStr = @"Failed NSTask in checkUserLogin";
        internetOk = NO;
        return -1;
    }
    else
    {
        internetOk = YES;
        NSFileHandle *fhand = [fpipe fileHandleForReading];
        
        NSData *data = [fhand readDataToEndOfFile];		 
        NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSRange range = [jsonString rangeOfString:@"error"];
        [jsonString release];
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
     
    self.errStr = nil;
    while(1)
    {
        if(cancelled)
            break;

        NSTask *ftask = [[[NSTask alloc] init] autorelease];
        NSPipe *fpipe = [NSPipe pipe];
        [ftask setStandardOutput:fpipe];
        [ftask setLaunchPath:@"/bin/bash"];
        [ftask setArguments:[NSArray arrayWithObjects:@"-c", farg, nil]];
        [ftask launch];		// fetch live id
        [ftask waitUntilExit];
        if([ftask terminationStatus])
        {
            self.errStr = @"Failed NSTask in signupNew";
            internetOk = NO;
            break;
        }
        else
        {
            internetOk = YES;
            if(cancelled)
                break;
            else
            {
                NSFileHandle *fhand = [fpipe fileHandleForReading];
                
                NSData *data = [fhand readDataToEndOfFile];		 
                NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSString *akey = [self jsonVal:jsonString key:@"access_key"];
                [jsonString release];
                if(akey.length)
                {
                    self.user = self.userNew;
                    self.ukey = akey;
                    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                    [defaults setObject:self.user  forKey:kUsername];
                    [defaults setObject:self.ukey  forKey:kAccountkey];
                    [[NSApp delegate] performSelectorOnMainThread:@selector(newUserAuthorized:)   
                                            withObject:nil  waitUntilDone:NO];
                    break;
                }
            }
        }
    }    
}

- (void)postSnapshotBug:(NSString *)snapName title:(NSString *)title desc:(NSString *)desc
{ 
    NSView *view = [[[ScoutWindowController sharedScout] curSession] view];

    NSDictionary *sdict = [self sessionInfo:view];
    NSString *aliveid = [sdict objectForKey:@"liveId"];
    NSString *auser = [sdict objectForKey:@"user"];
    NSString *akey = [sdict objectForKey:@"ukey"];
    NSString *ajobid = [sdict objectForKey:@"jobId"];

    NSString* escTitle = [title stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding];
    NSString* escDesc  = [desc stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding];

    NSString *farg = [NSString stringWithFormat:@"curl 'https://%@:%@@saucelabs.com/scout/live/%@/reportbug?&ssname=%@&title=%@&description=%@'", auser, akey, aliveid, snapName, escTitle, escDesc];
    
    self.errStr = nil;
    NSString *surl;
    SnapProgress *sp = [[ScoutWindowController sharedScout] snapProgress];
    while(1)
    {
        if(cancelled)
            break;
        
        NSTask *ftask = [[[NSTask alloc] init] autorelease];
        NSPipe *fpipe = [NSPipe pipe];
        [ftask setStandardOutput:fpipe];
        [ftask setLaunchPath:@"/bin/bash"];
        [ftask setArguments:[NSArray arrayWithObjects:@"-c", farg, nil]];
        [ftask launch];		// fetch live id
        [ftask waitUntilExit];
        if([ftask terminationStatus])
        {
            internetOk = NO;
            break;
        }
        internetOk = YES;
        if(cancelled)
            break;
        else
        {
            NSFileHandle *fhand = [fpipe fileHandleForReading];
            
            NSData *data = [fhand readDataToEndOfFile];		 
            NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSString *snapId = [self jsonVal:jsonString key:@"c"];
            [jsonString release];
            if(snapId)  // QUERY: what is the id for?  jobId isn't always correct?
                surl = [NSString stringWithFormat:@"https://saucelabs.com/jobs/%@/%@",ajobid,snapName];
            break;
        }
    }        
    [sp setServerURL:surl];
}

- (void)snapshotBug:(NSString *)title desc:(NSString *)desc
{
    NSView *view = [[[[ScoutWindowController sharedScout] tabView] selectedTabViewItem] view];
    NSDictionary *sdict = [self sessionInfo:view];
    NSString *aliveid = [sdict objectForKey:@"liveId"];
    NSString *auser = [sdict objectForKey:@"user"];
    NSString *akey = [sdict objectForKey:@"ukey"];
    NSString *ajobid = [sdict objectForKey:@"jobId"];
    
    NSString *farg = [NSString stringWithFormat:@"curl 'https://%@:%@@saucelabs.com/scout/live/%@/sendcommand?&1=getScreenshotName&sessionId=%@&cmd=captureScreenshot'", 
                      auser, akey, aliveid, ajobid];

    self.errStr = nil;
    while(1)
    {
        if(cancelled)
            break;
        
        NSTask *ftask = [[[NSTask alloc] init] autorelease];
        NSPipe *fpipe = [NSPipe pipe];
        [ftask setStandardOutput:fpipe];
        [ftask setLaunchPath:@"/bin/bash"];
        [ftask setArguments:[NSArray arrayWithObjects:@"-c", farg, nil]];
        [ftask launch];		// fetch live id
        [ftask waitUntilExit];
        if([ftask terminationStatus])
        {
            self.errStr = @"Failed NSTask in snapshotBug";
            internetOk = NO;
            break;
        }
        internetOk = YES;
        if(cancelled)
            break;
        else
        {
            NSFileHandle *fhand = [fpipe fileHandleForReading];
            
            NSData *data = [fhand readDataToEndOfFile];		 
            NSString *jsonString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
            NSString *rstr = [self jsonVal:jsonString key:@"success"];            
            BOOL res = [rstr boolValue];
            if(res)
            {
                NSString *snapName = [self jsonVal:jsonString key:@"message"];            
                [self postSnapshotBug:snapName title:title desc:desc];
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

// 0->bad login 1->good user  -1->bad internet connection
- (NSInteger)checkAccountOk:(BOOL)bSubscribed
{
    NSString *farg = [NSString stringWithFormat:@"curl 'https://%@:%@@saucelabs.com/rest/v1/users/%@'", 
                      self.user, self.ukey, self.user];

    NSTask *ftask = [[[NSTask alloc] init] autorelease];
    NSPipe *fpipe = [NSPipe pipe];
    [ftask setStandardOutput:fpipe];
    [ftask setLaunchPath:@"/bin/bash"];
    [ftask setArguments:[NSArray arrayWithObjects:@"-c", farg, nil]];
    [ftask launch];		// fetch job-id and secret server
    [ftask waitUntilExit];
    if([ftask terminationStatus])
    {
        NSLog(@"failed NSTask");
        self.errStr =  @"Failed to request accountOk";
        internetOk = NO;
        return -1;  // assume no internet connection
    }
    else
    {
        internetOk = YES;
        NSFileHandle *fhand = [fpipe fileHandleForReading];
        
        NSData *data = [fhand readDataToEndOfFile];		 
        NSString *jsonString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
        if(bSubscribed)
        {
            NSString *subscribedStr = [self jsonVal:jsonString key:@"subscribed"];
            return [subscribedStr isEqualToString:@"true"];
        }
        
        NSString *minStr = [self jsonVal:jsonString key:@"minutes"];
        return ([minStr length] > 1);     // assume 0-9 minutes isn't enough
        
    }
    return NO;      // caller should check for errStr or -1 return
}

@end
