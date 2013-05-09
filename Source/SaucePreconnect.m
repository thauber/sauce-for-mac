//
//  SaucePreconnect.m
//  scout-desktop
//
//  Created by Sauce Labs on 3/12/12.
//  Copyright (c) 2012 __SauceLabs__. All rights reserved.
//

#import "SaucePreconnect.h"
#import "SBJson.h"
#import "RFBConnectionManager.h"
#import "RFBConnection.h"
#import "ScoutWindowController.h"
#import "Session.h"
#import "TunnelController.h"
#import "AppDelegate.h"
#import "MF_Base64Additions.h"

NSString *kSauceLabsDomain = @"saucelabs.com";

@implementation SaucePreconnect

@synthesize user;
@synthesize ukey;

@synthesize timer;
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

// sdict state: 0=os/browser/url; -1=secret/liveId; 1=connected
- (NSMutableDictionary*)setOptions:(NSString*)os browser:(NSString*)browser 
browserVersion:(NSString*)browserVersion url:(NSString*)urlStr resolution:(NSString*)resolution
{
    NSString *osbvStr = [NSString stringWithFormat:@"%@/%@ %@",os,browser,browserVersion];

    NSMutableDictionary *sdict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                  [NSNumber numberWithInt:0], @"state", user, @"user", ukey, @"ukey",
                                  osbvStr, @"osbv", urlStr, @"url", 
                                  os, @"os", browser, @"browser", browserVersion, @"browserVersion", 
                                  @"2:00:00", @"remainingTime", resolution, @"resolution", nil];

    if(!credArr)
    {
        credArr = [[[NSMutableArray alloc] init] retain];
    }
    [credArr addObject:sdict];
    return sdict;
}

// use user/password and users selections to get live_id from server
- (void)preAuthorize:(NSMutableDictionary*)sdict
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    // timeout if can't get credentials from server
    NSTimer *authTimer = [NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(cancelPreAuthorize:) userInfo:sdict repeats:NO];

    [sdict setObject:authTimer forKey:@"authTimer"];
    NSString *os = [sdict objectForKey:@"os"];
    NSString *browser = [sdict objectForKey:@"browser"];
    if([browser isEqualToString:@"chrome"])        // correct for what server accepts
        browser = @"googlechrome";
    NSString *browserVersion = [sdict objectForKey:@"browserVersion"];
    NSString *urlStr = [sdict objectForKey:@"url"];
    NSString *resolution = [sdict objectForKey:@"resolution"];
    NSString *maxdur = @"";
    if([[NSApp delegate] isDemoAccount])
        maxdur = @",\"max-duration\":660";    // give code a chance to end 10 minute demo account session

    NSString *farg = [NSString stringWithFormat:@"curl -X POST 'https://%@:%@@%@/rest/v1/users/%@/scout' -H 'Content-Type: application/json' -d '{\"os\":\"%@\", \"browser\":\"%@\", \"browser-version\":\"%@\", \"url\":\"%@\", \"res\":\"%@\",\"client\":\"mac\"%@}'", self.user, self.ukey,kSauceLabsDomain, user, os, browser, browserVersion, urlStr, resolution, maxdur];

    NSString *errStr = nil;
    while(1)
    {
        if([sdict objectForKey:@"errorString"])
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
            errStr = @"Failed to send user options to server";
            internetOk = NO;
            break;;
        }
        else
        {
            internetOk = YES;
            NSFileHandle *fhand = [fpipe fileHandleForReading];
            
            NSData *data = [fhand readDataToEndOfFile];	
            NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSString *liveId = [self jsonVal:jsonString key:@"live-id"];
            [jsonString release];
            if(liveId.length)
            {
                [sdict setObject:liveId forKey:@"liveId"];
                break;
            }
            else 
            {
                errStr = @"Failed to retrieve live-id";
                break;
            }
        }
    }
    if(errStr)
        [sdict setObject:@"Failed to send user options to server" forKey:@"errorString"];
    if(![sdict objectForKey:@"errorString"])        // no error/no cancel
        [self curlGetauth:sdict];
    NSTimer *atmr = [sdict objectForKey:@"authTimer"];
    [atmr invalidate];
    [sdict removeObjectForKey:@"authTimer"];    

    if([sdict objectForKey:@"errorString"])        // error
    {
        [self cancelPreAuthorize:(id)sdict];
    }
    [pool release];
}

