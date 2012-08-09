//
//  SessionController.m
//  scout-desktop
//
//  Created by ackerman dudley on 4/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "SessionController.h"
#import "SaucePreconnect.h"
#import "RFBConnectionManager.h"
#import "ScoutWindowController.h"
#import "AppDelegate.h"
#import "OptionBox.h"
#import "RegexKitLite.h"

@implementation SessionController

@synthesize defaultBrowser;
@synthesize panel;
@synthesize view;
@synthesize connectBtn;
@synthesize connectIndicatorText;
@synthesize connectIndicator;
@synthesize url;

- (id)init
{
    self = [super init];
    if(self)
    {
        [NSBundle loadNibNamed:@"SessionController"  owner:self];
    }
    return self;
}

-(void)runSheet
{
    // use last used values from prefs
    NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
    [[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(textDidChange:) name: NSTextDidChangeNotification object: nil];
    curTabIndx = [defs integerForKey:kCurTab];
    sessionIndxs[tt_windows] = [defs integerForKey:kSessionIndxWin];
    sessionIndxs[tt_linux] =   [defs integerForKey:kSessionIndxLnx];
    sessionIndxs[tt_apple] =   [defs integerForKey:kSessionIndxMac];
    sessionIndxs[tt_mobile] =  [defs integerForKey:kSessionIndxMbl];
    
    NSString *urlstr = [defs stringForKey:kSessionURL];
    if(urlstr)
        [self.url setStringValue:urlstr];
    else        // never connected
    {
        [connectBtn setEnabled:NO];
        sessionIndxs[curTabIndx] = 6;           // default is firefox 9    
    }

    [self setupFromConfig];
    
    [browserTbl setDoubleAction:@selector(doDoubleClick:)];
    [connectBtn setTitle:@"Navigate"];
    [connectBtn setAction: @selector(connect:)];
    [connectBtn setKeyEquivalent:@"\r"];
    [connectBtn setKeyEquivalentModifierMask:0]; 
    [connectBtn setState:NSOnState];
    [connectIndicator stopAnimation:self];
    [connectIndicatorText setStringValue:@""];
        
    [NSApp beginSheet:panel modalForWindow:[[ScoutWindowController sharedScout] window] modalDelegate:self  didEndSelector:nil   contextInfo:nil];

    // size column 0 row heights
    NSMatrix *mm = [browserTbl matrixInColumn:0];
    NSSize sz = [mm cellSize];
    sz.height = 40;
    [mm setCellSize:sz];
    sz.width=0; sz.height = 8;
    [mm setIntercellSpacing:sz];
    [mm sizeToCells];
        
    [browserTbl selectRow:curTabIndx inColumn:0];
    [self doBrowserClick:nil];      // set browser cells height
    [browserTbl selectRow:sessionIndxs[curTabIndx] inColumn:1];
    lastpop1 = NO;

}

- (NSInteger)hoverIndx
{
    return hoverIndx;
}

// read config to get os/browsers; create rects; store it all
- (void)setupFromConfig
{
    [self readConfig];      // fill config arrays with data from config file
    
    // create attributed strings for os's (column 0)    
    // os images
    NSImage *oimgs[4];
    NSSize isz = NSMakeSize(40,40);
    NSString *path = [[NSBundle mainBundle] pathForResource:@"windows_color" ofType:@"pdf"];
    oimgs[0] = [[NSImage alloc] initByReferencingFile:path];
    [oimgs[0] setSize:isz];
    path = [[NSBundle mainBundle] pathForResource:@"linux_color" ofType:@"pdf"];
    oimgs[1] = [[NSImage alloc] initByReferencingFile:path];
    [oimgs[1] setSize:isz];
    path = [[NSBundle mainBundle] pathForResource:@"apple_color" ofType:@"pdf"];
    oimgs[2] = [[NSImage alloc] initByReferencingFile:path];
    [oimgs[2] setSize:isz];
    path = [[NSBundle mainBundle] pathForResource:@"apple_color" ofType:@"pdf"];
    oimgs[3] = [[NSImage alloc] initByReferencingFile:path];
    [oimgs[3] setSize:isz];
    
    NSString *osStr[4] = {@"Windows", @"Linux", @"Mac", @"Mobile"};

    for(int i=0; i < 2; i++)
    {
        NSTextAttachment* ta = [[NSTextAttachment alloc] init];
        NSTextAttachmentCell* tac = [[NSTextAttachmentCell alloc] init];
        [tac setImage: oimgs[i]];
        [oimgs[i] release];
        [ta setAttachmentCell: tac];
        NSAttributedString* as = [NSAttributedString attributedStringWithAttachment: ta];
        [ta release];
        [tac release];
        // NSBaselineOffsetAttributeName
        NSNumber *nn = [NSNumber numberWithInteger:8]; 
        NSDictionary *asdict = [NSDictionary dictionaryWithObjectsAndKeys:nn,NSBaselineOffsetAttributeName, nil];
        NSMutableAttributedString* mas = [[[NSMutableAttributedString alloc] initWithAttributedString:as ] retain];    
        NSAttributedString *osAStr = [[NSAttributedString alloc] initWithString:osStr[i] attributes:asdict]; 
        [mas appendAttributedString: osAStr];
        [osAStr release];
        osAStrs[i] = mas;
     }

    // browser images for column 1    
    NSImage *bimgs[5];
    isz = NSMakeSize(18,18);
    path = [[NSBundle mainBundle] pathForResource:@"ie_color" ofType:@"pdf"];
    bimgs[0] = [[[NSImage alloc] initByReferencingFile:path] autorelease];
    [bimgs[0] setSize:isz];
    path = [[NSBundle mainBundle] pathForResource:@"firefox_color" ofType:@"icns"];
    bimgs[1] = [[[NSImage alloc] initByReferencingFile:path] autorelease];
    [bimgs[1] setSize:isz];
    path = [[NSBundle mainBundle] pathForResource:@"safari_color" ofType:@"icns"];
    bimgs[2] = [[[NSImage alloc] initByReferencingFile:path] autorelease];
    [bimgs[2] setSize:isz];
    path = [[NSBundle mainBundle] pathForResource:@"opera_color" ofType:@"pdf"];
    bimgs[3] = [[[NSImage alloc] initByReferencingFile:path] autorelease];
    [bimgs[3] setSize:isz];
    path = [[NSBundle mainBundle] pathForResource:@"chrome_color" ofType:@"pdf"];
    bimgs[4] = [[[NSImage alloc] initByReferencingFile:path] autorelease];
    [bimgs[4] setSize:isz];
        
    NSMutableArray *configArr;
    NSMutableArray *brAStrs;
    
    for(int i=0; i < 2; i++)    // setup browsers for each os
    {
        switch(i)
        {
            case tt_windows: 
                brAStrsWindows = [[[NSMutableArray alloc] init] retain];     // os/browsers for windows
                brAStrs = brAStrsWindows;
                configArr = configWindows; 
                break;
            case tt_linux:   
                brAStrsLinux = [[[NSMutableArray alloc] init] retain];     // os/browsers for windows
                brAStrs = brAStrsLinux;
                configArr = configLinux; break;
            case tt_apple:  break;
            case tt_mobile: break;
        }
        NSInteger num = [configArr count];

        NSString *lastBrowser = @"ie";      // initial column
        NSImage *bimg = bimgs[0];

        for(NSInteger i=0;i < num; i++)     // setup browsers
        {
            NSArray *llArr = [configArr objectAtIndex:i];
            NSString *osstr = [llArr objectAtIndex:0];
            NSString *browser = [llArr objectAtIndex:1];
            NSString *version = [llArr objectAtIndex:2];
            NSString *twoch = [browser substringToIndex:2];     // 2 chars to identify browser
            if(![twoch isEqualToString:lastBrowser])            // different browser than previous
            {            
                if([twoch isEqualToString:@"ie"])         // internet explorer
                    bimg = bimgs[0];
                if([twoch isEqualToString:@"fi"])         // firefox
                    bimg = bimgs[1];
                else if([twoch isEqualToString:@"sa"])    // safari
                    bimg = bimgs[2];
                else if([twoch isEqualToString:@"op"])    // opera
                    bimg = bimgs[3];
                else if([twoch isEqualToString:@"go"])    // google chrome
                    bimg = bimgs[4];
                lastBrowser = [browser substringToIndex:2];
            }

            NSTextAttachment* ta = [[NSTextAttachment alloc] init];
            NSTextAttachmentCell* tac = [[NSTextAttachmentCell alloc] init];
            [tac setImage: bimg];
            [ta setAttachmentCell: tac];
            NSAttributedString* as = [NSAttributedString attributedStringWithAttachment: ta];
            [ta release];
            [tac release];
            NSMutableAttributedString* mas = [[NSMutableAttributedString alloc] initWithAttributedString: as];
            NSString *winver = @"";     // windows version
            if(configArr == configWindows)
            {
                winver = [[osstr componentsSeparatedByString:@" "] objectAtIndex:1];
            }
            browser = [browser capitalizedString];
            NSString *brver = [NSString stringWithFormat:@" %@ %@",browser, version];
            NSNumber *nn = [NSNumber numberWithInteger:6]; 
            NSDictionary *asdict = [NSDictionary dictionaryWithObjectsAndKeys:nn,NSBaselineOffsetAttributeName, nil];
            NSAttributedString *bAStr = [[NSAttributedString alloc] initWithString:brver attributes:asdict]; 
            [mas appendAttributedString:bAStr];
            [bAStr release];
            [brAStrs addObject:mas];
        }
    }

}


-(void)terminateApp
{
    [NSApp endSheet:panel];
    [panel orderOut:nil];
    [[NSApp delegate] setOptionsCtrlr:nil];
}

- (IBAction)performClose:(id)sender
{
    [[SaucePreconnect sharedPreconnect] setErrStr:nil];
    [[NSApp delegate] cancelOptionsConnect:self];
}

-(void)quitSheet
{
    [NSApp endSheet:panel];
    [panel orderOut:nil];    
}

- (void)textDidChange:(NSNotification *)aNotification
{
    BOOL bchars = [[url stringValue] length] ? YES : NO;
    [connectBtn setEnabled:bchars];
}

-(IBAction)connect:(id)sender 
{        
    NSInteger rr = [browserTbl selectedRowInColumn:1];
    NSArray *brarr;
    switch(curTabIndx)
    {
        case tt_windows: brarr = [configWindows objectAtIndex:rr]; break;
        case tt_linux: brarr = [configLinux objectAtIndex:rr]; break;
        case tt_apple:
        case tt_mobile: return;     // TODO: not implemented, yet
    }
    NSString *os      = [brarr objectAtIndex:0];
    NSString *browser = [brarr objectAtIndex:1];
    NSString *version = [brarr objectAtIndex:2];

    if([version isEqualToString:@"*"])
        version = @"";
    NSString *urlstr = [self.url stringValue];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:urlstr  forKey:kSessionURL];
    [defaults setInteger:curTabIndx forKey:kCurTab];
    // save selected browser for all os's
    [defaults setInteger:sessionIndxs[tt_windows] forKey:kSessionIndxWin];
    [defaults setInteger:sessionIndxs[tt_linux] forKey:kSessionIndxLnx];
    [defaults setInteger:sessionIndxs[tt_apple] forKey:kSessionIndxMac];
    [defaults setInteger:sessionIndxs[tt_mobile] forKey:kSessionIndxMbl];

    [[SaucePreconnect sharedPreconnect] setOptions:os browser:browser browserVersion:version url:urlstr];
    [NSApp endSheet:panel];

    NSURL *uurl = [NSURL URLWithString:urlstr];
    BOOL noTunnel = [[NSApp delegate] noTunnel];
    if(uurl && !noTunnel && ![urlstr hasPrefix:@"www."])        // check for localhost
    {
        NSString *uhost = [uurl host];
        BOOL isLocalURL = ![uhost length] || [uhost isEqualToString:@"localhost"] || [uhost isEqualToString:@"127.0.0.1"];
        isLocalURL = isLocalURL || [uhost hasPrefix:@"192.168."] || [uhost hasPrefix:@"10."];
        if(![[NSApp delegate] tunnelCtrlr] && isLocalURL)       // prompt for opening tunnel
        {
            if(![uhost length] || [self canReachIP:uhost])
            {
                NSBeginAlertSheet(@"Requires Intranet Access", @"Yes", @"No", nil, [NSApp keyWindow], self,nil, @selector(tunnelDidDismiss:returnCode:contextInfo:), NULL, @"Do you want to start Sauce Connect?"); 
            }
            else {
                NSBeginAlertSheet(@"Can't Reach IP", @"Okay", nil, nil, [NSApp keyWindow], self,nil, nil, NULL, @"Check connection and IP address"); 
            }
        }
        else 
            [self startConnecting];
    }
    else 
        [self startConnecting];
}

