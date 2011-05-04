//
//  JsonLoader.h
//  GeoPhoto
//
//  Created by Dustin Dettmer on 12/18/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JsonLoaderDelegate.h"


/// Loads some json from the server, alerting the user
/// of any error either in json decoding or error attribute
/// of the json hash
@interface JsonLoaderInternal : NSObject {

}

@property (nonatomic, assign) id delegate;

- (id)initWithRequest:(NSURLRequest*)request delegate:(id)delegate;

- (void)cancel;

@end
