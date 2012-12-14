/* ConnectionWaiter.m
 * Copyright (C) 2010 Dustin Cartwright
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 */

#import "ConnectionWaiter.h"
#import "RFBConnection.h"
#import "RFBConnectionManager.h"
#import "ScoutWindowController.h"

#import "SaucePreconnect.h"

#import <poll.h>
#import <unistd.h>

@interface ConnectionWaiter(Private)

- (void)errorDidEnd:(NSWindow *)sheet returnCode:(int)returnCode
        contextInfo:(void *)info;

@end

@implementation ConnectionWaiter

@synthesize sdict;

+ (ConnectionWaiter *)waiterWithDict:(NSMutableDictionary *)sdict
                             delegate:(id<ConnectionWaiterDelegate>)aDelegate
{
    ConnectionWaiter *cw = [ConnectionWaiter alloc];
    cw = [cw initWithDict:sdict delegate:aDelegate];
    return [cw autorelease];
}

- (id)initWithDict:(NSMutableDictionary *)theDict
    delegate:(id<ConnectionWaiterDelegate>)aDelegate
{
    if (self = [super init])
    {
        host = kSauceLabsHost;        // fixed value
        port = [self checkHost:host];
        if(!port)
        {
            [self release];
            return nil;
        }

        lock = [[NSLock alloc] init];
        currentSock = -1;

        sdict = theDict;
        delegate = aDelegate;

        [NSThread detachNewThreadSelector: @selector(connect:) toTarget: self
                               withObject: nil];
    }
    return self;
}

- (void)dealloc
{
    [lock release];
    [errorStr release];
    [super dealloc];
}

- (int)checkHost:(NSString*)ahost
{
    for(int i=0;i<4;i++)
    {
        NSTask *ftask = [[[NSTask alloc] init] autorelease];
        NSPipe *fpipe = [NSPipe pipe];
        [ftask setStandardOutput:fpipe];
        [ftask setLaunchPath:@"/bin/bash"];
        NSString *farg = [NSString stringWithFormat:@"telnet %@ %d",ahost, kPorts[i]];
        [ftask setArguments:[NSArray arrayWithObjects:@"-c", farg, nil]];
        [ftask launch];		
        NSFileHandle *fhand = [fpipe fileHandleForReading];                
        NSData *data = [fhand readDataOfLength:40];
        NSString *rstr = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
        if([rstr rangeOfString:@"Connected"].location != NSNotFound)
            return kPorts[i];        
    }
    return 0;
}

- (void)setErrorStr:(NSString *)str
{
    [errorStr autorelease];
    errorStr = [str retain];
}

/* Cancels the connection attempt. This prevents any future messages to the
 * delegate. */
- (void)cancel
{
    [lock lock];
    delegate = nil;
    if (currentSock >= 0) {
        close(currentSock);
        currentSock = -1;
    }
    [lock unlock];
}

/* Attempts to connect to the server. */
- (void)connect: (id)unused
{
    int             error;
    struct addrinfo hints;
    struct addrinfo *res, *res0;
    NSString        *cause = @"unknown";
    int             causeErr = 0;
    NSString        *errMsg = nil;
    NSAutoreleasePool   *pool = [[NSAutoreleasePool alloc] init];
    NSString    *portStr = [NSString stringWithFormat:@"%d", port];

    memset(&hints, 0, sizeof(hints));
    hints.ai_family = PF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_flags = AI_ADDRCONFIG; // getaddrinfo will only do IPv6 lookup
                                    // if host has an IPv6 address
    hints.ai_flags = 0;
    hints.ai_protocol = IPPROTO_TCP;

    error = getaddrinfo([host UTF8String], [portStr UTF8String], &hints, &res0);
    [pool release];

    if (error) {
        NSNumber    *errnum = [[NSNumber alloc] initWithInt: error];
        [self performSelectorOnMainThread: @selector(lookupFailed:)
                               withObject: errnum waitUntilDone: NO];
        [errnum release];

        return;
    }

    // Try all available addresses for given host string
    for (res = res0; res; res = res->ai_next) {
        int     sock;
        if ((sock = socket(res->ai_family, res->ai_socktype, res->ai_protocol)) < 0) {
            cause = @"socket()";
            causeErr = errno;
            continue;
        }

        [lock lock];
        if (delegate == nil) {
            [lock unlock];
            close(sock);
            break;
        }
        currentSock = sock;
        [lock unlock];

        if (connect(sock, res->ai_addr, res->ai_addrlen) == 0) {
            freeaddrinfo(res0);
            
            // first send secret+jobID to server
            NSString *jobId = [sdict objectForKey:@"jobId"];
            NSString *secret = [sdict objectForKey:@"secret"];
            NSString *credStr = [NSString stringWithFormat:@"{\"job-id\":\"%@\",\"secret\":\"%@\"}\n",jobId,secret];
            int len = [credStr length];
            int wlen = sendto(sock,[credStr UTF8String],len,0,0,0);
            if(wlen != len)
                NSLog(@"failed to send credentials");
            
            [self waitForDataOn:sock];
            return; 
        } else {
            [lock lock];
            if (delegate == nil) {
                // cancelled in middle of connect, so cancel message has already
                // closed the socket
                [lock unlock];
                break;
            } else {
                if (errno == ECONNREFUSED) {
                    errMsg = @"ConnectRefused";
                } else if (errno == ETIMEDOUT) {
                    errMsg = @"ConnectTimedOut";
                } else {
                    cause = @"connect()";
                    causeErr = errno;
                }
                close(sock);
                currentSock = -1;
                [lock unlock];
            }
        }
    }

    freeaddrinfo(res0);
    // exhausted all possible addresses -> failure
    pool = [[NSAutoreleasePool alloc] init];
    if (errMsg == nil) {
        errMsg = [NSString stringWithFormat:@"%s: %@", strerror(causeErr),
                                        cause];
    }
    // TODO: prbly need to pass sdict
    [self performSelectorOnMainThread: @selector(connectionFailed:)
                           withObject: errMsg waitUntilDone: NO];
    [pool release];
}

