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

#define XK_MISCELLANY
#include <X11/keysymdef.h>

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
    
//    [[NSNotificationCenter defaultCenter] addObserver:self
//                                             selector:@selector(tintChanged:)
//                                                 name:ProfileTintChangedMsg
//                                               object:[connection profile]];
    [self loadView];

    return self;
}

-(void)loadView
{
    [super loadView];
    
    window = [[ScoutWindowController sharedScout] window];

    host = kSauceLabsHost;
    //    sshTunnel = [[connection sshTunnel] retain];
    
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
//    [sshTunnel close];
//    [sshTunnel release];
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
    [[RFBConnectionManager sharedManager] removeConnection:self];
    [[NSApp delegate] performSelectorOnMainThread:@selector(showOptionsIfNoTabs) withObject:nil waitUntilDone:NO];
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
    [sshTunnel close];
    [[RFBConnectionManager sharedManager] removeConnection:self];
    [[ScoutWindowController sharedScout] setCurSession:nil];
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
        [[RFBConnectionManager sharedManager] removeConnection:self];
    }
}

/* Authentication failed: give the user a chance to re-enter password. */
- (void)authenticationFailed:(NSString *)aReason
{
    if (connection == nil)
        return;

//        [self terminateConnection:NSLocalizedString(@"AuthenticationFailed", nil)];

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
        // we only enable Force Reconnect menu item if server supports it
//        return [server_ doYouSupport:CONNECT];
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
    maxviewsize.height += 88;
    
    horizontalScroll = verticalScroll = NO;
    if(aSize.width<maxviewsize.width)
    {
        horizontalScroll = YES;
        maxviewsize.height += 15;
    }

    if(aSize.height<maxviewsize.height)
    {
        verticalScroll = YES;            
        maxviewsize.width += 15;
    }
    
    winframe = [window frame];
    winframe.size = maxviewsize;

    winframe = [NSWindow frameRectForContentRect:winframe styleMask:[window styleMask]];

    return winframe.size;
}

/* Sets up window. */
- (void)setupWindow
{
    NSRect wf;
	NSRect screenRect;
	NSClipView *contentView;
    
    horizontalScroll = verticalScroll = NO;
	screenRect = [[NSScreen mainScreen] visibleFrame];
    if(screenRect.size.height == 874)       // cut off 4 pixies instead of having scrollbars
        screenRect.size.height +=4; // kludge b/c we need a few more pixels than the screen gives us
    wf.origin.x = wf.origin.y = 0;
    wf.size = _maxSize;
    wf.size.height += 88;       // allow for statusbar(26) and tabbar(22) + toolbar(40)
    
    wf = [NSWindow frameRectForContentRect:wf styleMask:[window styleMask]];

	if(wf.size.width > NSWidth(screenRect))
    {
        horizontalScroll = YES;
        wf.size.width = NSWidth(screenRect);
    }
	if(wf.size.height >  NSHeight(screenRect))
    {
        verticalScroll = YES;
        wf.size.height = NSHeight(screenRect);
        wf.size.width += 15;    // add scroller size to width
    }
    
	// According to the Human Interface Guidelines, new windows should be "visually centered"
	// If screenRect is X1,Y1-X2,Y2, and wf is x1,y1 -x2,y2, then
	// the origin (bottom left point of the rect) for wf should be
	// Ox = ((X2-X1)-(x2-x1)) * (1/2)    [I.e., one half screen width less window width]
	// Oy = ((Y2-Y1)-(y2-y1)) * (2/3)    [I.e., two thirds screen height less window height]
	// Then the origin must be offset by the "origin" of the screen rect.
	// Note that while Rects are floats, we seem to have an issue if the origin is
	// not an integer, so we use the floor() function.
	wf.origin.x = floor((NSWidth(screenRect) - NSWidth(wf))/2 + NSMinX(screenRect));
	wf.origin.y = floor((NSHeight(screenRect) - NSHeight(wf))*2/3 + NSMinY(screenRect));
	
	[scrollView setHasHorizontalScroller:horizontalScroll];
	[scrollView setHasVerticalScroller:verticalScroll];
	contentView = [scrollView contentView];
    NSRect fr = [contentView frame];
    fr.size.height = _maxSize.height;
    [contentView setFrame:fr];
    [window setFrame:wf display:NO];

    [window makeFirstResponder:rfbView];
    [window display];
}

- (void)setNewTitle:(id)sender
{
    [titleString release];
    titleString = [[newTitleField stringValue] retain];

//    [[RFBConnectionManager sharedManager] setDisplayNameTranslation:titleString forName:realDisplayName forHost:host];
//    [window setTitle:titleString];
}

- (void)setDisplayName:(NSString*)aName
{
	[realDisplayName release];
    realDisplayName = [aName retain];
    [titleString release];
    titleString = [[[RFBConnectionManager sharedManager] translateDisplayName:realDisplayName forHost:host] retain];
//    [window setTitle:titleString];
}

