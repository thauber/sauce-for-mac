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
#import "SessionController.h"

#define DISPLAY_MAX 50 // numbers >= this are interpreted as a port

@implementation ServerDataViewController

- (id)init
{
	if (self = [super init])
	{		
		selfTerminate = NO;
		removedSaveCheckbox = NO;
		
        connectionWaiter = nil;		
    }
	
	return self;
}

- (id)initWithReleaseOnCloseOrConnect
{
	if (self = [self init])
	{
		selfTerminate = YES;		
	}
	
	return self;
}

- (void)dealloc
{
	
    [connectionWaiter cancel];
    [connectionWaiter release];
	[super dealloc];		
}


- (void)setSuperController:(RFBConnectionManager *)aSuperController
{
    superController = aSuperController;
}

- (void)connectToServer:(NSMutableDictionary*)sdict
{
    // go on to connect
    // Asynchronously creates a connection to the server
    connectionWaiter = [[ConnectionWaiter waiterWithDict:sdict delegate:self] retain];
    if (connectionWaiter == nil)
        [self connectionFailed];
    
}

- (void)cancelConnect: (id)sender
{
    [connectionWaiter cancel];
    [self connectionAttemptEnded];
}

- (void)connectionSucceeded: (RFBConnection *)theConnection
{
    [[RFBConnectionManager sharedManager] successfulConnection:theConnection];

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

@end
