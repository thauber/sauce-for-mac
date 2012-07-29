//
//  ScoutWindowController.m
//  PSMTabBarControl
//
//  Created by John Pannell on 4/6/06.
//  Copyright 2006 Positive Spin Media. All rights reserved.
//

#import "ScoutWindowController.h"
#import "LoginController.h"
#import "AppDelegate.h"
#import "PSMTabBar/PSMTabBarControl.h"
#import "PSMTabBar/PSMTabStyle.h"
#import "BugInfoController.h"
#import "SnapProgress.h"
#import "RFBConnectionManager.h"
#import "RFBConnection.h"
#import "Session.h"
#import "HistoryViewController.h"
#import "GradientView.h"

@implementation ScoutWindowController

@synthesize tabView;
@synthesize urlmsg;
@synthesize osbrowserMsg;
@synthesize vmsize;
@synthesize tunnelImage;
@synthesize toolbar;
@synthesize msgBox;
@synthesize statusMessage;
@synthesize timeRemainingStat;
@synthesize userStat;
@synthesize osbrowser;
@synthesize curSession;
@synthesize snapProgress;
@synthesize tunnelButton;
@synthesize hviewCtlr;

static ScoutWindowController* _sharedScout = nil;
NSString *kHistoryTabLabel = @"Session History";

+(ScoutWindowController*)sharedScout
{
	@synchronized([ScoutWindowController class])
	{
		if (!_sharedScout)
        {
			_sharedScout = [[self alloc] init];
        }

		return _sharedScout;
	}
    
	return nil;
}

- (id)init
{
    self=[super initWithWindowNibName:@"scoutwin"];
    if(self)
    {
        //perform any initializations
    }
    return self;
}

- (void)awakeFromNib 
{
    [tabView setTabViewType:NSNoTabsNoBorder];
    [tabBar setStyleNamed:@"Unified"];
    [tabBar setSizeCellsToFit:YES];
    [tabBar setCellMaxWidth:300];       // allow longer tab labels
    [tabBar setCanCloseOnlyTab:NO];

    // set up add tab button
    [tabBar setShowAddTabButton:YES];
	[[tabBar addTabButton] setTarget:self];
	[[tabBar addTabButton] setAction:@selector(addNewTab:)];
    
    NSTabViewItem *newItem = [[(NSTabViewItem*)[NSTabViewItem alloc] initWithIdentifier:nil] autorelease];
    hviewCtlr = [[[HistoryViewController alloc] init] retain];
    [newItem setView:[hviewCtlr view]];
	[newItem setLabel:kHistoryTabLabel];
	[tabView addTabViewItem:newItem];
    
    [msgGradient setNoDraw:YES];    // no draw gradient for now

    [self showWindow:self];
    [[self window] setDelegate:self];
}

- (BOOL)canBecomeKeyWindow
{
    return YES;
}

- (IBAction)doPlayStop:(id)sender
{
    NSString *header = NSLocalizedString( @"Stop Session", nil );
    NSString *okayButton = NSLocalizedString( @"Close session", nil );
    NSString *keepButton =  NSLocalizedString( @"Keep session", nil );
    NSBeginAlertSheet(header, okayButton, keepButton, nil, [self window], self, nil, @selector(stopSessionDidDismiss:returnCode:contextInfo:), nil, @"Do you want to end this session?");
}

- (void)stopSessionDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	/* One might reasonably argue that this should be handled by the connection manager. */
//    [playstop setSelected:NO forSegment:0];
	switch (returnCode)
    {
		case NSAlertDefaultReturn:
            [self closeTab:self];
			return;
		case NSAlertAlternateReturn:
            return;
		default:
			NSLog(@"Unknown alert returnvalue: %d", returnCode);
			break;
	}
}


- (IBAction)doBugCamera:(id)sender
{
//    [bugsnap setState:0];
    // sheet for title and description
    BugInfoController *bugCtrl = [[BugInfoController alloc] init];
    [[NSApp delegate] setBugCtrlr:bugCtrl];
    [bugCtrl runSheetOnWindow:[self window]];
    [bugCtrl release];
}

-(void)submitBug        // after user submits from buginfo sheet
{    
    BugInfoController *bugctrlr = [[NSApp delegate] bugCtrlr];
    if(bugctrlr)
    {
        NSString *title = [[bugctrlr title] stringValue];
        NSString *description = [[[bugctrlr description] textStorage] string];
        self.snapProgress = [[SnapProgress alloc] init];
        [[SaucePreconnect sharedPreconnect] snapshotBug:title desc:description];
    }
}

