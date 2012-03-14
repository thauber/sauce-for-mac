//
//  SaucePreconnect.m
//  scout-desktop
//
//  Created by Sauce Labs on 3/12/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "saucepreconnect.h"
#import "SBJson.h"

@implementation SaucePreconnect

@synthesize secret;
@synthesize jobId;
@synthesize liveId;
@synthesize receivedData;

// use user/password to get live_id from server using
// use live_id to get secret and job-id 
- (BOOL)preAuthorize:(NSString*)user key:(NSString*)key  
                  os:(NSString*)os browser:(NSString*)browser browserVersion:(NSString*)browserVersion url:(NSString*)url
{
    BOOL success = NO;
    
    NSString *theURL=[NSString stringWithFormat:@"https://%@:%@@saucelabs.com/rest/v1/users/%@/scout",user,key,user];
    
    NSMutableURLRequest *request = 
        [NSMutableURLRequest requestWithURL:[NSURL URLWithString:theURL]
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
        success = YES;
    }
    else {
        NSLog(@"connection Failed");
    }
    
    return success;   // caller if we made connection ok
}

// return json object for vnc connection
- (NSString *)json_arg
{
    return [NSString stringWithFormat:@"{\"job-id\":\"%@\", \"secret\":\"%@\"}",jobId,secret];
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
    
    // inform the user
    /*UIAlertView *didFailWithErrorMessage = [[UIAlertView alloc] initWithTitle: @"NSURLConnection " message: @"/didFailWithError"  delegate: self cancelButtonTitle: @"Ok" otherButtonTitles: nil];
    [didFailWithErrorMessage show];
    [didFailWithErrorMessage release];*/
	
    //inform the user
    NSLog(@"Connection failed! Error - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [connection release];
    NSLog(@"connection Finished");
    // parse json data to get live-id
    NSString *jsonString = [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding];
    NSDictionary *jsonDict = [jsonString JSONValue];
    self.liveId = [jsonDict objectForKey:@"live-id"];

    
    self.receivedData=nil;
}

@end
