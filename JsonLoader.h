//
//  JsonLoader.h
//  associate.ipad
//
//  Created by Dustin Dettmer on 5/3/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JsonLoaderDelegate.h"


@interface JsonLoader : NSObject {

}

@property (nonatomic, assign) id<JsonLoaderDelegate> delegate;

- (id)initWithRequest:(NSURLRequest*)request delegate:(id)delegate;

/// Tries to load from the cache first, falling back on a web request.
/// The cache is updated according to a cache updating policy decided
/// internally.
- (id)initWithCacheRequest:(NSURLRequest*)request delegate:(id)delegate;

- (void)cancel;

@end