-(void)snapshotDone
{    
    self.snapProgress = nil;
    [[NSApp delegate] setBugCtrlr:nil];
}

- (void)addBugToHistory:(NSString*)bugUrl
{
    NSTabViewItem *tvi = [tabView selectedTabViewItem];
    [hviewCtlr addSnapbug:[tvi view] bug:bugUrl];
}

- (IBAction)newSession:(id)sender
{
    [[NSApp delegate] showOptionsDlg:nil];
}

- (IBAction)doTunnel:(id)sender
{
    [[NSApp delegate] doTunnel:self]; 
}

-(void)closeAllTabs
{
   while([self tabCount])
       [self closeTab:nil];
}

#pragma mark -
#pragma mark ---- window delegate ----

//window delegate messages
- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
    if(curSession)
        [curSession windowDidBecomeKey];
}

- (void)windowDidResignKey:(NSNotification *)aNotification
{
    if(curSession)
        [curSession windowDidResignKey];    
}

- (void)windowDidDeminiaturize:(NSNotification *)aNotification
{
    if(curSession)
        [curSession windowDidDeminiaturize];    
}

- (void)windowDidMiniaturize:(NSNotification *)aNotification
{    
    if(curSession)
        [curSession windowDidMiniaturize];    
}

- (BOOL)windowShouldClose:(id)sender
{
    [NSApp terminate:nil];
    return NO;
}

- (void)windowWillClose:(NSNotification *)aNotification
{
    if(curSession)
        [curSession windowWillClose];
}

- (void)windowDidResize:(NSNotification *)aNotification
{
   if(curSession)
        [curSession windowDidResize];            
}

- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize
{
    if(curSession)
        return [curSession windowWillResize:sender toSize:proposedFrameSize];
    return proposedFrameSize;
}

#pragma mark -

-(void)toggleToolbar
{
    BOOL vis = [toolbar isVisible];
    [toolbar setVisible:!vis];
}

-(int)tabCount
{
    return[tabView  numberOfTabViewItems];
}

- (IBAction)addNewTab:(id)sender
{
    [self newSession:nil];
}

- (void)addTabWithView:(NSView*)view
{
    NSString *tstr;
    NSDictionary *sdict = [[SaucePreconnect sharedPreconnect] sessionInfo:view];
    NSString *url = [sdict  objectForKey:@"url"];    
    NSString *os = [sdict  objectForKey:@"os"];
    NSString *browser = [sdict objectForKey:@"browser"];
    NSString *bvers = [sdict objectForKey:@"browserVersion"];
    // what attributes?
    NSDictionary *udict = [NSDictionary dictionaryWithObjectsAndKeys:nil];
    NSString *osbrv = [NSString stringWithFormat:@"%C %@/%@%@", 0x00bb, os, browser, bvers];
    NSSize sz = [osbrv sizeWithAttributes:udict];
    float urlwid = 300 - sz.width;
    NSString *truncurl = url;
    sz = [url sizeWithAttributes:udict];
    if(sz.width > urlwid)   // truncate and add '...'
    {
        NSInteger numchars = (urlwid-2)/8 -2;   // guess 8 pixels average for characters
        NSInteger offset = 0;
        if([url hasPrefix:@"http://"])          // remove schema prefix
            offset = 7;
        NSRange rng = NSMakeRange(offset, numchars);
        truncurl = [truncurl substringWithRange:rng];
        truncurl = [truncurl stringByAppendingFormat:@"%C",0x2026];       // add ellipsis
    }
    tstr = [NSString stringWithFormat:@"%@ %@",truncurl, osbrv];

    [toolbar setVisible:YES];
    
    NSTabViewItem *newItem = [[(NSTabViewItem*)[NSTabViewItem alloc] initWithIdentifier:nil] autorelease];
    [newItem setView:view];
	[newItem setLabel:tstr];
	[tabView addTabViewItem:newItem];
	[tabView selectTabViewItem:newItem];
    
    // put info into history view tab0
    NSMutableArray *rarr = [NSMutableArray arrayWithCapacity:0];
    [rarr addObject:@"A"];      // active ('A'/'x')          index = 0
    [rarr addObject:url];       // initial requested url     index = 1
    osbrv = [NSString stringWithFormat:@"%@/%@ %@",os, browser, bvers];
    [rarr addObject:osbrv];      // os/browser/version        index = 2
    NSMutableArray *bdict = [NSMutableArray arrayWithCapacity:0];
    [bdict addObject:[NSNumber numberWithInteger:0]];       // initial popup selection
    [bdict addObject:@"Bugs and Snapshots"]; 
    [rarr addObject:bdict];     // bugs                      index = 3
    int hrs, mins, secs;
    time_t rawtime;
    struct tm *ptm;    
    time(&rawtime);    
    ptm = localtime(&rawtime);
    hrs = ptm->tm_hour;
    mins = ptm->tm_min;
    secs = ptm->tm_sec;
    NSString *timeStr = [NSString stringWithFormat:@"%02d:%02d:%02d",hrs,mins,secs];
    [rarr addObject:timeStr];          // start time          index = 4
    [rarr addObject:@"00:00:00"];      // run time            index = 5
    [rarr addObject:[NSNumber numberWithLong:rawtime]];    // index = 6 start value to compute session run time
    [hviewCtlr addRow:view rowArr:rarr];    
}

