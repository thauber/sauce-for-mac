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

@protocol IServerData;

@class RFBConnection;
@class RFBView;
@class SshTunnel;

@interface Session : NSViewController <ConnectionWaiterDelegate>
{
    NSWindow *window;       // set to scoutwindowcontroller's window

    
    RFBConnection   *connection;
    IBOutlet RFBView *rfbView;
    SshTunnel       *sshTunnel;

    id      newTitleField;
    NSString    *titleString;
    id      statisticField;

    NSSize _maxSize;

    BOOL	horizontalScroll;
    BOOL	verticalScroll;

    id optionPanel;
    id infoField;

    NSString *realDisplayName;
    NSString *host;

    IBOutlet NSTextField *authHeader;
    IBOutlet NSTextField *authMessage;

        // for reconnection attempts
    IBOutlet NSPanel                *_reconnectPanel;
    IBOutlet NSProgressIndicator    *_reconnectIndicator;
    IBOutlet NSTextField            *_reconnectReason;
    NSDate                          *_connectionStartDate;
    NSTimer                         *_reconnectSheetTimer;
    ConnectionWaiter                *_reconnectWaiter;

        // instance variables for managing the fullscreen display
	BOOL _isFullscreen;
	NSTrackingRectTag _leftTrackingTag;
	NSTrackingRectTag _topTrackingTag;
	NSTrackingRectTag _rightTrackingTag;
	NSTrackingRectTag _bottomTrackingTag;
    int         _horizScrollFactor;
    int         _vertScrollFactor;
	NSTimer *_autoscrollTimer;

    NSScrollView *scrollView;
}
@property (assign) IBOutlet NSScrollView *scrollView;

- (id)initWithConnection:(RFBConnection*)conn;
- (void)dealloc;

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
- (IBAction)dontReconnect:(id)sender;
- (IBAction)forceReconnect:(id)sender;

- (IBAction)requestFrameBufferUpdate:(id)sender;

    //window delegate messages
- (void)windowDidBecomeKey:(NSNotification *)aNotification;
- (void)windowDidResignKey:(NSNotification *)aNotification;
- (void)windowDidDeminiaturize:(NSNotification *)aNotification;
- (void)windowDidMiniaturize:(NSNotification *)aNotification;
- (void)windowWillClose:(NSNotification *)aNotification;
- (void)windowDidResize:(NSNotification *)aNotification;
- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize;

- (void)openOptions:(id)sender;

#if 0
- (void)mouseEntered:(NSEvent *)theEvent;
- (void)mouseExited:(NSEvent *)theEvent;
- (void)mouseDragged:(NSEvent *)theEvent;
#endif

- (void)setFrameBufferUpdateSeconds: (float)seconds;

// For reconnect
- (void)createReconnectSheet:(id)sender;
- (IBAction)reconnectCancelled:(id)sender; // returnCode:(int)retCode

@end
