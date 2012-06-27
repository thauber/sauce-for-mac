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
#import "PSMTabBarControl/PSMTabBarControl.h"
#import "PSMTabBarControl/PSMTabStyle.h"
#import "BugInfoController.h"
#import "SnapProgress.h"
#import "RFBConnectionManager.h"
#import "RFBConnection.h"
#import "Session.h"

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

static ScoutWindowController* _sharedScout = nil;

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
    [tabBar setCellMaxWidth:500];       // allow longer tab labels
    [tabBar setCanCloseOnlyTab:YES];

    // set up add tab button
    [tabBar setShowAddTabButton:YES];
	[[tabBar addTabButton] setTarget:self];
	[[tabBar addTabButton] setAction:@selector(addNewTab:)];

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
    [playstop setSelected:NO forSegment:0];
	switch (returnCode)
    {
		case NSAlertDefaultReturn:
            [self closeTab:nil];
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
    BOOL snap;
    int sel = [sender selectedSegment];
    if(sel==0)      // bug
    {
        [bugcamera setSelected:NO forSegment:0];
        snap = NO;
    }
    else if(sel==1)     // snapshot
    {
        [bugcamera setSelected:NO forSegment:1];
        snap = YES;

    }
    // sheet for title and description
    BugInfoController *bugCtrl = [[BugInfoController alloc] init:snap];
    [[NSApp delegate] setBugCtrlr:bugCtrl];
    [bugCtrl runSheetOnWindow:[self window]];                
}

-(void)submitBug        // after user submits from buginfo sheet
{    
    BugInfoController *bugctrlr = [[NSApp delegate] bugCtrlr];
    if(bugctrlr)
    {
        NSString *title = [[bugctrlr title] stringValue];
        NSString *description = [[bugctrlr description] stringValue];
        self.snapProgress = [[SnapProgress alloc] init];
        [[SaucePreconnect sharedPreconnect] snapshotBug:title desc:description];
    }
}

-(void)snapshotDone
{    
    self.snapProgress = nil;
    [[NSApp delegate] setBugCtrlr:nil];
    [[NSApp delegate] showOptionsIfNoTabs];        // in case last session timed out or internet connection lost
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
    NSString *os = [sdict  objectForKey:@"os"];
    NSString *browser = [sdict objectForKey:@"browser"];
    NSString *bvers = [sdict objectForKey:@"browserVersion"];
    tstr = [NSString stringWithFormat:@"%@/%@%@",os,browser,bvers];

    [toolbar setVisible:YES];
    [bugcamera setEnabled:YES forSegment:0];
    [bugcamera setEnabled:YES forSegment:1];
    [playstop setEnabled:YES forSegment:0];
    
    NSTabViewItem *newItem = [[(NSTabViewItem*)[NSTabViewItem alloc] initWithIdentifier:nil] autorelease];
    [newItem setView:view];
	[newItem setLabel:tstr];
	[tabView addTabViewItem:newItem];
	[tabView selectTabViewItem:newItem];
}

- (IBAction)closeTab:(id)sender 
{
    if(curSession)
    {
        [[SaucePreconnect sharedPreconnect] sessionClosed:[curSession connection]];
        [[RFBConnectionManager sharedManager] removeConnection:[curSession connection]];
        curSession = nil;
    }
	[tabView removeTabViewItem:[tabView selectedTabViewItem]];    
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
    NSDictionary *sdict = [[SaucePreconnect sharedPreconnect] sessionInfo:[tabViewItem view]];
    if(sdict)
    {
        [[self window] setFrame:[[self window] frame] display:NO];  // get scrollbars redone

        NSString *str = [sdict objectForKey:@"size"];
        if(str)
            [self.vmsize setStringValue:str];
                
        str = [sdict objectForKey:@"osbv"];
        [self.osbrowser setStringValue:str];
        [self.osbrowserMsg setStringValue:str];
        
        str = [sdict objectForKey:@"url"];
        [self.urlmsg  setStringValue:str];

        [nowscout setStringValue:@"Now Scouting:"];
        /*
        str = [sdict objectForKey:@"os"];
        
        // get correct image based on os string
        NSImage *img = nil;
        NSArray *arr = [str  componentsSeparatedByString:@" "];
        str = [arr objectAtIndex:0];
        if([str isEqualToString:@"Windows"])
            img = [NSImage imageNamed:@"windows_color.pdf"];
        else if([str isEqualToString:@"Linux"])
            img = [NSImage imageNamed:@"linux_color.pdf"];
        else if([str isEqualToString:@"OSX"])
            img = [NSImage imageNamed:@"linux_color.pdf"];
        if(img)
        {
            [self.osmsg setEnabled:NO];
            [self.osmsg  setImage:img];
        }
        

        str = [sdict objectForKey:@"browser"];        
        // get correct image based on browser string
        if([str isEqualToString:@"iexplore"])
            img = [NSImage imageNamed:@"ie_color.pdf"];
        else if([str isEqualToString:@"firefox"])
            img = [NSImage imageNamed:@"firefox_color.icns"];
        else if([str isEqualToString:@"googlechrome"])
            img = [NSImage imageNamed:@"chrome_color.pdf"];
        else if([str isEqualToString:@"safari"])
            img = [NSImage imageNamed:@"safari_color.icns"];
        else if([str isEqualToString:@"safariproxy"])
            img = [NSImage imageNamed:@"safari_color.icns"];
        else if([str isEqualToString:@"opera"])
            img = [NSImage imageNamed:@"opera_color.pdf"];
        if(img)
        {
            [self.browsermsg setEnabled:NO];
            [self.browsermsg  setImage:img];
        }
        
        str = [sdict objectForKey:@"browserVersion"];
        [self.osbrowser  setStringValue:str];
*/        
        
        
        // use last remaining time value for this session
        str = [sdict objectForKey:@"remainingTime"];
        [self.timeRemainingStat setStringValue:str];

        RFBConnection *rfbcon = [sdict objectForKey:@"connection"];
        curSession = [rfbcon session];
        [[RFBConnectionManager sharedManager] setSessionsUpdateIntervals];
        
        [[self window] display];
    }
}

- (BOOL)tabView:(NSTabView *)aTabView shouldCloseTabViewItem:(NSTabViewItem *)tabViewItem {
    [self doPlayStop:self];
	return NO;
}

- (void)tabView:(NSTabView *)aTabView didCloseTabViewItem:(NSTabViewItem *)tabViewItem 
{
    [[NSApp delegate] showOptionsIfNoTabs];
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
	NSLog(@"didDropTabViewItem: %@ inTabBar: %@", [tabViewItem label], tabBarControl);
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
