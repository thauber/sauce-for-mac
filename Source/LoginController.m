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

- (id)init
{
    self=[super initWithNibName:@"LoginController" bundle:nil];
    if(self)
    {
        //perform any initializations
    }
    return self;
}

- (void)loadView {
    [super loadView];
    
    NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
    NSString *uname = [defs stringForKey:kUsername];
    NSString *akey = [defs stringForKey:kAccountkey];
    [user setStringValue:uname];
    [accountKey setStringValue:akey]; 
    [[ScoutWindowController sharedScout] addNewTab:login view:[self view]];
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
            [NSApp showOptionsDlg:nil];
            [self dealloc];     // get rid of the login dialog
        }
        else 
        {
            // alert for bad login
//            NSBeginAlertSheet(@"Login Error", @"Okay", nil, nil, [self window], self,nil, NULL, NULL, @"Failed to Authenticate");
        }
    }
    else
    {
        // alert for missing username or accountkey
//        NSBeginAlertSheet(@"Login Error", @"Okay", nil, nil, [self window], self,nil, NULL, NULL, @"Need valid user-name and account-key");    
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
    
    [[SaucePreconnect sharedPreconnect] setNewUser:nameNew passNew:passNew emailNew:emailNew];
    [[SaucePreconnect sharedPreconnect] signupNew:nil];
}

- (void)newUserAuthorized  // called from saucePreconnect
{
    
    SaucePreconnect *precon = [SaucePreconnect sharedPreconnect];
    if([precon.ukey length])
    {
        [NSApp showOptionsDlg:nil];
        [self dealloc];     // get rid of the login dialog
    }    
    
}


@end
