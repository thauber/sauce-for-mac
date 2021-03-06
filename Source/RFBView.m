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

#import "RFBView.h"
#import "EventFilter.h"
#import "RFBConnection.h"
#import "FrameBuffer.h"
#import "Profile.h"
//#import "RectangleList.h"
#import "AppDelegate.h"
#import "PrefController.h"

@implementation RFBView

@synthesize fbuf;

/* One-time initializer to read the cursors into memory. */
+ (NSCursor *)_cursorForName: (NSString *)name
{
	static NSDictionary *sMapping = nil;
	if ( ! sMapping )
	{
		NSBundle *mainBundle = [NSBundle mainBundle];
		NSDictionary *entries = [NSDictionary dictionaryWithContentsOfFile: [mainBundle pathForResource: @"cursors" ofType: @"plist"]];
		NSParameterAssert( entries != nil );
		sMapping = [[NSMutableDictionary alloc] init];
		NSEnumerator *cursorNameEnumerator = [entries keyEnumerator];
		NSDictionary *cursorName;
		
		while ( cursorName = [cursorNameEnumerator nextObject] )
		{
			NSDictionary *cursorEntry = [entries objectForKey: cursorName];
			NSString *localPath = [cursorEntry objectForKey: @"localPath"];
			NSString *path = [mainBundle pathForResource: localPath ofType: nil];
			NSImage *image = [[NSImage alloc] initWithContentsOfFile: path];
			
			int hotspotX = [[cursorEntry objectForKey: @"hotspotX"] intValue];
			int hotspotY = [[cursorEntry objectForKey: @"hotspotY"] intValue];
			NSPoint hotspot = {hotspotX, hotspotY};
			
			NSCursor *cursor = [[NSCursor alloc] initWithImage: image hotSpot: hotspot];
			[(NSMutableDictionary *)sMapping setObject: cursor forKey: cursorName];
            [cursor release];
            [image release];
		}
	}
	
	return [sMapping objectForKey: name];
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
    return NO;
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (void)setFrameBuffer:(id)aBuffer;
{
    NSRect f = [self frame];

    if(aBuffer != fbuf)
    {
        [fbuf release];
        fbuf = [aBuffer retain];
    }
    NSSize bsize = [aBuffer size];

    f.size = bsize;
    
    if([[PrefController sharedController] isScaling])
    {
        NSRect clip = [[self superview] frame];
        float w = 1;
        if(clip.size.width < bsize.width)
            w = clip.size.width/bsize.width;
        float h = 1;
        if(clip.size.height < bsize.height)
            h = clip.size.height/bsize.height;
        if(w>h)     // keep aspect ratio for vert/horz scaling
            w = h;
        else
            h = w;
        [fbuf setMHScale:w];
        [fbuf setMVScale:h];
        [fbuf setVwWidth:f.size.width];
        [fbuf setVwHeight:f.size.height];
    }
    else
    {
        [fbuf setMHScale:0];
        [fbuf setMVScale:0];
    }
    
    [self setFrame:f];
}

- (void)dealloc
{
    [fbuf release];
    fbuf = nil;
    [_serverCursor release];
    [_modifierCursor release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)setCursorTo: (NSString *)name
{
    [_modifierCursor release];
	if (name == nil)
        _modifierCursor = nil;
    else
        _modifierCursor = [[[self class] _cursorForName: name] retain];
    [[self window] invalidateCursorRectsForView: self];
}

- (void)setServerCursorTo: (NSCursor *)aCursor
{
    [_serverCursor release];
    _serverCursor = [aCursor retain];
    if (!_modifierCursor)
        [[self window] invalidateCursorRectsForView: self];
}

- (void)setTint: (NSColor *)aTint
{
    if (![tint isEqual:aTint]) {
        [tint release];
        tint = [aTint retain];
        drawTint = [tint alphaComponent] != 0.0;
        [self setNeedsDisplay:YES];
    }
}

- (void)setDelegate:(RFBConnection *)delegate
{
    _delegate = delegate;
	_eventFilter = [_delegate eventFilter];
	[self setCursorTo: nil];
	[self setPostsFrameChangedNotifications: YES];
	[[NSNotificationCenter defaultCenter] addObserver: _delegate selector: @selector(viewFrameDidChange:) name: NSViewFrameDidChangeNotification object: self];
}

- (RFBConnection *)delegate
{
	return _delegate;
}

- (void)drawRect:(NSRect)destRect
{
    NSRect          b = [self bounds];
    const NSRect    *rects;
    NSInteger       numRects;
    int             i;    

    [self getRectsBeingDrawn:&rects count:&numRects];
    for (i = 0; i < numRects; i++)
    {
        NSRect      r = rects[i];
        r.origin.y = b.size.height - NSMaxY(r);
        @try 
        {
            [fbuf drawRect:r at:rects[i].origin];
        }
        @catch(id ue) {
            NSLog(@"exception in rfbview:drawRect");
        }
        @catch(...) {
            NSLog(@"non obj-c exception in rfbview:drawRect");
        }
    }
}

/* Called by system to set-up cursors for this view */
- (void)resetCursorRects
{
    if ([_delegate viewOnly])
        return;

    NSRect cursorRect;
    cursorRect = [self visibleRect];
    if (_modifierCursor)
        [self addCursorRect: cursorRect cursor: _modifierCursor];
    else if (_serverCursor)
        [self addCursorRect: cursorRect cursor: _serverCursor];
    else
        [self addCursorRect: cursorRect cursor: [[self class] _cursorForName: @"rfbCursor"]];
}

- (void)mouseDown:(NSEvent *)theEvent
{  [_eventFilter mouseDown: theEvent];  }

- (void)rightMouseDown:(NSEvent *)theEvent
{  [_eventFilter rightMouseDown: theEvent];  }

- (void)otherMouseDown:(NSEvent *)theEvent
{  [_eventFilter otherMouseDown: theEvent];  }

- (void)mouseUp:(NSEvent *)theEvent
{  [_eventFilter mouseUp: theEvent];  }

- (void)rightMouseUp:(NSEvent *)theEvent
{  [_eventFilter rightMouseUp: theEvent];  }

- (void)otherMouseUp:(NSEvent *)theEvent
{  [_eventFilter otherMouseUp: theEvent];  }

- (void)mouseEntered:(NSEvent *)theEvent
{  [[self window] setAcceptsMouseMovedEvents: YES];  }

- (void)mouseExited:(NSEvent *)theEvent
{  [[self window] setAcceptsMouseMovedEvents: NO];  }

- (void)mouseMoved:(NSEvent *)theEvent
{  [_eventFilter mouseMoved: theEvent];  }

- (void)mouseDragged:(NSEvent *)theEvent
{  [_eventFilter mouseDragged: theEvent];
   [_delegate mouseDragged: theEvent];}

- (void)rightMouseDragged:(NSEvent *)theEvent
{  [_eventFilter rightMouseDragged: theEvent];  }

- (void)otherMouseDragged:(NSEvent *)theEvent
{  [_eventFilter otherMouseDragged: theEvent];  }

- (void)scrollWheel:(NSEvent *)theEvent
{  [_eventFilter scrollWheel: theEvent];  }

- (void)keyDown:(NSEvent *)theEvent
{  [_eventFilter keyDown: theEvent];  }

- (void)keyUp:(NSEvent *)theEvent
{  [_eventFilter keyUp: theEvent];  }

- (void)flagsChanged:(NSEvent *)theEvent
{  [_eventFilter flagsChanged: theEvent];  }


- (void)concludeDragOperation:(id <NSDraggingInfo>)sender {}

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
    return NSDragOperationGeneric;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender {}

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{
    return NSDragOperationGeneric;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    return [_delegate pasteFromPasteboard:[sender draggingPasteboard]];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
    return YES;
}

- (void)sendKey:(int)chr  modifier:(int)modifier
{
    [_eventFilter sendKey:chr  modifier:(int)modifier];
}

@end
