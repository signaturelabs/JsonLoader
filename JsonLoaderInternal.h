
/*
 ``The contents of this file are subject to the Mozilla Public License
 Version 1.1 (the "License"); you may not use this file except in
 compliance with the License. You may obtain a copy of the License at
 http://www.mozilla.org/MPL/
 
 The Initial Developer of the Original Code is Hollrr, LLC.
 Portions created by the Initial Developer are Copyright (C) 2011
 the Initial Developer. All Rights Reserved.
 
 Contributor(s):
 
 Dustin Dettmer <dusty@dustytech.com>
 
 */


#import <Foundation/Foundation.h>
#import "JsonLoaderDelegate.h"


/// Loads some json from the server, alerting the user
/// of any error either in json decoding or error attribute
/// of the json hash
@interface JsonLoaderInternal : NSObject {

}

@property (nonatomic, assign) id delegate;

@property (nonatomic, readonly, retain) NSURLResponse *response;

- (id)initWithRequest:(NSURLRequest*)request delegate:(id)delegate;

- (void)cancel;

@end
