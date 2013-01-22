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
//#import "SshWaiter.h"
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


@implementation Session
@synthesize scrollView;
@synthesize rfbView;
@synthesize sdict;

- (id)initWithConnection:(RFBConnection *)aConnection  sdict:(NSMutableDictionary*)adict
{
    if ((self = [super initWithNibName:@"RFBConnection" bundle:nil]) == nil)
        return nil;
    
    connection = [aConnection retain];
    sdict = adict;
    
    [self loadView];

    return self;
}

-(void)loadView
{
    [super loadView];
    
    window = [[ScoutWindowController sharedScout] window];
    NSRect rr = [rfbView frame];
    rr.origin.x = 0;
    rr.origin.y = 0;
    [rfbView setFrame:rr];
    NSClipView* clipView = [[centerclip alloc] initWithFrame:rr];
    [clipView setAutoresizesSubviews:NO];
    [scrollView setContentView:clipView];
    [clipView release];
    [scrollView setDocumentView:rfbView];
    [scrollView setBackgroundColor:[NSColor colorWithCalibratedWhite:0.5f alpha:1.0]];

    host = kSauceLabsHost;
        
    [rfbView registerForDraggedTypes:[NSArray arrayWithObjects:NSStringPboardType, NSFilenamesPboardType, nil]];
  
    /* On 10.7 Lion, the overlay scrollbars don't reappear properly on hover.
     * So, for now, we're going to force legacy scrollbars. */
    if ([scrollView respondsToSelector:@selector(setScrollerStyle:)])
        [scrollView setScrollerStyle:NSScrollerStyleLegacy];
        
    [connection setSession:self];
    [connection setRfbView:rfbView];
    
    NSMutableDictionary *theDict = [connection sdict];
    [theDict setObject:[self view] forKey:@"view"];
    [theDict setObject:connection forKey:@"connection"];
    [theDict setObject:self forKey:@"session"];
    [[ScoutWindowController sharedScout] addTabWithDict:theDict];
    
}

- (void)dealloc
{
    [connection closeConnection];
    [connection setSession:nil];
    [connection release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];

	[titleString release];
	[realDisplayName release];

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

- (void)connectionProblem
{
    [connection closeConnection];
    [connection release];
    connection = nil;
}

- (void)endSession
{
    [[ScoutWindowController sharedScout] closeTabWithSession:self];
    [self connectionProblem];
}

- (void)terminateConnection:(NSString*)aReason
{
    if (!connection)
        return;

    [self connectionProblem];
    
    // the reason isn't being used, but msg below seems to be extraneous in some cases
    //    NSBeginAlertSheet(@"Connection Ended", @"Ok", nil, nil, [[ScoutWindowController sharedScout] window], self, nil, nil, nil, @"%@", aReason);
    

    [[ScoutWindowController sharedScout] performSelectorOnMainThread:@selector(closeTabWithSession:) withObject:self waitUntilDone:NO];
}

/* Authentication failed: give the user a chance to re-enter password. */
- (void)authenticationFailed:(NSString *)aReason
{
    if (connection == nil)
        return;

    [self connectionProblem];
}

- (void)setSize:(NSSize)aSize
{
    _maxSize = aSize;
}

/* Returns the maximum possible size for the window. Also, determines whether or
 * not the scrollbars are necessary. */
- (NSSize)_maxSizeForWindowSize:(NSSize)aSize;
{
    horizontalScroll = verticalScroll = NO;
    if(![[PrefController sharedController] isScaling])
    {
        NSSize docsz = [[scrollView documentView] frame].size;
        docsz.height += 91;
        if(aSize.height <  docsz.height)
        {
            verticalScroll = YES;
            docsz.width += 18;
        }
        if(aSize.width < docsz.width)
        {
            horizontalScroll = YES;
        }
    }
    [scrollView setHasHorizontalScroller:horizontalScroll];
    [scrollView setHasVerticalScroller:verticalScroll];
    NSPoint pt = NSMakePoint(0.0, [[scrollView documentView] bounds].size.height);   // scroll to top
    [[scrollView documentView] scrollPoint:pt];
    
    [rfbView setFrameBuffer:[rfbView fbuf]];        // get scaling set
    return aSize;
}

/* Sets up window. */
- (void)setupWindow
{
    [self _maxSizeForWindowSize:[scrollView frame].size];
    [window makeFirstResponder:rfbView];
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

- (BOOL)connectionIsFullscreen {
	return NO;
}

- (void)setFrameBufferUpdateSeconds: (float)seconds
{
    // miniaturized windows should keep update seconds set at maximum
    if (![window isMiniaturized])
        [connection setFrameBufferUpdateSeconds:seconds];
}

@end
