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

#import "KeyChain.h"
#import "RFBConnectionManager.h"
#import "RFBConnection.h"
#import "ConnectionWaiter.h"
//#import "ListenerController.h"
#import "PersistentServer.h"
#import "PrefController.h"
#import "ProfileManager.h"
#import "Profile.h"
#import "rfbproto.h"
#import "vncauth.h"
#import "ServerDataViewController.h"
#import "ServerFromPrefs.h"
#import "ServerStandAlone.h"
#import "ServerDataManager.h"
#import "Session.h"
#import "SessionController.h"
#import "SaucePreconnect.h"
#import "AppDelegate.h"
#import "ScoutWindowController.h"

NSString *kUsername = @"username";
NSString *kAccountkey = @"accountkey";
NSString *kSessionURL = @"sessionURL";
NSString *kSessionIndx = @"sessionIndx";
NSString *kSessionFrame = @"sessionFrame";
NSString *kSauceLabsHost = @"tv1.saucelabs.com";    // fixed host for connection
int kPort = 5901;                                   // fixed port for connection


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

    /* Also, during termination, ServerDataManager needs to save, but it needs
     * to hapeen after we make our changes. Thus, it is triggered here instead
     * of ServerDataManager having its own notification. */
    [[ServerDataManager sharedInstance] save];

	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)reloadServerArray
{
    ServerDataManager   *manager = [ServerDataManager sharedInstance];
    [mOrderedServerNames release];
    mOrderedServerNames = [[manager sortedServerNames] retain];
}

- (void)wakeup
{
	mOrderedServerNames = nil;
	[self reloadServerArray];
	
	mServerCtrler = [[ServerDataViewController alloc] init];

    signal(SIGPIPE, SIG_IGN);
    sessions = [[NSMutableArray alloc] init];

    [mServerCtrler setSuperController: self];

}

- (void)connectToServer     // called after login and user options dialogs
{
    [mServerCtrler connectToServer:self];
}

/* Connection initiated from the command-line succeeded */
- (void)connectionSucceeded:(RFBConnection *)conn
{
    [self successfulConnection:conn];
}

- (void)connectionFailed
{
}

- (void)cancelConnection
{
    if(mServerCtrler)
        [mServerCtrler cancelConnect:self];
}


// We're done with the connecting to a server with the dialog
- (void)connectionDone
{
}

- (NSString*)translateDisplayName:(NSString*)aName forHost:(NSString*)aHost
{
    return @"Sauce Labs";
}


- (void)removeConnection:(id)aConnection
{
    [aConnection retain];
    [sessions removeObject:aConnection];
    [[SaucePreconnect sharedPreconnect] sessionClosed:aConnection];
    [aConnection autorelease];
}

/* Creates a connection from an already connected file handle */
- (BOOL)createConnectionWithFileHandle:(NSFileHandle*)file server:(id<IServerData>) server
{
	/* change */
    RFBConnection* theConnection;

    theConnection = [[RFBConnection alloc] initWithFileHandle:file server:server];
    if(theConnection) {
        [self successfulConnection:theConnection];
        [theConnection release];
        return YES;
    }
    else {
        return NO;
    }
}

/* Registers a successful connection using an already-created RFBConnection
 * object. */
- (void)successfulConnection: (RFBConnection *)theConnection
{
    [[NSApp delegate] connectionSucceeded]; 
    Session *sess = [[Session alloc] initWithConnection:theConnection];
    [sessions addObject:sess];
    [sess release];
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
