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
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(textDidChange:) name:NSControlTextDidChangeNotification object:user];
        [center addObserver:self selector:@selector(textDidChange:) name:NSControlTextDidChangeNotification object:accountKey];
        [center addObserver:self selector:@selector(textDidChange:) name:NSControlTextDidChangeNotification object:aNewUsername];
        [center addObserver:self selector:@selector(textDidChange:) name:NSControlTextDidChangeNotification object:aNewPassword];
    
        [NSApp beginSheet:panel modalForWindow:[[ScoutWindowController sharedScout] window] modalDelegate:self  didEndSelector:nil   contextInfo:nil];
    }
    return self;
}
    
- (void)textDidChange:(NSNotification *)aNotification
{
    BOOL bEmpty = [[user stringValue] isEqualToString: @""] || [[accountKey stringValue] isEqualToString: @""];
    [loginButton setEnabled: !bEmpty];
    bEmpty = [[aNewUsername stringValue] isEqualToString: @""] || [[aNewPassword stringValue] isEqualToString: @""];
    [signupButton setEnabled: !bEmpty];
}

-(void)terminateApp
{
    [NSApp endSheet:panel];
    [panel orderOut:nil];
    [[NSApp delegate] setLoginCtrlr:nil];
}
- (IBAction)doCancelLogin:(id)sender 
{
/*
    if([[SaucePreconnect sharedPreconnect] user])
    {

        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        NSString *uname = [defs stringForKey:kUsername];
        NSString *akey = [defs stringForKey:kAccountkey];
        if([[SaucePreconnect sharedPreconnect] checkUserLogin:uname key:akey])
        {
            [NSApp endSheet:panel];
            [panel orderOut:nil];
            [[NSApp delegate] setLoginCtrlr:nil];
        }

    }
 */
    [self terminateApp];
}

- (IBAction)login:(id)sender
{
    NSString *uname = [user stringValue];
    NSString *aaccountkey = [accountKey stringValue];
    [NSApp endSheet:panel];
    [panel orderOut:nil];
    if([uname length] && [aaccountkey length])
    {
        NSString *errStr = [[SaucePreconnect sharedPreconnect] checkUserLogin:uname  key:aaccountkey];
        if(!errStr)
        {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setObject:uname  forKey:kUsername];
            [defaults setObject:aaccountkey  forKey:kAccountkey];
            NSTextField *tf = [[ScoutWindowController sharedScout] userStat];
            [tf setStringValue:uname];

            [[NSApp delegate] setLoginCtrlr:nil];
            [[NSApp delegate] showOptionsDlg:nil];
        }
        else 
        {
            // alert for bad login
            NSBeginAlertSheet(@"Login Error", @"Okay", nil, nil, [NSApp keyWindow], self,@selector(redoLogin:returnCode:contextInfo:), NULL, NULL, errStr);
        }
    }
    else
    {
        // alert for missing username or accountkey
        NSBeginAlertSheet(@"Login Error", @"Okay", nil, nil, [NSApp keyWindow], self,@selector(redoLogin:returnCode:contextInfo:), NULL, NULL, @"Need valid user-name and account-key");    
    }
}

-(void)redoLogin:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [[NSApp delegate] performSelectorOnMainThread:@selector(showLoginDlg:) withObject:nil  waitUntilDone:NO];    
}

- (IBAction)forgotKey:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://saucelabs.com/account/key"]];    
}

- (IBAction)signUp:(id)sender
{
    NSString *nameNew = [aNewUsername stringValue];
    NSString *passNew = [aNewPassword stringValue];
    NSString *emailNew = [aNewEmail stringValue];

    [NSApp endSheet:panel];
    [panel orderOut:nil];
    
    if([nameNew length] && [passNew length])
        [[SaucePreconnect sharedPreconnect] signupNew:nameNew passNew:passNew emailNew:emailNew];
    else
    {
        // alert for missing username or accountkey
        NSBeginAlertSheet(@"Login Error", @"Okay", nil, nil, [NSApp keyWindow], self,@selector(redoLogin:returnCode:contextInfo:), NULL, NULL, @"Need valid username and password to sign up");            
    }
}

- (void)newUserAuthorized  // called from saucePreconnect
{
    
    SaucePreconnect *precon = [SaucePreconnect sharedPreconnect];
    if([precon.ukey length])
    {
        [NSApp endSheet:panel];
        [panel orderOut:self];
        [[NSApp delegate] showOptionsDlg:nil];
    } 
    else
        // alert for missing username or accountkey
        NSBeginAlertSheet(@"Login Error", @"Okay", nil, nil, [NSApp keyWindow], self,@selector(redoLogin:returnCode:contextInfo:), NULL, NULL, @"Sign up was not successful");                
}


@end
