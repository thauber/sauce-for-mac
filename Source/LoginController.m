//
//  ServerFromPrefs.h
//  Chicken of the VNC
//
//  Created by Jared McIntyre on Sun May 1 2004.
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//


#import "AppDelegate.h"
#import "LoginController.h"
#import "SaucePreconnect.h"
#import "RFBConnectionManager.h"
#import "SessionController.h"
#import "ScoutWindowController.h"


@implementation LoginController
@synthesize panel;
@synthesize cancelLogin;

- (id)init
{
    if (self = [super init]) 
    {
        [NSBundle loadNibNamed:@"LoginController" owner:self];
        NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
        NSString *uname = [defs stringForKey:kUsername];
        NSString *akey = [defs stringForKey:kAccountkey];
        if(!uname)
            uname=@"";
        [user setStringValue:uname];
        if(!akey)
            akey = @"";
        [accountKey setStringValue:akey];
        if(!uname || !akey)     // can't cancel login if we don't have username/acctkey
            [cancelLogin setHidden:YES];
        [panel setOpaque:YES];
        [panel setAlphaValue:1.0];
        [NSApp beginSheet:panel modalForWindow:[[ScoutWindowController sharedScout] window] modalDelegate:self  didEndSelector:nil   contextInfo:nil];
        [self retain];
    }
    return self;
}

- (IBAction)doCancelLogin:(id)sender 
{
    [NSApp endSheet:panel];
    [panel orderOut:nil];
    if(![[SaucePreconnect sharedPreconnect] user])
    {
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        NSString *uname = [defs stringForKey:kUsername];
        NSString *akey = [defs stringForKey:kAccountkey];
        if([[SaucePreconnect sharedPreconnect] checkUserLogin:uname key:akey])
            [[NSApp delegate] showOptionsDlg:nil];            
    }
}

- (IBAction)login:(id)sender
{
    NSString *uname = [user stringValue];
    NSString *aaccountkey = [accountKey stringValue];
    if([uname length] && [aaccountkey length])
    {
        if([[SaucePreconnect sharedPreconnect] checkUserLogin:uname  key:aaccountkey])
        {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setObject:uname  forKey:kUsername];
            [defaults setObject:aaccountkey  forKey:kAccountkey];
            NSTextField *tf = [[ScoutWindowController sharedScout] userStat];
            [tf setStringValue:uname];

            [NSApp endSheet:panel];
            [panel orderOut:nil];

            if(![[ScoutWindowController sharedScout] tabCount])
                [[NSApp delegate] showOptionsDlg:nil];
            [self release];     
        }
        else 
        {
            // alert for bad login
            NSBeginAlertSheet(@"Login Error", @"Okay", nil, nil, [NSApp keyWindow], self,nil, NULL, NULL, @"Failed to Authenticate");
        }
    }
    else
    {
        // alert for missing username or accountkey
        NSBeginAlertSheet(@"Login Error", @"Okay", nil, nil, [NSApp keyWindow], self,nil, NULL, NULL, @"Need valid user-name and account-key");    
    }
}

- (IBAction)forgotKey:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.saucelabs.com"]];    
}

- (IBAction)signUp:(id)sender
{
    NSString *nameNew = [aNewUsername stringValue];
    NSString *passNew = [aNewPassword stringValue];
    NSString *emailNew = [aNewEmail stringValue];
    
    [[SaucePreconnect sharedPreconnect] signupNew:nameNew passNew:passNew emailNew:emailNew];
}

- (void)newUserAuthorized  // called from saucePreconnect
{
    
    SaucePreconnect *precon = [SaucePreconnect sharedPreconnect];
    if([precon.ukey length])
    {
        [[NSApp delegate] showOptionsDlg:nil];
        [self dealloc];     // get rid of the login dialog
    }    
    
}


@end