- (void)updateHistoryRunTime:(NSView*)view
{
    [hviewCtlr updateRuntime:view];
}

- (IBAction)closeTab:(id)sender 
{
    if(curSession)
    {
        Session *ss = curSession;
        curSession = nil;        
        NSTabViewItem *tvi = [tabView selectedTabViewItem];
        [hviewCtlr updateActive:[tvi view]];
        [[SaucePreconnect sharedPreconnect] sessionClosed:[ss connection]];
        [[RFBConnectionManager sharedManager] cancelConnection];
        [ss  connectionProblem];
        [tabView removeTabViewItem:tvi]; 
    }
}

- (void)closeTabWithSession:(Session*)session
{
    Session *osess = curSession;
    NSView *vv = [session view];
    NSArray *tabitems = [tabView tabViewItems];
    NSInteger numitems = [tabitems count];
    NSTabViewItem *seltvi = [tabView selectedTabViewItem];
    curSession = nil;
    NSTabViewItem *deltvi;
    for(NSInteger i=0;i<numitems;i++)
    {
        NSTabViewItem *tvi = [tabitems objectAtIndex:i];
        if([tvi view] == vv)
        {
            deltvi = tvi;
            break;
        }        
    }
    [tabView selectTabViewItem:deltvi];
    curSession = session;
    [self closeTab:self];
    if(session != osess)
    {
        curSession = osess;
        if(deltvi != seltvi)    // don't select tab we just deleted
            [tabView selectTabViewItem:seltvi];
    }
}

- (void)setTabLabel:(NSString*)lbl
{
	[[tabView selectedTabViewItem] setLabel:lbl];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
	if([menuItem action] == @selector(closeTab:)) {
		if(![tabBar canCloseOnlyTab] && ([tabView numberOfTabViewItems] <= 1)) {
			return NO;
		}
	}
	return YES;
}

- (PSMTabBarControl *)tabBar {
	return tabBar;
}

#pragma mark -
#pragma mark ---- tabview delegate ----

