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


@implementation LoginController
@synthesize user;
@synthesize accountKey;
@synthesize aNewUsername;
@synthesize aNewPassword;
@synthesize aNewEmail;


- (IBAction)login:(id)sender
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *uname = [self.user stringValue];
    NSString *aaccountkey = [self.accountKey stringValue];
    if([uname length] && [aaccountkey length])
    {
        if([[SaucePreconnect sharedPreconnect] checkUserLogin:uname  key:aaccountkey])
        {
            [defaults setObject:uname  forKey:@"username"];
            [defaults setObject:uname  forKey:@"accountkey"];
            [[RFBConnectionManager sharedManager] preconnect:self];  // TESTING
            [[RFBConnectionManager sharedManager] connectToServer];
            [self dealloc];     // get rid of the login dialog
        }
        else 
        {
            // TODO: alert for bad login
        }
    }
    else {
        // TODO: alert for missing username or accountkey
    }
}

- (IBAction)forgotKey:(id)sender
{
    [[NSWorkspace sharedWorkspace] openFile:@"http://www.saucelabs.com"];    
}

- (IBAction)signUp:(id)sender
{
    
}


@end