// retrieve value for a key out of json formatted data
-(NSString *)jsonVal:(NSString *)json key:(NSString *)key
{
    if([json hasPrefix:@"<html>"])
        return @"";
    int klen = [key length];
    const char *kk = [key UTF8String];
    const char *kstr = [json UTF8String];
    bool kfound = false;
    while((kstr = strstr(kstr,kk)))     // avoid match on part of a key
    {
        if( *(kstr + klen) == '"')
        {
           kfound = true;
           break;
        }
        kstr++; 
    }
    if(!kfound || !kstr)
        return @"";
    
    kstr += klen + 2;   // skip over the key, end quote and colon
    if(*kstr == ' ')            // skip possible space
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

-(void)cancelPreAuthorize:(id)tm      // if timer, userinfo is sdict; or it is sdict
{
    NSMutableDictionary *sdict;
    NSTimer *tmr = nil;
    if([tm isKindOfClass:[NSTimer class]])
    {
        tmr = (NSTimer*)tm;
        sdict = [tmr userInfo];
        [tmr invalidate];
    }
    else        // was passed sdict in directly
    {
        sdict = (NSMutableDictionary*)tm;
        tm = [sdict objectForKey:@"authTimer"];
        [tm invalidate];
    }
    
    [sdict removeObjectForKey:@"authTimer"];
       
    NSString *errStr = nil;
    if(tmr)
        errStr = @"Connection attempt timed out";
    else 
    if(![sdict objectForKey:@"errorString"])
        errStr = @"Connection error";
    if(errStr)
        [sdict setObject:errStr forKey:@"errorString"];
    
    // remove tab with the sdict's sessionConnect object
    if(tmr)
    {
        [[NSApp delegate] performSelectorOnMainThread:@selector(cancelOptionsConnect:)   
         withObject:sdict  waitUntilDone:NO];
    }
}

// poll til we get secret/jobid
-(void)curlGetauth:(NSMutableDictionary*)sdict
{
    NSString *liveId = [sdict objectForKey:@"liveId"];
	NSString *farg = [NSString stringWithFormat:@"curl 'https://%@:%@@%@/scout/live/%@/status?secret&'", self.user, self.ukey, kSauceLabsDomain, liveId];

    while(1)    // use live-id to get job-id
    {
        if([sdict objectForKey:@"errorString"])
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
            [sdict setObject:@"Failed to request job-id" forKey:@"errorString"];
            internetOk = NO;
            break;
        }
        else
        {
            internetOk = YES;
            if([sdict objectForKey:@"errorString"])
                break;
            else
            {
                NSFileHandle *fhand = [fpipe fileHandleForReading];
                
                NSData *data = [fhand readDataToEndOfFile];		 
                NSString *jsonString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
                NSString *secret = [self jsonVal:jsonString key:@"video-secret"];
                NSString *jobId  = [self jsonVal:jsonString key:@"job-id"];
                if(secret.length)
                {
                    [sdict setObject:secret forKey:@"secret"];
                    [sdict setObject:jobId forKey:@"jobId"];
                    [[RFBConnectionManager sharedManager] performSelectorOnMainThread:@selector(connectToServer:)   withObject:sdict  waitUntilDone:NO];
                    break;
                }
                else
                {
                    NSString *err = [self jsonVal:jsonString key:@"status"];
                    if([err isEqualToString:@"error"])
                    {
                        [sdict setObject:@"Error getting job id" forKey:@"errorString"];
                        [[NSApp delegate] performSelectorOnMainThread:@selector(cancelOptionsConnect:) withObject:sdict waitUntilDone:NO];
                        break;
                    }                    
                }                
            }
        }
    }
}

