/* Copyright (C) 1998-2000  Helmut Maierhofer <helmut.maierhofer@chello.at>
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

#import "RFBConnectionManager.h"
#import "RFBConnection.h"
#import "ConnectionWaiter.h"
#import "PrefController.h"
#import "rfbproto.h"
#import "vncauth.h"
#import "Session.h"
#import "SessionController.h"
#import "SaucePreconnect.h"
#import "AppDelegate.h"
#import "ScoutWindowController.h"

NSString *kUsername = @"username";
NSString *kAccountkey = @"accountkey";
NSString *kSessionURL = @"sessionURL";
NSString *kSessionIndxWin = @"sessionIndxWin";
NSString *kSessionIndxLnx = @"sessionIndxLnx";
NSString *kSessionIndxMac = @"sessionIndxMac";
NSString *kSessionIndxMbl = @"sessionIndxMbl";
NSString *kCurTab = @"lastCurrentTab";
NSString *kSauceLabsHost = @"tv1.saucelabs.com";    // fixed host for connection
//NSString *kSauceLabsHost = @"admc.dev.saucelabs.com";    // fixed host for connection
int kPorts[4] = {5901, 80, 443, 6080};                      // fixed port for connection


static NSString *kPrefs_LastHost_Key = @"RFBLastHost";

@implementation RFBConnectionManager

+ (id)sharedManager
{ 
	static id sInstance = nil;
	if ( ! sInstance )
	{
		sInstance = [[self alloc] init];

		NSParameterAssert( sInstance != nil );
		
        [sInstance wakeup];
		
		[[NSNotificationCenter defaultCenter] addObserver:sInstance
												 selector:@selector(applicationWillTerminate:)
													 name:NSApplicationWillTerminateNotification object:NSApp];
	}
	return sInstance;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    /* We need to make sure than any changes to text fields get reflected in our
     * preferences before we quit. */
    [[self window] makeFirstResponder:nil];
}

- (void)wakeup
{
    signal(SIGPIPE, SIG_IGN);
    connectionWaiters = [[NSMutableArray alloc] init];
    sessions = [[NSMutableArray alloc] init];

}

- (void)connectToServer:(NSMutableDictionary*)sdict     // called after login and user options dialogs
{
    ConnectionWaiter *connectionWaiter = [ConnectionWaiter waiterWithDict:sdict delegate:self];
    if (connectionWaiter == nil)
        [self connectionFailed:sdict];
    else 
        [connectionWaiters addObject:connectionWaiter];
}

- (void)connectionFailed:(NSMutableDictionary*)sdict
{
    [self cancelConnection:sdict];
    [sdict setObject:@"Failed Connection" forKey:@"errorString"];
    [[SaucePreconnect sharedPreconnect] cancelPreAuthorize:sdict];
    [[ScoutWindowController sharedScout] closeTab:sdict];
    NSBeginAlertSheet(@"Failed Connection", @"Ok", nil, nil, [[ScoutWindowController sharedScout] window], self, nil, nil, nil, @"Check your internet connection - or Sauce Labs server may be down");
}

- (void)cancelConnection:(NSMutableDictionary*)sdict
{
    [self connectionDone:sdict];
}


// We're done with the session
- (void)connectionDone:(NSMutableDictionary*)sdict
{
	NSEnumerator *enumerator = [sessions objectEnumerator];
    Session *ss;
    while(ss = [enumerator nextObject])
    {
        if([ss sdict] == sdict)
        {
            [self removeConnectionWaiter:sdict];
            [sessions removeObject:ss];
            return;
        }
    }    
}

- (NSString*)translateDisplayName:(NSString*)aName forHost:(NSString*)aHost
{
    return @"Sauce Labs";
}

- (void)removeConnectionWaiter:(NSMutableDictionary*)sdict
{
    // find connectionWaiter for the sdict and remove it from array
	NSEnumerator *enumerator = [connectionWaiters objectEnumerator];
    ConnectionWaiter *cw;
    while(cw = [enumerator nextObject])
    {
        if([cw sdict] == sdict)
        {
            [connectionWaiters removeObject:cw];
            return;
        }
    }
}

/* Registers a successful connection using an already-created RFBConnection
 * object. */
- (void)connectionSucceeded: (RFBConnection *)theConnection
{
    NSMutableDictionary *sdict = [theConnection sdict];
    [self removeConnectionWaiter:sdict];
    [(AppDelegate*)[NSApp delegate] connectionSucceeded:sdict]; 
    Session *sess = [[Session alloc] initWithConnection:theConnection sdict:sdict];
    [sessions addObject:sess];
    [sess release];
    [sdict removeObjectForKey:@"scview"];
    [self setSessionsUpdateIntervals];
    if(![[SaucePreconnect sharedPreconnect] timer])
        [[SaucePreconnect sharedPreconnect]  startHeartbeat];
}

- (void)setSessionsUpdateIntervals
{
	NSEnumerator *enumerator = [sessions objectEnumerator];
    Session      *session;
	float       interval;
	while (session = [enumerator nextObject])
    {
		if ([[ScoutWindowController sharedScout] curSession] == session)
        {
            interval = [[PrefController sharedController] frontFrameBufferUpdateSeconds];
            [[session connection] installMouseMovedTrackingRect];

        }
        else
        {
            interval = [[PrefController sharedController] otherFrameBufferUpdateSeconds];
            [[session connection] removeMouseMovedTrackingRect];
        }
            
        [session setFrameBufferUpdateSeconds: interval];
	}
}

@end
