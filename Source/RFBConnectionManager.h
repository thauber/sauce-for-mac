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

#import <AppKit/AppKit.h>
#import "ServerDataViewController.h"
#import "ConnectionWaiter.h"
#import "LoginController.h"

@class Profile, ProfileManager;
@class RFBConnection;
@class ServerDataViewController;
@protocol IServerData;

// stored in prefs, but not editable in the pref dlg
extern NSString *kUsername;
extern NSString *kAccountkey;
extern NSString *kSessionURL;
extern NSString *kSessionIndx;
extern NSString *kSessionFrame;
extern NSString *kSauceLabsHost;        // fixed host for connection
extern int kPort;

@interface RFBConnectionManager : NSWindowController<ConnectionWaiterDelegate>
{
    NSMutableArray*	sessions;
	ServerDataViewController* mServerCtrler;
	NSArray* mOrderedServerNames;

    ConnectionWaiter    *connectionWaiter;
    BOOL lockedSelection;
}

+ (id)sharedManager;

- (void)wakeup;

- (void)connectToServer;

- (void)connectionSucceeded:(RFBConnection *)conn;
- (void)connectionFailed;
- (void)cancelConnection;

- (void)removeConnection:(id)aConnection;
- (void)connectionDone;

- (NSString*)translateDisplayName:(NSString*)aName forHost:(NSString*)aHost;

- (BOOL)createConnectionWithFileHandle:(NSFileHandle*)file 
    server:(id<IServerData>) server;
- (void)successfulConnection: (RFBConnection *)theConnection;
- (void)setSessionsUpdateIntervals;

@end