- (void)tunnelDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    switch (returnCode)
    {
        case NSAlertDefaultReturn:
            [[NSApp delegate] doTunnel:self];
            return;
        case NSAlertAlternateReturn:
            [[NSApp delegate] setNoTunnel:YES];
            [self startConnecting];
            return;
        case NSAlertOtherReturn:
            [self runSheet];
            return;
    }
}

-(BOOL)canReachIP:(NSString*)host
{
    NSTask *ftask = [[[NSTask alloc] init] autorelease];
    NSPipe *fpipe = [NSPipe pipe];
    [ftask setStandardOutput:fpipe];
    [ftask setStandardError:fpipe];
    [ftask setLaunchPath:@"/bin/bash"];
    NSString *arg = [NSString stringWithFormat:@"ping %@",host];
    [ftask setArguments:[NSArray arrayWithObjects:@"-c", arg, nil]];
    NSFileHandle *fhand = [fpipe fileHandleForReading];        
    [ftask launch];
    while(10)       // just a guess to give enough attempts to get yes/no result
    {
        NSData *data = [fhand availableData];		 
        NSString *retStr = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
        if([retStr length])
        {
            unichar ch = [retStr characterAtIndex:0];
            if(ch >= '1' && ch <= '9')
                return YES;
            if(ch == 'R')      // Request timeout
                return NO;
            else
            {
                NSRange r = [retStr rangeOfString:@"down"];
                if(r.location != NSNotFound)
                    return NO;
            }
        }
    }
    return NO;
}
   
