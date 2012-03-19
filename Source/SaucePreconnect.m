//
//  SaucePreconnect.m
//  scout-desktop
//
//  Created by Sauce Labs on 3/12/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "SaucePreconnect.h"
#import "SBJson.h"
#import "NSData-Base64Extensions.h"

@implementation SaucePreconnect

@synthesize caller;
@synthesize user;
@synthesize ukey;
@synthesize secret;
@synthesize jobId;
@synthesize liveId;
@synthesize receivedData;

// use user/password to get live_id from server using
// use live_id to get secret and job-id 
- (void)preAuthorize:(id)ucaller username:(NSString*)uuser key:(NSString*)key os:(NSString*)os 
             browser:(NSString*)browser browserVersion:(NSString*)browserVersion url:(NSString*)url
{    
    self.caller = ucaller;
    self.user = uuser;
    self.ukey = key;
    getLiveId = YES;
    
// worked for a few days - then it didn't?
/*
    NSMutableURLRequest *request;
    
    NSString *theURL=[NSString stringWithFormat:@"https://%@:%@@saucelabs.com/rest/v1/users/%@/scout",user,key,user];
    
    request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:theURL]
                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                timeoutInterval:10.0];

    NSDictionary *jsonDict = [NSDictionary dictionaryWithObjectsAndKeys:os,@"os",browser,@"browser",
                              browserVersion,@"browser-version",url,@"url",nil];
    
    NSString *jsonRequest = [jsonDict JSONRepresentation];

    NSData *requestData = [NSData dataWithBytes:[jsonRequest UTF8String] length:[jsonRequest length]];
    
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%d", [requestData length]] forHTTPHeaderField:@"Content-Length"];
    [request setHTTPBody: requestData];    

    NSURLConnection *connection = [[NSURLConnection alloc]initWithRequest:request delegate:self];
    
    if(connection) {
        self.receivedData = [NSMutableData data];
    }
    else {
        NSLog(@"connection Failed");
    }
*/
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
        }
        else
        {
            NSFileHandle *fhand = [fpipe fileHandleForReading];
            
            NSData *data = [fhand readDataToEndOfFile];		 
            NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSDictionary *jsonDict = [jsonString JSONValue];
            self.liveId = [jsonDict objectForKey:@"live-id"];
            if(self.liveId.length)
            {
                break;
            }
        }
    }
    [self curlGetauth];
 
}



// return json object for vnc connection
- (NSString *)json_arg
{
    NSArray *jsArr = [NSArray arrayWithObjects:@"job-id",self.jobId,@"secret",self.secret,nil];
    NSString *jsonString = [[jsArr JSONRepresentation] retain];
    return jsonString;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [receivedData appendData:data];    
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    
    [connection release];
    self.receivedData=nil;    
	
    //TODO: inform the user
    NSLog(@"Connection failed! Error - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [connection release];
    NSLog(@"connection Finished");
    
    // parse json data
    NSString *jsonString = [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding];
    NSDictionary *jsonDict = [jsonString JSONValue];
    self.receivedData=nil;      
    

    if(getLiveId)   // get live-id and setup connection to get job-id and secret
    {
        getLiveId = NO;
        
        self.liveId = [jsonDict objectForKey:@"live-id"];
                
// doesn't work - returns saucelabs home page       
//      [self doConnect];
        if(self.liveId)
            [self curlGetauth];
        else
        {
            NSString *err = @"failed to get live id";
            [self performSelectorOnMainThread:@selector(connectError:) withObject:err waitUntilDone:NO];
        }

    }
    else // get job-id and secret
    {
        self.secret = [jsonDict objectForKey:@"video-secret"];
        self.jobId  = [jsonDict objectForKey:@"job-id"];
        if(![secret length])
            [self doConnect];        
    }
}

-(void)connectError:(NSString*)err
{
    NSLog(@"err:%@",err);
}


// doesn't work with or w/o basic auth - returns saucelabs home page
-(void)doConnect
{
    // doesn't work - returns saucelabs.com home page
            NSString *theURL=[NSString stringWithFormat:@"https://%@:%@@saucelabs.com/scout/live/%@/status?secret&", self.user, self.ukey, self.liveId ];
// basic authorization header doesn't help
//    NSString *theURL=[NSString stringWithFormat:@"https://saucelabs.com/scout/live/%@/status?secret&",
//                      self.liveId ];
    
    NSMutableURLRequest *request = 
                [NSMutableURLRequest requestWithURL:[NSURL URLWithString:theURL]
                            cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                        timeoutInterval:10.0];
/*    
    NSString *authStr = [NSString stringWithFormat:@"%@:%@", self.user, self.ukey];
    NSData *authData = [authStr dataUsingEncoding:NSASCIIStringEncoding];
    NSString *authValue = [NSString stringWithFormat:@"Basic %@", [authData encodeBase64]];
    [request setValue:authValue forHTTPHeaderField:@"Authorization"];        
*/   
    NSURLConnection *connection = [[NSURLConnection alloc]initWithRequest:request delegate:self];
    
    if(connection) {
        self.receivedData = [NSMutableData data];
    }
    else {
        NSLog(@"connection Failed");
    }

}

// poll til we get secret/jobid
-(void)curlGetauth
{
	NSString *farg = [NSString stringWithFormat:@"curl 'https://%@:%@@saucelabs.com/scout/live/%@/status?secret&'",
                       self.user, self.ukey, self.liveId ];

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
                NSString *parms = [self json_arg];
                [self.caller performSelectorOnMainThread:@selector(cred:) withObject:parms waitUntilDone:NO];
                break;
            }
        }
    }
}

@end
