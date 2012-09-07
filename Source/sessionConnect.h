//
//  sessionConnect.h
//  scout
//
//  Created by ackerman dudley on 8/31/12.
//  Copyright (c) 2012 Sauce Labs. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface sessionConnect : NSViewController 
{
    NSProgressIndicator *connectionIndicator;
    NSImageView *osImage;
    NSImageView *browserImage;
    NSMutableDictionary *sdict;
}

@property (assign) IBOutlet NSProgressIndicator *connectionIndicator;
@property (assign) IBOutlet NSImageView *osImage;
@property (assign) IBOutlet NSImageView *browserImage;
@property (assign) NSMutableDictionary *sdict;

- (id)initWithDict:(NSMutableDictionary*)adict;
- (IBAction)cancel:(id)sender;

@end
