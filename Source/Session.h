/* Copyright (C) 1998-2000  Helmut Maierhofer <helmut.maierhofer@chello.at>
 * Copyright 2011 Dustin Cartwright
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
#import "ConnectionWaiter.h"

//@protocol IServerData;

@class RFBConnection;
@class RFBView;
//@class SshTunnel;

@interface Session : NSViewController // <ConnectionWaiterDelegate>
{
    NSWindow *window;       // set to scoutwindowcontroller's window
    
    RFBConnection   *connection;
    NSString    *titleString;

    NSSize _maxSize;

    BOOL	horizontalScroll;
    BOOL	verticalScroll;

    NSString *realDisplayName;
    NSString *host;

    NSScrollView *scrollView;
    RFBView *rfbView;
    NSMutableDictionary *sdict;
}
@property (assign) IBOutlet NSScrollView *scrollView;
@property (assign) IBOutlet RFBView *rfbView;
@property (assign) NSMutableDictionary *sdict;

- (id)initWithConnection:(RFBConnection*)conn sdict:(NSMutableDictionary*)sdict;
- (void)dealloc;

- (RFBConnection *)connection;
- (BOOL)viewOnly;

- (void)setSize:(NSSize)size;
- (void)setDisplayName:(NSString *)aName;
- (void)setupWindow;
- (void)frameBufferUpdateComplete;
- (void)resize:(NSSize)size;

- (void)paste:(id)sender;
- (IBAction)sendPasteboardToServer:(id)sender;
- (void)terminateConnection:(NSString*)aReason;
- (void)authenticationFailed:(NSString *)aReason;
- (void)connectionProblem;
- (IBAction)requestFrameBufferUpdate:(id)sender;

    //window delegate messages
- (void)windowDidBecomeKey;
- (void)windowDidResignKey;
- (void)windowDidDeminiaturize;
- (void)windowDidMiniaturize;
- (void)windowWillClose;
- (void)windowDidResize;
- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize;

- (void)setFrameBufferUpdateSeconds: (float)seconds;

@end