- (void)startConnecting
{
    [connectBtn setState:NSOffState];
    [url setEnabled:NO];
    [connectIndicator startAnimation:self];
    [connectIndicatorText setStringValue:@"Connecting..."];
    
    [connectIndicatorText display];
    [connectBtn setAction:@selector(performClose:)];
    [connectBtn setTitle:@"Cancel"];
    [NSThread detachNewThreadSelector:@selector(preAuthorize:) toTarget:[SaucePreconnect sharedPreconnect] withObject:nil];
}
                                  
-(void)connectionSucceeded
{
    [panel orderOut:nil];
}

- (void)showError:(NSString *)errStr
{
    NSBeginAlertSheet(@"Session Options Error", @"Okay", nil, nil, [NSApp keyWindow], self,nil,     
                      NULL, NULL, errStr);    
}


// read data in config file into a dictionary
// NB:  assumes no curly braces wrapping the lines; 
//      assumes sorted by os, and all the same browsers for an os are grouped together
- (void)readConfig
{
    configOSX     = [[[NSMutableArray alloc] init] retain];     // os/browsers for osx
    configWindows = [[[NSMutableArray alloc] init] retain];     // os/browsers for windows
    configLinux   = [[[NSMutableArray alloc] init] retain];     // os/browsers for linux

    NSString *path = [[NSBundle mainBundle] pathForResource:@"scout" ofType:@"conf"];
    NSData *fdata = [[NSFileManager defaultManager] contentsAtPath:path];
    NSString *jsonStr = [[NSString alloc] initWithData:fdata encoding:NSUTF8StringEncoding];
    // pull out the lines into an array
    NSArray *linesArr = [jsonStr arrayOfCaptureComponentsMatchedByRegex:@"\\{(.*?)\\}"];
    [jsonStr release];
    NSString *osStr, *ll;
    NSString *browser;
    NSString *version;
    NSString *active;
    for(NSArray *arr in linesArr)
    {
        ll = [arr objectAtIndex:0];
        osStr   = [[SaucePreconnect sharedPreconnect] jsonVal:ll key:@"os"];
        browser = [[SaucePreconnect sharedPreconnect] jsonVal:ll key:@"browser"];
        version = [[SaucePreconnect sharedPreconnect] jsonVal:ll key:@"version"];
        if(![version length])
            version=@"*";
        active  = [[SaucePreconnect sharedPreconnect] jsonVal:ll key:@"active"];
        NSMutableArray *obarr = [NSMutableArray arrayWithCapacity:4];
        [obarr  addObject:osStr];
        [obarr  addObject:browser];
        [obarr  addObject:version];
        [obarr  addObject:active];
        if([osStr hasPrefix:@"Windows"])
            [configWindows addObject:obarr];
        else if([osStr hasPrefix:@"Linux"])
            [configLinux addObject:obarr];            
        else if([osStr hasPrefix:@"OSX"])
            [configOSX addObject:obarr];
    }    
}

