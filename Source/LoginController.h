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

@interface LoginController : NSWindowController                                            
{
    NSTextField *user;
    NSTextField *accountKey;
    NSTextField *aNewUsername;
    NSSecureTextField *aNewPassword;
    NSTextField *aNewEmail;
}
@property (assign) IBOutlet NSTextField *user;
@property (assign) IBOutlet NSTextField *accountKey;
@property (assign) IBOutlet NSTextField *aNewUsername;
@property (assign) IBOutlet NSSecureTextField *aNewPassword;
@property (assign) IBOutlet NSTextField *aNewEmail;

- (IBAction)login:(id)sender;
- (IBAction)forgotKey:(id)sender;
- (IBAction)signUp:(id)sender;

@end