- (void)tabView:(NSTabView *)aTabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem 
{
    NSString *label = [tabViewItem label];
    if( [label isEqualToString:kHistoryTabLabel])      // history tab not a session
    {
        [playstop setEnabled:NO];
        [bugsnap setEnabled:NO];
        [bugsnap setEnabled:NO];
        curSession = nil;
        // hide text in statusbar and messagebox
        [timeRemainingStat setStringValue:@""];
        [vmsize setStringValue:@""];
        [userStat setStringValue:@""];
        [osbrowserMsg setStringValue:@""];        
        [urlmsg  setStringValue:@" "];
        [nowscout setStringValue:@" "];
        [timeRemainingStat setStringValue:@""];
        [osbrowser setStringValue:@""];
        [msgBox needsDisplay];
        [[self window] display];

        return;
    }
    
    NSDictionary *sdict = [[SaucePreconnect sharedPreconnect] sessionInfo:[tabViewItem view]];
    if(sdict)
    {
        [[self window] setFrame:[[self window] frame] display:NO];  // get scrollbars redone

        NSString *str = [sdict objectForKey:@"size"];
        if(str)
            [self.vmsize setStringValue:str];
        str = [sdict objectForKey:@"user"];
            [self.userStat setStringValue:str];
                
        str = [sdict objectForKey:@"osbv"];
        [self.osbrowser setStringValue:str];
        
        NSString *s1, *s2, *s3, *s4;
        NSArray *sarr = [str componentsSeparatedByString:@" "];
        if([str hasPrefix:@"Win"])
        {
            s1 = @"Win";
            if(![[sarr objectAtIndex:2] length])     // assume no version b/c it is googlechrome
            {
                s3 = @"chrome";
                s4 = @"";
            }
            else 
                s4 = [sarr objectAtIndex:2];        // version
            sarr = [[sarr objectAtIndex:1] componentsSeparatedByString:@"/"];
            s2 = [sarr objectAtIndex:0];            // windows year
            if([s2 isEqualToString:@"2003"])
                s2 = @"3";
            else if([s2 isEqualToString:@"2007"])
               s2 = @"7";
            else
               s2 = @"8";
            if(![[sarr objectAtIndex:1] hasPrefix:@"goo"])
            {                
                if([[sarr objectAtIndex:1] hasPrefix:@"ie"])
                    s3 = @"ie";
                else
                    s3 = [sarr objectAtIndex:1];
            }
            str = [NSString stringWithFormat:@"%@ %@ / %@%@",s1,s2,s3,s4];
        }
        else
        {
            if(![[sarr objectAtIndex:1] length])     // assume no version b/c it is googlechrome
            {
                s2 = @"chrome";
                s3 = @"";
            }
            else 
                s3 = [sarr objectAtIndex:1];        // version
            sarr = [[sarr objectAtIndex:0] componentsSeparatedByString:@"/"];
            s1 = [sarr objectAtIndex:0];
            if(![[sarr objectAtIndex:1] hasPrefix:@"goo"])
                s2 = [sarr objectAtIndex:1];
            str = [NSString stringWithFormat:@"%@ / %@%@",s1,s2,s3];
        }                                 
        [self.osbrowserMsg setStringValue:str];
        
        str = [sdict objectForKey:@"url"];
        [self.urlmsg  setStringValue:str];

        [nowscout setStringValue:@"Now Scouting:"];        
                
        // use last remaining time value for this session
        str = [sdict objectForKey:@"remainingTime"];
        [self.timeRemainingStat setStringValue:str];

        RFBConnection *rfbcon = [sdict objectForKey:@"connection"];
        curSession = [rfbcon session];
        [[RFBConnectionManager sharedManager] setSessionsUpdateIntervals];
        
        [bugsnap setEnabled:YES];
        [bugsnap setEnabled:YES];
        [playstop setEnabled:YES];

        [[self window] display];
    }
}

- (BOOL)tabView:(NSTabView *)aTabView shouldCloseTabViewItem:(NSTabViewItem *)tabViewItem
{
    NSString *label = [tabViewItem label];
    if( [label isEqualToString:kHistoryTabLabel])      // can't close history tab
        return NO;
    [aTabView selectTabViewItem:tabViewItem];
    [self doPlayStop:self];
	return NO;
}

- (void)tabView:(NSTabView *)aTabView didCloseTabViewItem:(NSTabViewItem *)tabViewItem 
{
}

- (NSArray *)allowedDraggedTypesForTabView:(NSTabView *)aTabView {
	return [NSArray arrayWithObjects:NSFilenamesPboardType, NSStringPboardType, nil];
}

- (void)tabView:(NSTabView *)aTabView acceptedDraggingInfo:(id <NSDraggingInfo>)draggingInfo onTabViewItem:(NSTabViewItem *)tabViewItem {
	NSLog(@"acceptedDraggingInfo: %@ onTabViewItem: %@", [[draggingInfo draggingPasteboard] stringForType:[[[draggingInfo draggingPasteboard] types] objectAtIndex:0]], [tabViewItem label]);
}

- (NSMenu *)tabView:(NSTabView *)aTabView menuForTabViewItem:(NSTabViewItem *)tabViewItem 
{
	return nil;
}

- (BOOL)tabView:(NSTabView*)aTabView shouldDragTabViewItem:(NSTabViewItem *)tabViewItem fromTabBar:(PSMTabBarControl *)tabBarControl 
{
	return YES;
}

- (BOOL)tabView:(NSTabView*)aTabView shouldDropTabViewItem:(NSTabViewItem *)tabViewItem inTabBar:(PSMTabBarControl *)tabBarControl 
{
	return YES;
}

- (void)tabView:(NSTabView*)aTabView didDropTabViewItem:(NSTabViewItem *)tabViewItem inTabBar:(PSMTabBarControl *)tabBarControl 
{
}