// browser delegate methods
- (void)browser:(NSBrowser *)sender willDisplayCell:(id)cell atRow:(NSInteger)row column:(NSInteger)column
{
    if(column==0)
    {
        [cell setAttributedStringValue:osAStrs[row]];
        if(row>1)
            [cell setEnabled:NO];
    }
    else
    {
        NSAttributedString *brAStr;
        NSArray *obarr;
        switch(curTabIndx)
        {
            case tt_windows: brAStr = [brAStrsWindows objectAtIndex:row]; 
                obarr = [configWindows objectAtIndex:row]; break;
            case tt_linux:   brAStr = [brAStrsLinux   objectAtIndex:row]; 
                obarr = [configLinux objectAtIndex:row]; break;
            case tt_apple:
            case tt_mobile:;
        }
        if(brAStr)
        {
            NSString *active = [obarr objectAtIndex:3];
            BOOL enbld = [active isEqualToString:@"YES"];
            [cell setEnabled:enbld]; 
            [cell setLeaf:YES];
            [cell setAttributedStringValue:brAStr];
        }
    }
}

- (NSInteger)browser:(NSBrowser *)sender numberOfRowsInColumn:(NSInteger)column
{
    if(column==0)   // size column 0 row heights
    {
        lastpop1 = NO;
        return 4;
    }
    else    // size column 1 row heights
    {
        curTabIndx = [sender selectedRowInColumn:0];    // os selected in column 0
        curNumBrowsers = 0;
        switch(curTabIndx)
        {
            case tt_windows: curNumBrowsers = [brAStrsWindows count]; break;
            case tt_linux:   curNumBrowsers = [brAStrsLinux   count]; break;
            case tt_apple:
            case tt_mobile:;
        }
        lastpop1 = YES;
        return curNumBrowsers;       // num browsers for selected os
    }
}

- (IBAction)doBrowserClick:(NSBrowser *)sender
{
    // size column 1 row heights
    NSMatrix *mm = [browserTbl matrixInColumn:1];
    NSSize sz = [mm cellSize];
    sz.height = 18;
    [mm setCellSize:sz];
    sz.width=0; sz.height = 4;
    [mm setIntercellSpacing:sz];
    [mm sizeToCells];
    
    if(sender)      // a real click, not during initialization
    {
        if(lastpop1)        // repopulated -> changed os selection
            [sender selectRow:sessionIndxs[curTabIndx] inColumn:1];
        else 
        {
            sessionIndxs[curTabIndx] = [sender selectedRowInColumn:1];
        }
        lastpop1 = NO;
    }

}

- (IBAction)doDoubleClick:(id)sender
{
   if([browserTbl selectedRowInColumn:1] != -1)
    [self connect:self];
}

@end