- (void)waitForDataOn:(int)sock
{
    /* At this point, the socket has been connected successfully. Now we wait
     * for data from server. For example, if we're tunnelling over SSH, SSH will
     * accept the connection right away, but we want to wait for the handshake
     * from the VNC server, before we represent to the user that a connection
     * has been made. */
    struct pollfd   pfd;

    pfd.fd = sock;
    pfd.events = POLLERR | POLLHUP | POLLIN;
    poll(&pfd, 1, -1);
    if (pfd.revents & (POLLERR | POLLHUP)) {
        [self performSelectorOnMainThread:@selector(serverClosed)
                   withObject:nil waitUntilDone:NO];
        return;
    }

    [self performSelectorOnMainThread:@selector(finishConnection)
                           withObject:nil waitUntilDone:NO];
}

- (void)finishConnection
{
    if (delegate) {
        // only if we haven't been canceled
        NSFileHandle    *fh;
        RFBConnection   *theConnection;

        fh = [[NSFileHandle alloc] initWithFileDescriptor: currentSock
                                           closeOnDealloc: YES];
        theConnection = [[RFBConnection alloc] initWithFileHandle:fh  dict:sdict];
        [delegate connectionSucceeded: theConnection];
        [fh release];
        [theConnection release];
        currentSock = -1;
    }
}

/* DNS lookup has failed. Executed in main thread. */
- (void)lookupFailed: (NSNumber *)error
{
    int      errNum = [error intValue];
    NSString *actionStr = NSLocalizedString( @"NoNamedServer", nil );
    NSString *message;
    NSString *title = [NSString stringWithFormat:actionStr, host];

    if (errNum == EAI_NONAME)
        message = @"";
    else
        message = [NSString stringWithFormat:@"%s: getaddrinfo()",
                                gai_strerror(errNum)];

    [self error:title message:message];
}

/* Connection attempt has failed. Executed in main thread. */
- (void)connectionFailed: (NSString *)cause
{
    NSString *actionStr;

    actionStr = NSLocalizedString( @"NoConnection", nil );
    actionStr = [NSString stringWithFormat:actionStr, host, port];
        // cause can be either a localized string tag or the error string
        // itself, in which case NSLocalizedString just returns cause
    cause = NSLocalizedString(cause, nil);
    [self error:actionStr message:cause];
}

- (void)serverClosed
{
    NSString    *templ = NSLocalizedString(@"NoConnection", nil);
    NSString    *actionStr;

    actionStr = [NSString stringWithFormat:templ, host, port];
    [self error:actionStr message:NSLocalizedString(@"ServerClosed", nil)];
}

/* Creates error sheet */
- (void)error:(NSString*)theAction message:(NSString*)message
{
    if (delegate == nil) {
        // only show error if we haven't been canceled
        return;
    }

    if ([delegate respondsToSelector:@selector(connectionPrepareForSheet)])
        [delegate connectionPrepareForSheet];

    if (errorStr)
        theAction = errorStr;

	NSString *ok = NSLocalizedString( @"Okay", nil );
    NSBeginAlertSheet(theAction, ok, nil, nil, [[ScoutWindowController sharedScout] window], self, @selector(errorDidEnd:returnCode:contextInfo:), NULL, NULL, @"%@",message);
}

- (void)errorDidEnd:(NSWindow *)sheet returnCode:(int)returnCode
        contextInfo:(void *)info
{
    [delegate connectionFailed:sdict];
}

@end
