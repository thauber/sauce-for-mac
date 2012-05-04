//
//  ServerFromPrefs.h
//  Chicken of the VNC
//
//  Created by Jared McIntyre on Sun May 1 2004.
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//


#import "ServerDataViewController.h"
#import "AppDelegate.h"
#import "ConnectionWaiter.h"
#import "IServerData.h"
#import "ProfileDataManager.h"
#import "ProfileManager.h"
#import "RFBConnectionManager.h"
#import "ServerBase.h"
#import "ServerDataManager.h"
#import "ServerStandAlone.h"
#import "ServerFromPrefs.h"
#import "SshWaiter.h"
#import "SessionController.h"

#define DISPLAY_MAX 50 // numbers >= this are interpreted as a port

@implementation ServerDataViewController

@synthesize cred;

- (id)init
{
	if (self = [super init])
	{
//		[NSBundle loadNibNamed:@"ServerDisplay.nib" owner:self];
		
		selfTerminate = NO;
		removedSaveCheckbox = NO;
		
//		[connectIndicatorText setStringValue:@""];
//		[box setBorderType:NSNoBorder];

        connectionWaiter = nil;
		
/*		[self loadProfileIntoView];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(updateProfileView:)
													 name:ProfileListChangeMsg
												   object:(id)[ProfileDataManager sharedInstance]];
*/	
    }
	
	return self;
}

- (id)initWithServer:(id<IServerData>)server
{
	if (self = [self init])
	{
		[self setServer:server];
	}
	
	return self;
}

- (id)initWithReleaseOnCloseOrConnect
{
	if (self = [self init])
	{
		selfTerminate = YES;
		
		[[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(windowClose:)
                                                     name:NSWindowWillCloseNotification
                                                   object:(id)[self window]];
	}
	
	return self;
}

- (void)dealloc
{
	[(id)mServer release];
//	if( YES == removedSaveCheckbox )
//	{
//		[save release];
//	}
	
    [connectionWaiter cancel];
    [connectionWaiter release];
	[super dealloc];
		
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setServer:(id<IServerData>)server
{
	if( nil != mServer )
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self
														name:ServerChangeMsg
													  object:(id)mServer];
		[(id)mServer autorelease];
	}
	
	mServer = [(id)server retain];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(updateView:)
												 name:ServerChangeMsg
											   object:(id)mServer];
	
//	[self updateView:nil];
}


- (void)setSuperController:(RFBConnectionManager *)aSuperController
{
    superController = aSuperController;
}

- (id<IServerData>)server
{
	return mServer;
}

- (IBAction)connectToServer:(id)sender
{
//    window = superController ? [superController window] : [self window];

    // needed so that any changes being made now are reflected in server

    // go on to connect
    // Asynchronously creates a connection to the server
    connectionWaiter = [[ConnectionWaiter waiterForServer:nil
                                                 delegate:self
                                                   window:nil] retain];
    if (connectionWaiter == nil)
        [self connectionFailed];
    
}

- (IBAction)cancelConnect: (id)sender
{
    [connectionWaiter cancel];
    [self connectionAttemptEnded];
}

- (void)connectionSucceeded: (RFBConnection *)theConnection
{
    [[RFBConnectionManager sharedManager] successfulConnection:theConnection];

//    [superController connectionDone];
    [self connectionAttemptEnded];
}

- (void)connectionFailed
{
    [self connectionAttemptEnded];
}

/* Update the interface to indicate the end of the connection attempt. */
- (void)connectionAttemptEnded
{
    [connectionWaiter release];
    connectionWaiter = nil;    
}

- (void)windowClose:(id)notification
{	
	if([notification object] == [self window])
	{
		if( YES == selfTerminate )
		{
			[self autorelease];
		}
	}
}

@end
