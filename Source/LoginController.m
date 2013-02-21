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
        NSString *rsrc = nil;
        if(INAPPSTORE)              // appstore version
            rsrc = @"LoginControllerAS";
        else
            rsrc = @"LoginController";
        
        [NSBundle loadNibNamed:rsrc owner:self];
        NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
        NSString *uname = [defs stringForKey:kUsername];
        NSString *upass = [defs stringForKey:kUserPassword];
        NSString *akey = [defs stringForKey:kAccountkey];
        if([uname isEqualToString:kDemoAccountName])        // don't display demo account info
        {
            uname = nil;
            akey = nil;
        }
        if(!uname)
            uname=@"";
        if(!upass)
            upass=@"";
        [user setStringValue:uname];
        if(!akey)
        {
            if(upass)
            {
                akey = [[SaucePreconnect sharedPreconnect] accountkeyFromPassword:uname pswd:upass];
            }
            else
                akey = @"";
        }
        [accountKey setStringValue:upass];
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(textDidChange:) name:NSControlTextDidChangeNotification object:user];
        [center addObserver:self selector:@selector(textDidChange:) name:NSControlTextDidChangeNotification object:accountKey];
        if(!INAPPSTORE)              // has provision for creating a new user
        {
            [center addObserver:self selector:@selector(textDidChange:) name:NSControlTextDidChangeNotification object:aNewUsername];
            [center addObserver:self selector:@selector(textDidChange:) name:NSControlTextDidChangeNotification object:aNewPassword];
        }
    
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
    NSString *uname = [user stringValue];
    NSString *pswd = [accountKey stringValue];
    [self terminateApp];
    if(![uname length] || ![pswd length])       // set demo account if no user or password on cancel
    {
        uname = kDemoAccountName;       // defined in AppDelegate.h
        pswd = kDemoAccountKey;
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:uname  forKey:kUsername];
        [defaults setObject:pswd  forKey:kAccountkey];
        [defaults setObject:@"" forKey:kUserPassword];
        [[NSApp delegate] prefetchBrowsers];
        [[NSApp delegate] toggleTunnelDisplay];
        [[NSApp delegate] showOptionsDlg:nil];
    }
}

- (IBAction)login:(id)sender
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *uname = @"";
    NSString *aaccountkey = [defaults stringForKey:kAccountkey];
    NSString *pswd = @"";
    if(sender == self)      // using demo login when user cancelled 
    {
        uname = kDemoAccountName;       // defined in AppDelegate.h
        aaccountkey = kDemoAccountKey;
//        [defaults setObject:nil forKey:kSessionURL];  // why blank the url?
    }
    else
    {
        uname = [user stringValue];
        pswd = [accountKey stringValue];
    }
    [NSApp endSheet:panel];
    [panel orderOut:nil];
    if(!aaccountkey)
        aaccountkey = @"";
    if([uname length] && [pswd length])
    {
        aaccountkey = [[SaucePreconnect sharedPreconnect] accountkeyFromPassword:uname pswd:pswd];
    }
    if([uname length] && [aaccountkey length])
    {
        NSString *errStr = [[SaucePreconnect sharedPreconnect] checkUserLogin:uname key:aaccountkey];
        if(!errStr)
        {
            [defaults setObject:uname  forKey:kUsername];
            [defaults setObject:aaccountkey  forKey:kAccountkey];
            [defaults setObject:pswd forKey:kUserPassword];
            [[NSApp delegate] prefetchBrowsers];

            [[NSApp delegate] setLoginCtrlr:nil];
            [[NSApp delegate] toggleTunnelDisplay];
            [[NSApp delegate] showOptionsDlg:nil];
        }
        else 
        {
            // alert for bad login
            NSBeginAlertSheet(@"Login Error", @"Okay", nil, nil, [NSApp keyWindow], self,@selector(redoLogin:returnCode:contextInfo:), NULL, NULL, @"%@",errStr);
        }
    }
    else
    {
        // alert for missing username or accountkey
        NSBeginAlertSheet(@"Login Error", @"Okay", nil, nil, [NSApp keyWindow], self,@selector(redoLogin:returnCode:contextInfo:), NULL, NULL, @"%@",@"Need valid user-name and password");
    }
}

-(void)redoLogin:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [[NSApp delegate] performSelectorOnMainThread:@selector(showLoginDlg:) withObject:nil  waitUntilDone:NO];    
}

- (IBAction)forgotKey:(id)sender   // TODO: need a 'forget password' page when server is ready
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://saucelabs.com/send-password-reset"]];    
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

- (IBAction)demoLogin:(id)sender
{
    [self login:self];
}


@end
