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

#import "Session.h"
#import "AppDelegate.h"
#import "IServerData.h"
#import "FullscreenWindow.h"
#import "KeyEquivalent.h"
#import "KeyEquivalentManager.h"
#import "KeyEquivalentScenario.h"
#import "PrefController.h"
#import "ProfileManager.h"
#import "RFBConnection.h"
#import "RFBConnectionManager.h"
#import "RFBView.h"
#import "SshWaiter.h"
#import "ScoutWindowController.h"
#import "centerclip.h"

#define XK_MISCELLANY
#include "keysymdef.h"

#if MAC_OS_X_VERSION_MAX_ALLOWED < 1050
@interface NSAlert(AvailableInLeopard)
    - (void)setShowsSuppressionButton:(BOOL)flag;
    - (NSButton *)suppressionButton;
@end
#endif


/* Ah, the joy of supporting 4 different releases of the OS */
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1070
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1050
#if __LP64__
typedef long NSInteger;
#else
typedef int NSInteger;
#endif
#endif

@interface NSScrollView(AvailableInLion)
    - (void)setScrollerStyle:(NSInteger)newScrollerStyle;
@end

enum {
    NSScrollerStyleLegacy = 0,
    NSScrollerStyleOverlay = 1
};
#endif

@interface Session(Private)

- (void)startTimerForReconnectSheet;

@end

@implementation Session
@synthesize scrollView;
@synthesize rfbView;

- (id)initWithConnection:(RFBConnection *)aConnection
{
    if ((self = [super initWithNibName:@"RFBConnection" bundle:nil]) == nil)
        return nil;
    
    connection = [aConnection retain];
    
    [self loadView];

    return self;
}

-(void)loadView
{
    [super loadView];
    
    window = [[ScoutWindowController sharedScout] window];

    host = kSauceLabsHost;
    
    _isFullscreen = NO; // jason added for fullscreen display
    
    //    [NSBundle loadNibNamed:@"RFBConnection.nib" owner:self];
    [rfbView registerForDraggedTypes:[NSArray arrayWithObjects:NSStringPboardType, NSFilenamesPboardType, nil]];
    
    _reconnectWaiter = nil;
    _reconnectSheetTimer = nil;
    
    _horizScrollFactor = 0;
    _vertScrollFactor = 0;
    
    /* On 10.7 Lion, the overlay scrollbars don't reappear properly on hover.
     * So, for now, we're going to force legacy scrollbars. */
    if ([scrollView respondsToSelector:@selector(setScrollerStyle:)])
        [scrollView setScrollerStyle:NSScrollerStyleLegacy];
    
    _connectionStartDate = [[NSDate alloc] init];
    
    [connection setSession:self];
    [connection setRfbView:rfbView];
    
    [[SaucePreconnect sharedPreconnect] setSessionInfo:connection view:[self view]];
    [[ScoutWindowController sharedScout] addTabWithView:[self view]];
    
}

- (void)dealloc
{
    [connection setSession:nil];
    [connection release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];

	[titleString release];
	[realDisplayName release];
    [_reconnectSheetTimer invalidate];
    [_reconnectSheetTimer release];
    [_reconnectWaiter cancel];
    [_reconnectWaiter release];

	[optionPanel orderOut:self];
	
    [_connectionStartDate release];
    [super dealloc];
}

- (RFBConnection *)connection
{
    return connection;
}

- (BOOL)viewOnly
{
    return NO;
}

/* Begin a reconnection attempt to the server. */
- (void)beginReconnect
{
    if (sshTunnel) {
        /* Reuse the same SSH tunnel if we have one. */
        _reconnectWaiter = [[SshWaiter alloc] initWithServer:nil
                                                    delegate:self
                                                      window:window
                                                   sshTunnel:sshTunnel];
    } else {
        _reconnectWaiter = [[ConnectionWaiter waiterForServer:nil
                                                     delegate:self
                                                       window:window] retain];
    }
    NSString *templ = NSLocalizedString(@"NoReconnection", nil);
    NSString *err = [NSString stringWithFormat:templ, host];
    [_reconnectWaiter setErrorStr:err];
    [self startTimerForReconnectSheet];
}

- (void)startTimerForReconnectSheet
{
    _reconnectSheetTimer = [[NSTimer scheduledTimerWithTimeInterval:0.5
            target:self selector:@selector(createReconnectSheet:)
            userInfo:nil repeats:NO] retain];
}

