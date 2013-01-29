//
//  PrefController.m
//  Chicken of the VNC
//
//  Created by Jason Harris on 8/18/04.
//  Copyright 2004 Geekspiff. All rights reserved.
//

#import "PrefController.h"
#import "PrefController_private.h"
#import "ProfileManager.h"
#import "RFBConnectionManager.h"

#import "GrayScaleFrameBuffer.h"
#import "LowColorFrameBuffer.h"
#import "HighColorFrameBuffer.h"
#import "TrueColorFrameBuffer.h"
#import "AppDelegate.h"
#import "ScoutWindowController.h"


// --- Preferences Version --- //
static int const kPrefsVersion = 0x00000002;


@implementation PrefController

#pragma mark Creation and Deletion


+ (void)initialize
{
	NSUserDefaults *defaults;
	NSMutableDictionary *defaultDict;
	NSDictionary *profiles;
	
	defaults = [NSUserDefaults standardUserDefaults];
	defaultDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool: YES],			kPrefs_FullscreenWarning_Key,
		[NSNumber numberWithFloat: 26.0],		kPrefs_AutoscrollIncrement_Key,
		[NSNumber numberWithBool: NO],			kPrefs_FullscreenScrollbars_Key,
		[NSNumber numberWithBool: NO],			kPrefs_UseRendezvous_Key,
		[NSNumber numberWithFloat: 0],			kPrefs_FrontFrameBufferUpdateSeconds_Key,
		[NSNumber numberWithFloat: 4.0],		kPrefs_OtherFrameBufferUpdateSeconds_Key, 
		[NSNumber numberWithBool: NO],			kPrefs_AutoReconnect_Key, 
		[NSNumber numberWithDouble: 30.0],		kPrefs_IntervalBeforeReconnect_Key,
        [NSNumber numberWithBool:NO],           kPrefs_AlwaysUseTunnel,
        [NSNumber numberWithBool:NO],           kPrefs_Scaling,
		nil,									nil];
	
    Profile *defaultProfile = [[Profile alloc] init];
	NSString *profileName = NSLocalizedString(@"defaultProfileName", nil);
    profiles = [NSDictionary dictionaryWithObject: [defaultProfile dictionary]
                                           forKey:profileName];
    [defaultDict setObject: profiles forKey: kPrefs_ConnectionProfiles_Key];
    [defaultProfile release];
	
	[defaults registerDefaults: defaultDict];
    // force defaults
    [[NSUserDefaults standardUserDefaults] setFloat:0 forKey:kPrefs_FrontFrameBufferUpdateSeconds_Key];
    [[NSUserDefaults standardUserDefaults] setFloat:4.0 forKey:kPrefs_OtherFrameBufferUpdateSeconds_Key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}


+ (id)sharedController
{
	static id sInstance = nil;
	if ( ! sInstance )
	{
		sInstance = [[self alloc] init];
		NSParameterAssert( sInstance != nil );
	}
	return sInstance;
}


- (id)init
{
	if ( self = [super init] )
	{
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		int prefsVersion = [[defaults objectForKey: kPrefs_Version_Key] intValue];
		BOOL badPrefsVersion = (kPrefsVersion > prefsVersion);
		if ( 0x00000000 == prefsVersion )
		{
			// update for 2.0b2
			[self _updatePrefs_20b2];
			prefsVersion = 0x00000001;
		}
		if ( 0x00000001 == prefsVersion )
		{
			// some menu items have changed
			[defaults removeObjectForKey: @"KeyEquivalentScenarios"];
//			prefsVersion = 0x00000002;
		}
		
		if ( badPrefsVersion )
			[defaults setObject: [NSNumber numberWithInt: kPrefsVersion] forKey: kPrefs_Version_Key];
	}
	return self;
}


#pragma mark -
#pragma mark Settings


- (BOOL)displayFullScreenWarning
{  return [[[NSUserDefaults standardUserDefaults] objectForKey: kPrefs_FullscreenWarning_Key] boolValue];  }
	
- (void)setDisplayFullScreenWarning:(BOOL)warn
{
    [[NSUserDefaults standardUserDefaults] setBool:warn
                                        forKey:kPrefs_FullscreenWarning_Key];
}

- (float)fullscreenAutoscrollIncrement
{  return [[[NSUserDefaults standardUserDefaults] objectForKey: kPrefs_AutoscrollIncrement_Key] floatValue];  }


- (BOOL)fullscreenHasScrollbars
{  return [[[NSUserDefaults standardUserDefaults] objectForKey: kPrefs_FullscreenScrollbars_Key] boolValue];  }


- (float)frontFrameBufferUpdateSeconds
{  return [[[NSUserDefaults standardUserDefaults] objectForKey: kPrefs_FrontFrameBufferUpdateSeconds_Key] floatValue];  }