- (void)frameBufferUpdateComplete
{
//    if ([optionPanel isVisible])
//        [statisticField setStringValue:[connection statisticsString]];
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
//    [self endSession];
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
//    [rfbView setTint:[[connection profile] tintWhenFront:YES]];
}

- (void)windowDidResignKey
{
    [[RFBConnectionManager sharedManager] setSessionsUpdateIntervals];
//    [rfbView setTint:[[connection profile] tintWhenFront:NO]];
	
	//Reset keyboard state on remote end
	[[connection eventFilter] clearAllEmulationStates];
}

- (void)tintChanged:(NSNotification *)notif
{
//    [rfbView setTint:[[connection profile] tintWhenFront:[window isKeyWindow]]];
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

#if 0
- (IBAction)toggleFullscreenMode: (id)sender
{
	_isFullscreen ? [self makeConnectionWindowed: self] : [self makeConnectionFullscreen: self];
}

- (void)mouseEntered:(NSEvent *)theEvent {
	NSTrackingRectTag trackingNumber = [theEvent trackingNumber];

    if (trackingNumber == _leftTrackingTag)
        _horizScrollFactor = -1;
    else if (trackingNumber == _topTrackingTag)
        _vertScrollFactor = +1;
    else if (trackingNumber == _rightTrackingTag)
        _horizScrollFactor = +1;
    else if (trackingNumber == _bottomTrackingTag)
        _vertScrollFactor = -1;
    else
        NSLog(@"Unknown trackingNumber %d", trackingNumber);

//    if ([self connectionIsFullscreen])
        [self beginFullscreenScrolling];
}

- (void)mouseExited:(NSEvent *)theEvent {
	NSTrackingRectTag trackingNumber = [theEvent trackingNumber];

    if (trackingNumber == _leftTrackingTag
            || trackingNumber == _rightTrackingTag) {
        _horizScrollFactor = 0;
        if (_vertScrollFactor == 0)
            [self endFullscreenScrolling];
    } else {
        _vertScrollFactor = 0;
        if (_horizScrollFactor == 0)
            [self endFullscreenScrolling];
    }
}

/* The tracking rectangles don't apply to mouse movement when the button is
 * down. So this method tests mouse drags to see if it should trigger fullscreen
 * scrolling. */
- (void)mouseDragged:(NSEvent *)theEvent
{
//    if (!_isFullscreen)
//        return;
    
    NSPoint pt = [scrollView convertPoint: [theEvent locationInWindow]
                                 fromView:nil];
    NSRect  scrollRect = [scrollView bounds];

    if (pt.x - NSMinX(scrollRect) < kTrackingRectThickness)
        _horizScrollFactor = -1;
    else if (NSMaxX(scrollRect) - pt.x < kTrackingRectThickness)
        _horizScrollFactor = 1;
    else
        _horizScrollFactor = 0;

    if (pt.y - NSMinY(scrollRect) < kTrackingRectThickness)
        _vertScrollFactor = 1;
    else if (NSMaxY(scrollRect) - pt.y < kTrackingRectThickness)
        _vertScrollFactor = -1;
    else
        _vertScrollFactor = 0;

    if (_horizScrollFactor || _vertScrollFactor)
        [self beginFullscreenScrolling];
    else
        [self endFullscreenScrolling];
}
#endif

- (void)setFrameBufferUpdateSeconds: (float)seconds
{
    // miniaturized windows should keep update seconds set at maximum
    if (![window isMiniaturized])
        [connection setFrameBufferUpdateSeconds:seconds];
}

#if 0
- (void)beginFullscreenScrolling {
    if (_autoscrollTimer)
        return;
	_autoscrollTimer = [[NSTimer scheduledTimerWithTimeInterval: kAutoscrollInterval
                                                         target: self
                                                       selector: @selector(scrollFullscreenView:)
                                                       userInfo: nil repeats: YES] retain];
}

- (void)endFullscreenScrolling {
	[_autoscrollTimer invalidate];
	[_autoscrollTimer release];
	_autoscrollTimer = nil;
}

- (void)scrollFullscreenView: (NSTimer *)timer {
	NSClipView *contentView = [scrollView contentView];
	NSPoint origin = [contentView bounds].origin;
	float autoscrollIncrement = [[PrefController sharedController] fullscreenAutoscrollIncrement];
    NSPoint newOrigin = NSMakePoint(origin.x + _horizScrollFactor * autoscrollIncrement, origin.y + _vertScrollFactor * autoscrollIncrement);
    
    newOrigin = [contentView constrainScrollPoint: newOrigin];
    // don't let constrainScrollPoint screw up centering
    if (_horizScrollFactor == 0)
        newOrigin.x = origin.x;
    if (_vertScrollFactor == 0)
        newOrigin.y = origin.y;
    
    [contentView scrollToPoint: newOrigin];
    [scrollView reflectScrolledClipView: contentView];
}
#endif


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
