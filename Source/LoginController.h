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


#import <Cocoa/Cocoa.h>

@interface LoginController : NSObject                                            
{
    IBOutlet NSTextField *user;
    IBOutlet NSTextField *accountKey;
    IBOutlet NSTextField *accountKeyLabel;
    IBOutlet NSTextField *aNewUsername;
    IBOutlet NSSecureTextField *aNewPassword;
    IBOutlet NSTextField *aNewEmail;
    IBOutlet NSButton *loginButton;
    IBOutlet NSButton *signupButton;
    NSPanel *panel;
    NSButton *cancelLogin;
}
@property (assign) IBOutlet NSPanel *panel;
@property (assign) IBOutlet NSButton *cancelLogin;
- (IBAction)doCancelLogin:(id)sender;
- (void)quitSheet;
- (IBAction)login:(id)sender;
- (IBAction)forgotKey:(id)sender;
- (IBAction)signUp:(id)sender;
- (IBAction)demoLogin:(id)sender;

@end