- (void)connectionTerminatedSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	/* One might reasonably argue that this should be handled by the connection manager. */
	switch (returnCode) {
		case NSAlertDefaultReturn:
			break;
		case NSAlertAlternateReturn:
            [self beginReconnect];
            return;
		default:
			NSLog(@"Unknown alert returnvalue: %d", returnCode);
			break;
	}
    [[ScoutWindowController sharedScout] performSelectorOnMainThread:@selector(closeTabWithSession:) withObject:self waitUntilDone:NO];
}

- (void)connectionProblem
{
    [connection closeConnection];
    [connection release];
    connection = nil;
    [[ScoutWindowController sharedScout] setCurSession:nil];
}

- (void)endSession
{
    [[ScoutWindowController sharedScout] closeTabWithSession:self];
    [self connectionProblem];
}

/* Some kind of connection failure. ([rda] don't) Decide whether to try to reconnect. */
- (void)terminateConnection:(NSString*)aReason
{
    if (!connection)
        return;

    [self connectionProblem];

    if(aReason) 
    {
        NSTimeInterval timeout = [[PrefController sharedController] intervalBeforeReconnect];
        BOOL supportReconnect = NO;

        [_reconnectReason setStringValue:aReason];
        if (supportReconnect
                && -[_connectionStartDate timeIntervalSinceNow] > timeout) {
            NSLog(@"Automatically reconnecting to server.  The connection was closed because: \"%@\".", aReason);
            // begin reconnect
            [self beginReconnect];
        }
        else {
            // Ask what to do
            NSString *header = NSLocalizedString( @"ConnectionTerminated", nil );
            NSString *okayButton = NSLocalizedString( @"Okay", nil );
            NSString *reconnectButton =  NSLocalizedString( @"Reconnect", nil );
            NSBeginAlertSheet(header, okayButton, supportReconnect ? reconnectButton : nil, nil, window, self, @selector(connectionTerminatedSheetDidEnd:returnCode:contextInfo:), nil, nil, aReason);
        }
    } else 
    {
        [[ScoutWindowController sharedScout] performSelectorOnMainThread:@selector(closeTabWithSession:) withObject:self waitUntilDone:NO];
    }
}

/* Authentication failed: give the user a chance to re-enter password. */
- (void)authenticationFailed:(NSString *)aReason
{
    if (connection == nil)
        return;

    [self connectionProblem];
    [authHeader setStringValue:NSLocalizedString(@"AuthenticationFailed", nil)];
    [authMessage setStringValue: aReason];

}

/* User cancelled chance to enter new password */
- (IBAction)dontReconnect:(id)sender
{
    [self connectionProblem];
    [self endSession];
}

/* Close the connection and then reconnect */
- (IBAction)forceReconnect:(id)sender
{
    if (connection == nil)
        return;

    [self connectionProblem];
    [_reconnectReason setStringValue:@""];

    // Force ourselves to use a new SSH tunnel
    [sshTunnel close];
    [sshTunnel release];
    sshTunnel = nil;

    [self beginReconnect];
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)item
{
    if ([item action] == @selector(forceReconnect:))
        return NO;
    else
        return [self respondsToSelector:[item action]];
}

- (void)setSize:(NSSize)aSize
{
    _maxSize = aSize;
    [[SaucePreconnect sharedPreconnect] setvmsize:aSize];
}

/* Returns the maximum possible size for the window. Also, determines whether or
 * not the scrollbars are necessary. */
- (NSSize)_maxSizeForWindowSize:(NSSize)aSize;
{
    NSRect  winframe;
    NSSize	maxviewsize;

    maxviewsize = _maxSize;
    maxviewsize.height += 91;
    
    horizontalScroll = verticalScroll = NO;
    if(aSize.height<=maxviewsize.height)
    {
        verticalScroll = YES;            
    }

    if(aSize.width<=maxviewsize.width)
    {
        horizontalScroll = YES;
    }
    
    winframe = [[NSScreen mainScreen] visibleFrame];

    winframe = [NSWindow frameRectForContentRect:winframe styleMask:[window styleMask]];

    return winframe.size;
}