// remove session being close from heartbeat array
-(void)sessionClosed:(NSMutableDictionary*)sdict
{
	int len = [credArr count];
    
    for(int i=0;i<len;i++)
    {
        if([credArr objectAtIndex:i] == sdict)
        {
// do we need this?
//            if(![sdict objectForKey:@"view"])
//                return;
            NSString *aliveId = [sdict objectForKey:@"liveId"];
            NSString *farg = [NSString stringWithFormat:@"curl -X DELETE 'https://%@:%@@%@/rest/v1/users/%@/scout/%@'", self.user, self.ukey, kSauceLabsDomain, self.user, aliveId];
            [credArr removeObjectAtIndex:i];
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
            break;
        }
    }

}

// return get info for a view; also used to determine if tab has an active session
-(NSMutableDictionary*)sessionInfo:(id)view
{
	int len = [credArr count];
    NSMutableDictionary *sdict;
    
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

- (NSMutableDictionary *)sdictWithSCView:(NSView*)view
{
	int len = [credArr count];
    NSMutableDictionary *sdict;
    
    for(int i=0;i<len;i++)
    {
        sdict = [credArr objectAtIndex:i];
        if([sdict objectForKey:@"scview"] == view)
        {
            return sdict;
        }
    }
    return nil;
    
}

#if 0
-(void)setvmsize:(NSSize)size
{
    NSMutableDictionary *sdict = [credArr lastObject];
    NSString *str = [NSString stringWithFormat:@"%.0fx%.0f",size.width,size.height];
    [sdict setValue:str forKey:@"size"];
    [[[ScoutWindowController sharedScout] vmsize] setStringValue:str];
}
#endif

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
    if(!hr && !min)   // less than 1 minute left, so prompt users
    {
        NSString *res = [self checkAccountOk];
        if([res rangeOfString:@"-"].location != NSNotFound)
            [[NSApp delegate] performSelectorOnMainThread:@selector(showSubscribeDlg:) withObject:nil waitUntilDone:NO];

    }
    NSString *str = [NSString stringWithFormat:@"%@:%@:%@",hrstr,minstr,secstr];
    return str;
}

-(void)startHeartbeat       // has to be 30 seconds at most
{    
    if(!self.timer)    
        self.timer = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(heartbeat:) userInfo:nil repeats:YES];
}

-(void)cancelHeartbeat:(NSString*)errStr
{
    if(![credArr count])    // only stop heartbeat if no sessions are active
    {
        [self.timer invalidate];
        self.timer = nil;
    }
    if(errStr)      // lost connection - 
    {        
        [[ScoutWindowController sharedScout] performSelectorOnMainThread:@selector(closeAllTabs) withObject:nil waitUntilDone:NO];
    }
}