- (float)otherFrameBufferUpdateSeconds
{  return [[[NSUserDefaults standardUserDefaults] objectForKey: kPrefs_OtherFrameBufferUpdateSeconds_Key] floatValue];  }


- (void)getLocalPixelFormat:(rfbPixelFormat*)pf
{
    id fbc = [self defaultFrameBufferClass];
    [fbc getPixelFormat:pf];
}

- (float)gammaCorrection
{
	// we won't need this method once we move to a sane way of drawing into our local buffer
	return 1.1;
}


- (id)defaultFrameBufferClass
{
	// we won't need this method once we move to a sane way of drawing into our local buffer
	NSWindowDepth windowDepth = [[NSScreen deepestScreen] depth];
	if( 1 == NSNumberOfColorComponents(NSColorSpaceFromDepth(windowDepth)) )
		return [GrayScaleFrameBuffer class];

	int bpp = NSBitsPerPixelFromDepth( windowDepth );
	if ( bpp <= 8 )
		return [LowColorFrameBuffer class];
	if ( bpp <= 16 )
		return [HighColorFrameBuffer class];
	return [TrueColorFrameBuffer class];
}

- (float)maxPossibleFrameBufferUpdateSeconds;
{
	// this is a bit ugly - our window might not be loaded yet, so if it's not, hardcode the value, yick
//	if ( mWindow )
//		return [mFrontInverseCPUSlider maxValue];
//	return 1;
    return [self otherFrameBufferUpdateSeconds]+1;
}


- (BOOL)usesRendezvous
{  
    return [[NSUserDefaults standardUserDefaults] boolForKey: kPrefs_UseRendezvous_Key];  
}


- (NSDictionary *)hostInfo
{  return [[NSUserDefaults standardUserDefaults] objectForKey: kPrefs_HostInfo_Key];  }


- (void)setHostInfo: (NSDictionary *)dict
{  
    [[NSUserDefaults standardUserDefaults] setObject: dict forKey: kPrefs_HostInfo_Key];  
}


- (NSDictionary *)profileDict
{  return [[NSUserDefaults standardUserDefaults] objectForKey: kPrefs_ConnectionProfiles_Key];  
}


- (NSDictionary *)defaultProfileDict
{
	return [[[[[NSUserDefaults standardUserDefaults] volatileDomainForName: NSRegistrationDomain] objectForKey: kPrefs_ConnectionProfiles_Key] allValues] lastObject];
}


- (void)setProfileDict: (NSDictionary *)dict
{  
    [[NSUserDefaults standardUserDefaults] setObject: dict forKey: kPrefs_ConnectionProfiles_Key];  
}


- (BOOL)autoReconnect
{  
    return [[NSUserDefaults standardUserDefaults] boolForKey: kPrefs_AutoReconnect_Key];  
}


- (NSTimeInterval)intervalBeforeReconnect
{  
    return [[NSUserDefaults standardUserDefaults] floatForKey: kPrefs_IntervalBeforeReconnect_Key];  
}

- (BOOL)defaultShowWarnings
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:kPrefs_NoWarningDialogs];
}

- (void)setNoShowWarning
{
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kPrefs_NoWarningDialogs];
}

- (BOOL)alwaysUseTunnel
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:kPrefs_AlwaysUseTunnel];    
}

- (void)setAlwaysUseTunnel:(BOOL)state
{
    [[NSUserDefaults standardUserDefaults] setBool:state forKey:kPrefs_AlwaysUseTunnel];
    
}

- (BOOL)isScaling
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:kPrefs_Scaling];
}

- (void)setIsScaling:(BOOL)state
{
    [[NSUserDefaults standardUserDefaults] setBool:state forKey:kPrefs_Scaling];
    
}

#pragma mark -
#pragma mark Preferences Window

- (void)showWindow
{
	[self _setupWindow];
	[mWindow makeKeyAndOrderFront: nil];
}

- (IBAction)hideWindow:(id)sender
{
    if(sender)
        [mWindow close];
}

- (void)windowWillClose:(NSNotification *)notification
{
    [[ScoutWindowController sharedScout] performSelectorOnMainThread:@selector(sizeWindow) withObject:nil waitUntilDone:NO];
}

#pragma mark -
#pragma mark Action Methods


- (IBAction)checkScale:(id)sender
{
	BOOL value = ([sender state] == NSOnState) ? YES : NO;
	[[NSUserDefaults standardUserDefaults] setBool:value forKey:kPrefs_Scaling];        
}

- (IBAction)checkTunnel:(id)sender
{
	BOOL value = ([sender state] == NSOnState) ? YES : NO;
	[[NSUserDefaults standardUserDefaults] setBool:value forKey:kPrefs_AlwaysUseTunnel];        
}

- (IBAction)resetWarnings:(id)sender 
{
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:kPrefs_NoWarningDialogs];
    [[NSApp delegate] setNoShowCloseConnect:NO];
    [[NSApp delegate] setNoShowCloseSession:NO];    
}


@end