/* Sets up window. */
- (void)setupWindow
{
    NSRect wf;
	NSRect screenRect;

    NSRect rr = [rfbView frame];
    rr.origin.x = 0;
    rr.origin.y = 0;
    [rfbView setFrame:rr];
    NSClipView* clipView = [[centerclip alloc] initWithFrame:rr];
    [clipView setAutoresizesSubviews:NO];
    [scrollView setContentView:clipView];
    [clipView release];
    [scrollView setDocumentView:rfbView];
    [scrollView setBackgroundColor:[NSColor colorWithCalibratedWhite:0.6f alpha:1.0]];

    horizontalScroll = verticalScroll = NO;
	screenRect = [[NSScreen mainScreen] visibleFrame];
    wf.origin.x = wf.origin.y = 0;
    wf.size = _maxSize;
    wf.size.height += 91;       // allow for statusbar(26) and tabbar(28) + toolbar(42) minus the 22 for title bar that the next call will add (unless screen is shorter than 876)
    
    wf = [NSWindow frameRectForContentRect:wf styleMask:[window styleMask]];

	if(wf.size.height >  NSHeight(screenRect))
    {
        verticalScroll = YES;
        wf.size.width += 18;    // add scroller size to width
    }
	if(wf.size.width > NSWidth(screenRect))
    {
        horizontalScroll = YES;
    }
    	
	[scrollView setHasHorizontalScroller:horizontalScroll];
	[scrollView setHasVerticalScroller:verticalScroll];


    [window makeFirstResponder:rfbView];
}

- (void)setNewTitle:(id)sender
{
    [titleString release];
    titleString = [[newTitleField stringValue] retain];
}

- (void)setDisplayName:(NSString*)aName
{
	[realDisplayName release];
    realDisplayName = [aName retain];
    [titleString release];
    titleString = [[[RFBConnectionManager sharedManager] translateDisplayName:realDisplayName forHost:host] retain];
}

- (void)frameBufferUpdateComplete
{
}

- (void)resize:(NSSize)size
{
    NSSize  maxSize;
    NSRect  frame;

    // resize window, if necessary
    maxSize = [self _maxSizeForWindowSize:[[window contentView] frame].size];
    frame = [window frame];
    if (frame.size.width > maxSize.width)
        frame.size.width = maxSize.width;
    if (frame.size.height > maxSize.height)
        frame.size.height = maxSize.height;
    [window setFrame:frame display:YES];

    [self windowDidResize]; // setup scroll bars if necessary
}

- (void)requestFrameBufferUpdate:(id)sender
{
    [connection requestFrameBufferUpdate:sender];
}

- (void)sendCmdOptEsc: (id)sender
{
    [connection sendKeyCode: XK_Alt_L pressed: YES];
    [connection sendKeyCode: XK_Meta_L pressed: YES];
    [connection sendKeyCode: XK_Escape pressed: YES];
    [connection sendKeyCode: XK_Escape pressed: NO];
    [connection sendKeyCode: XK_Meta_L pressed: NO];
    [connection sendKeyCode: XK_Alt_L pressed: NO];
    [connection writeBuffer];
}

- (void)sendCtrlAltDel: (id)sender
{
    [connection sendKeyCode: XK_Control_L pressed: YES];
    [connection sendKeyCode: XK_Alt_L pressed: YES];
    [connection sendKeyCode: XK_Delete pressed: YES];
    [connection sendKeyCode: XK_Delete pressed: NO];
    [connection sendKeyCode: XK_Alt_L pressed: NO];
    [connection sendKeyCode: XK_Control_L pressed: NO];
    [connection writeBuffer];
}

- (void)sendPauseKeyCode: (id)sender
{
    [connection sendKeyCode: XK_Pause pressed: YES];
    [connection sendKeyCode: XK_Pause pressed: NO];
    [connection writeBuffer];
}

- (void)sendBreakKeyCode: (id)sender
{
    [connection sendKeyCode: XK_Break pressed: YES];
    [connection sendKeyCode: XK_Break pressed: NO];
    [connection writeBuffer];
}

- (void)sendPrintKeyCode: (id)sender
{
    [connection sendKeyCode: XK_Print pressed: YES];
    [connection sendKeyCode: XK_Print pressed: NO];
    [connection writeBuffer];
}

- (void)sendExecuteKeyCode: (id)sender
{
    [connection sendKeyCode: XK_Execute pressed: YES];
    [connection sendKeyCode: XK_Execute pressed: NO];
    [connection writeBuffer];
}

- (void)sendInsertKeyCode: (id)sender
{
    [connection sendKeyCode: XK_Insert pressed: YES];
    [connection sendKeyCode: XK_Insert pressed: NO];
    [connection writeBuffer];
}

- (void)sendDeleteKeyCode: (id)sender
{
    [connection sendKeyCode: XK_Delete pressed: YES];
    [connection sendKeyCode: XK_Delete pressed: NO];
    [connection writeBuffer];
}