- (void)heartbeat:(NSTimer*)tm
{    
    NSMutableDictionary *sdict;
    
    if(![credArr count])
    {
        [self cancelHeartbeat:nil];
        return;        
    }
    
    NSInteger credArrSz = [credArr count];
    BOOL removedObj = NO;
    NSInteger indx=0;
	while (indx < [credArr count] )
    {
        sdict = (NSMutableDictionary*)[credArr objectAtIndex:indx];
        NSString *aliveid = [sdict objectForKey:@"liveId"];
        if(!aliveid)
        {
            NSLog(@"no liveId in heartbeat");
            indx++;
            continue;
        }
        NSString *farg = [NSString stringWithFormat:@"curl 'https://%@/scout/live/%@/status?auth_username=%@&auth_access_key=%@' 2>/dev/null", kSauceLabsDomain, aliveid, self.user, self.ukey];

        while(1)    
        {
            if(![credArr count])        // if all sessions closed while in heartbeat
            {
                [self cancelHeartbeat:nil];
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
                internetOk = NO;
                [self cancelHeartbeat:@"failed NSTask in heartbeat"];
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
                    NSString *remaining = [self jsonVal:jsonString key:@"remaining-time"];
                    // show in status
                    if([remaining length] && [credArr count] == credArrSz)
                    {
                        NSString *str = [self remainingTimeStr:[remaining intValue]];
                        [sdict setObject:str forKey:@"remainingTime"];
                    }
                    break;                
                }
                else
                {
                    if(![status isEqualToString:@"queued"] && ![status isEqualToString:@"new"])
                    {
                        NSLog(@"heartbeat - not in progress:%@",jsonString);
                        [self sessionClosed:sdict];
                        credArrSz = [credArr count];
                        removedObj = YES;
                    }
                    break;
                }
            }
        }
        if(removedObj)              // removed b/c session not in progress
        {
            removedObj = NO;        // clear flag
            [sdict setObject:@"job not in progress" forKey:@"errorString"];
            [[NSApp delegate] cancelOptionsConnect:sdict];
            continue;               // avoid incrementing index
        }
        // update run time for session in history tab view
        NSView *vv = [sdict objectForKey:@"view"];
        if(vv)
            [[ScoutWindowController sharedScout] performSelectorOnMainThread:@selector(updateHistoryRunTime:) withObject:vv waitUntilDone:NO];
        indx++;

    }
}

// return: 'N'->failed login; nil->good user;  'F'->bad internet connection
- (NSString*)checkUserLogin:(NSString *)uuser  key:(NSString*)kkey
{
    NSString *farg = [NSString stringWithFormat:@"curl 'https://%@:%@@%@/rest/v1/%@/jobs'", uuser, kkey, kSauceLabsDomain, uuser];
    
    NSString *resStr = nil;
    NSTask *ftask = [[[NSTask alloc] init] autorelease];
    NSPipe *fpipe = [NSPipe pipe];
    [ftask setStandardOutput:fpipe];
    [ftask setLaunchPath:@"/bin/bash"];
    [ftask setArguments:[NSArray arrayWithObjects:@"-c", farg, nil]];
    [ftask launch];		// fetch live id
    [ftask waitUntilExit];
    if([ftask terminationStatus])
    {
        resStr = @"Failed login check";
        internetOk = NO;
    }
    else
    {
        internetOk = YES;
        NSFileHandle *fhand = [fpipe fileHandleForReading];
        
        NSData *data = [fhand readDataToEndOfFile];		 
        NSString *jsonString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
        NSRange range = [jsonString rangeOfString:@"error"];
        if(!range.length)
        {
            self.user = uuser;
            self.ukey = kkey;
        }
        else 
            resStr = @"User account login error";
    }
    return resStr;
}