- (NSImage *)tabView:(NSTabView *)aTabView imageForTabViewItem:(NSTabViewItem *)tabViewItem offset:(NSSize *)offset styleMask:(NSUInteger *)styleMask 
{
	// grabs whole window image
	NSImage *viewImage = [[[NSImage alloc] init] autorelease];
	NSRect contentFrame = [[[self window] contentView] frame];
	[[[self window] contentView] lockFocus];
	NSBitmapImageRep *viewRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:contentFrame] autorelease];
	[viewImage addRepresentation:viewRep];
	[[[self window] contentView] unlockFocus];

	// grabs snapshot of dragged tabViewItem's view (represents content being dragged)
	NSView *viewForImage = [tabViewItem view];
	NSRect viewRect = [viewForImage frame];
	NSImage *tabViewImage = [[[NSImage alloc] initWithSize:viewRect.size] autorelease];
	[tabViewImage lockFocus];
	[viewForImage drawRect:[viewForImage bounds]];
	[tabViewImage unlockFocus];

	[viewImage lockFocus];
	NSPoint tabOrigin = [tabView frame].origin;
	tabOrigin.x += 10;
	tabOrigin.y += 13;
	[tabViewImage compositeToPoint:tabOrigin operation:NSCompositeSourceOver];
	[viewImage unlockFocus];

	//draw over where the tab bar would usually be
	NSRect tabFrame = [tabBar frame];
	[viewImage lockFocus];
	[[NSColor windowBackgroundColor] set];
	NSRectFill(tabFrame);
	//draw the background flipped, which is actually the right way up
	NSAffineTransform *transform = [NSAffineTransform transform];
	[transform scaleXBy:1.0 yBy:-1.0];
	[transform concat];
	tabFrame.origin.y = -tabFrame.origin.y - tabFrame.size.height;
	[(id < PSMTabStyle >)[(PSMTabBarControl*)[aTabView delegate] style] drawBackgroundInRect:tabFrame];
	[transform invert];
	[transform concat];

	[viewImage unlockFocus];

	if([(PSMTabBarControl *)[aTabView delegate] orientation] == PSMTabBarHorizontalOrientation) {
		offset->width = [(id < PSMTabStyle >)[(PSMTabBarControl*)[aTabView delegate] style] leftMarginForTabBarControl];
		offset->height = 22;
	} else {
		offset->width = 0;
		offset->height = 22 + [(id < PSMTabStyle >)[(PSMTabBarControl*)[aTabView delegate] style] leftMarginForTabBarControl];
	}

	if(styleMask) {
		*styleMask = NSTitledWindowMask | NSTexturedBackgroundWindowMask;
	}

	return viewImage;
}

- (PSMTabBarControl *)tabView:(NSTabView *)aTabView newTabBarForDraggedTabViewItem:(NSTabViewItem *)tabViewItem atPoint:(NSPoint)point 
{
	NSLog(@"newTabBarForDraggedTabViewItem: %@ atPoint: %@", [tabViewItem label], NSStringFromPoint(point));
    return nil;
}

- (void)tabView:(NSTabView *)aTabView closeWindowForLastTabViewItem:(NSTabViewItem *)tabViewItem 
{
	NSLog(@"closeWindowForLastTabViewItem: %@", [tabViewItem label]);
	[[self window] close];
}

- (void)tabView:(NSTabView *)aTabView tabBarDidHide:(PSMTabBarControl *)tabBarControl 
{
}

- (void)tabView:(NSTabView *)aTabView tabBarDidUnhide:(PSMTabBarControl *)tabBarContro
{
}

- (NSString *)tabView:(NSTabView *)aTabView toolTipForTabViewItem:(NSTabViewItem *)tabViewItem 
{
	return [tabViewItem label];
}

- (NSString *)accessibilityStringForTabView:(NSTabView *)aTabView objectCount:(NSInteger)objectCount 
{
	return (objectCount == 1) ? @"item" : @"items";
}

- (void)tunnelConnected:(BOOL)is     // tunnel is ready to use
{    
    NSImage *img;
    if(is)
    {
        img = [NSImage imageNamed:@"dotgreen.png"];
        [tunnelImage setToolTip:@"Tunnel connected"];
    }
    else
    {
        img = [NSImage imageNamed:@"dotred.png"];
        [tunnelImage setToolTip:@"Tunnel not connected"];
    }
    
    [tunnelImage setImage:img];
    [img release];
}

@end