- (void)paste:(id)sender
{
    [connection pasteFromPasteboard:[NSPasteboard generalPasteboard]];
}

- (void)sendPasteboardToServer:(id)sender
{
    [connection sendPasteboardToServer:[NSPasteboard generalPasteboard]];
}

/* --------------------------------------------------------------------------------- */

/* calling these to/from scoutwindowcontroller */
/* Window delegate methods */

- (void)windowDidDeminiaturize
{
    float s = [[PrefController sharedController] otherFrameBufferUpdateSeconds];

    [connection setFrameBufferUpdateSeconds:s];
	[connection installMouseMovedTrackingRect];
}

- (void)windowDidMiniaturize
{
    float s = [[PrefController sharedController] maxPossibleFrameBufferUpdateSeconds];

    [connection setFrameBufferUpdateSeconds:s];
	[connection removeMouseMovedTrackingRect];
}

- (void)windowWillClose
{
    // dealloc closes the window, so we have to null it out here
    // The window will autorelease itself when closed.  If we allow terminateConnection
    // to close it again, it will get double-autoreleased.  Bummer.
    window = NULL;
}

- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize
{
    NSSize max = [self _maxSizeForWindowSize:proposedFrameSize];

    max.width = (proposedFrameSize.width > max.width) ? max.width : proposedFrameSize.width;
    max.height = (proposedFrameSize.height > max.height) ? max.height : proposedFrameSize.height;
    return max;
}

- (void)windowDidResize
{
	[scrollView setHasHorizontalScroller:horizontalScroll];
	[scrollView setHasVerticalScroller:verticalScroll];
}

- (void)windowDidBecomeKey
{
    [[RFBConnectionManager sharedManager] setSessionsUpdateIntervals];
}

- (void)windowDidResignKey
{
    [[RFBConnectionManager sharedManager] setSessionsUpdateIntervals];
	
	//Reset keyboard state on remote end
	[[connection eventFilter] clearAllEmulationStates];
}

- (void)openOptions:(id)sender
{
    [infoField setStringValue: [connection infoString]];
    [statisticField setStringValue:[connection statisticsString]];
    [optionPanel setTitle:titleString];
    [optionPanel makeKeyAndOrderFront:self];
}

- (BOOL)connectionIsFullscreen {
	return NO;
}

- (void)setFrameBufferUpdateSeconds: (float)seconds
{
    // miniaturized windows should keep update seconds set at maximum
    if (![window isMiniaturized])
        [connection setFrameBufferUpdateSeconds:seconds];
}

/* Reconnection attempts */

- (void)createReconnectSheet:(id)sender
{
    [NSApp beginSheet:_reconnectPanel modalForWindow:window
           modalDelegate:self
           didEndSelector:@selector(reconnectEnded:returnCode:contextInfo:)
           contextInfo:nil];
    [_reconnectIndicator startAnimation:self];

    [_reconnectSheetTimer release];
    _reconnectSheetTimer = nil;
}

- (void)reconnectCancelled:(id)sender
{
    [_reconnectWaiter cancel];
    [_reconnectWaiter release];
    _reconnectWaiter = nil;
    [NSApp endSheet:_reconnectPanel];
    [self endSession];
}

- (void)reconnectEnded:(id)sender returnCode:(int)retCode
           contextInfo:(void *)info
{
    [_reconnectPanel orderOut:self];
}

- (void)connectionPrepareForSheet
{
    [NSApp endSheet:_reconnectPanel];
    [_reconnectSheetTimer invalidate];
    [_reconnectSheetTimer release];
    _reconnectSheetTimer = nil;
}

- (void)connectionSheetOver
{
    [self startTimerForReconnectSheet];
}

/* Reconnect attempt has failed */
- (void)connectionFailed
{
    [self endSession];
}

/* Reconnect attempt has succeeded */
- (void)connectionSucceeded:(RFBConnection *)newConnection
{
    [NSApp endSheet:_reconnectPanel];
    [_reconnectSheetTimer invalidate];
    [_reconnectSheetTimer release];
    _reconnectSheetTimer = nil;

    connection = [newConnection retain];
    [connection setSession:self];
    [connection setRfbView:rfbView];
    [connection installMouseMovedTrackingRect];
    if (sshTunnel == nil)
        sshTunnel = [[connection sshTunnel] retain];

    [_connectionStartDate release];
    _connectionStartDate = [[NSDate alloc] init];

    [_reconnectWaiter release];
    _reconnectWaiter = nil;
}

@end