- (NSString*)signupNew:(NSString*)userNew passNew:(NSString*)passNew 
         emailNew:(NSString*)emailNew
{        
    NSString *farg = [NSString stringWithFormat:@"curl -X POST https://%@/rest/v1/users -H 'Content-Type: application/json' -d '{\"username\":\"%@\", \"password\":\"%@\",\"name\":\"\",\"email\":\"%@\",\"token\":\"0E44EF6E-B170-4CA0-8264-78FD9E49E5CD\"}'",kSauceLabsDomain, userNew, passNew, emailNew];
     
    NSString *errStr = nil;
    // TODO: put a timer on it
    while(1)
    {
        NSTask *ftask = [[[NSTask alloc] init] autorelease];
        NSPipe *fpipe = [NSPipe pipe];
        [ftask setStandardOutput:fpipe];
        [ftask setLaunchPath:@"/bin/bash"];
        [ftask setArguments:[NSArray arrayWithObjects:@"-c", farg, nil]];
        [ftask launch];		// fetch live id
        [ftask waitUntilExit];
        if([ftask terminationStatus])
        {
            errStr = @"Failed NSTask in signupNew";
            internetOk = NO;
            break;
        }
        else
        {
            internetOk = YES;
            NSFileHandle *fhand = [fpipe fileHandleForReading];
            
            NSData *data = [fhand readDataToEndOfFile];		 
            NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSString *akey = [self jsonVal:jsonString key:@"access_key"];
            [jsonString release];
            if(akey.length)
            {
                self.user = userNew;
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
    return errStr;
}

- (NSString*)postSnapshotBug:(NSString *)snapName title:(NSString *)title desc:(NSString *)desc
{ 
    NSView *view = [[[ScoutWindowController sharedScout] curSession] view];

    NSDictionary *sdict = [self sessionInfo:view];
    NSString *aliveid = [sdict objectForKey:@"liveId"];
    NSString *auser = [sdict objectForKey:@"user"];
    NSString *akey = [sdict objectForKey:@"ukey"];
    NSString *ajobid = [sdict objectForKey:@"jobId"];

    NSString* escTitle = [title stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding];
    NSString* escDesc  = [desc stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding];

    NSString *farg = [NSString stringWithFormat:@"curl 'https://%@:%@@%@/scout/live/%@/reportbug?&ssname=%@&title=%@&description=%@'", auser, akey, kSauceLabsDomain, aliveid, snapName, escTitle, escDesc];
    
    NSString *surl;
    NSString *errStr = nil;
    
    SnapProgress *sp = [[ScoutWindowController sharedScout] snapProgress];
    // TODO: ?can this be cancelled
        
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
        return @"Failed to report snapshot/bug to server";
    }
    internetOk = YES;
    NSFileHandle *fhand = [fpipe fileHandleForReading];
    
    NSData *data = [fhand readDataToEndOfFile];		 
    NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSString *snapId = [self jsonVal:jsonString key:@"c"];
    [jsonString release];
    if(snapId)  // ?what is the id for?
        surl = [NSString stringWithFormat:@"https://%@/jobs/%@/%@",kSauceLabsDomain, ajobid,snapName];
    else 
        errStr = @"Failed to retrieve snapshot id";

    if(surl)
        [sp setServerURL:surl];
    else
        errStr = @"Failed to retrieve snapshot URL";
    return errStr;
}

- (NSString*)snapshotBug:(NSString *)title desc:(NSString *)desc
{
    NSView *view = [[[[ScoutWindowController sharedScout] tabView] selectedTabViewItem] view];
    NSDictionary *sdict = [self sessionInfo:view];
    NSString *aliveid = [sdict objectForKey:@"liveId"];
    NSString *auser = [sdict objectForKey:@"user"];
    NSString *akey = [sdict objectForKey:@"ukey"];
    NSString *ajobid = [sdict objectForKey:@"jobId"];
    
    NSString *farg = [NSString stringWithFormat:@"curl 'https://%@:%@@%@/scout/live/%@/sendcommand?&1=getScreenshotName&sessionId=%@&cmd=captureScreenshot'", 
                      auser, akey, kSauceLabsDomain, aliveid, ajobid];

    NSTask *ftask = [[[NSTask alloc] init] autorelease];
    NSPipe *fpipe = [NSPipe pipe];
    [ftask setStandardOutput:fpipe];
    [ftask setLaunchPath:@"/bin/bash"];
    [ftask setArguments:[NSArray arrayWithObjects:@"-c", farg, nil]];
    [ftask launch];		// fetch live id
    [ftask waitUntilExit];
    if([ftask terminationStatus])
    {
        return @"Failed NSTask in snapshotBug";
        internetOk = NO;
    }
    internetOk = YES;
    NSFileHandle *fhand = [fpipe fileHandleForReading];
    
    NSData *data = [fhand readDataToEndOfFile];		 
    NSString *jsonString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    NSString *rstr = [self jsonVal:jsonString key:@"success"];            
    BOOL res = [rstr boolValue];
    if(res)
    {
        NSString *snapName = [self jsonVal:jsonString key:@"message"];            
        return [self postSnapshotBug:snapName title:title desc:desc];
    }
    else
    {
        return @"Failed to get snapshot name";
    }                
    return nil;
}

// 'S'->subscribed; nil->good user;  'F'->bad internet connection
- (NSString*)checkAccountOk
{
    NSString *farg = [NSString stringWithFormat:@"curl 'https://%@:%@@%@/rest/v1/users/%@'",self.user, self.ukey, kSauceLabsDomain, self.user];

    NSString *resStr = nil;
    while(1)
    {
        NSTask *ftask = [[[NSTask alloc] init] autorelease];
        NSPipe *fpipe = [NSPipe pipe];
        [ftask setStandardOutput:fpipe];
        [ftask setLaunchPath:@"/bin/bash"];
        [ftask setArguments:[NSArray arrayWithObjects:@"-c", farg, nil]];
        [ftask launch];
        [ftask waitUntilExit];
        if([ftask terminationStatus])
        {
            NSLog(@"failed NSTask");
            internetOk = NO;
            return @"Failed to request accountOk";
        }
        else
        {
            internetOk = YES;
            NSFileHandle *fhand = [fpipe fileHandleForReading];
            
            NSData *data = [fhand readDataToEndOfFile];		 
            NSString *jsonString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
            NSString *subscribedStr = [self jsonVal:jsonString key:@"subscribed"];
            if([subscribedStr length])
            {
                
                NSString *minStr = [self jsonVal:jsonString key:@"can_run_manual"];
                BOOL bMin = [minStr boolValue];
                if([subscribedStr isEqualToString:@"true"])
                {
                    if(bMin)
                        resStr = @"S+";     // subscribed with minutes
                    else
                        resStr = @"S-";     // subscribed without minutes
                }
                else
                {
                    if(bMin)
                        resStr = @"N+";     // not subscribed with minutes
                    else
                        resStr = @"N-";     // not subscribed without minutes               
                }
                break;
            }            
        }
    }
    return resStr;
}

// called on connection for a demo account session
- (void)sendDemoVersion:(NSString*)job version:(NSString*)version
{
    NSString *farg = [NSString stringWithFormat:@"curl https://%@:%@@%@/rest/v1/%@/jobs/%@ -H 'Content-Type: application/json' -d '{\"tags\":[\"desktop\", \"version:%@\"]}'",self.user, self.ukey, kSauceLabsDomain, self.user, job,version];

    NSTask *ftask = [[[NSTask alloc] init] autorelease];
    NSPipe *fpipe = [NSPipe pipe];
    [ftask setStandardOutput:fpipe];
    [ftask setLaunchPath:@"/bin/bash"];
    [ftask setArguments:[NSArray arrayWithObjects:@"-c", farg, nil]];
    [ftask launch];
    [ftask waitUntilExit];
    if([ftask terminationStatus])
    {
        NSLog(@"failed NSTask in sendDemoVersion");
    }
}

- (NSString*)accountkeyFromPassword:(NSString*)uname pswd:(NSString*)pass
{
    NSString *key = @"";

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/rest/v1/users/%@", kSauceLabsDomain, uname]];
    NSString *auth = [[NSString stringWithFormat:@"%@:%@", uname, pass] base64String];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request addValue:[NSString stringWithFormat:@"Basic %@", auth] forHTTPHeaderField:@"Authorization"];

    NSData *response = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
    
    if (response) {
        NSError *error = nil;
        NSDictionary *data = [NSJSONSerialization JSONObjectWithData:response options:0 error:&error];
    
        if (!error) {
            key = [data objectForKey:@"access_key"];
        }
    }
        
    return key != nil ? key : @"";
}


@end
