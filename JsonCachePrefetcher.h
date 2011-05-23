//
//  JsonCachePrefetcher.h
//  enduser
//
//  Created by Dustin Dettmer on 5/23/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JsonLoader.h"

/// Once created, this class retains itself and performs a url request on
/// request or urlString.  Once complete, the class releases itself.
/// If the request was successful, the cache will contain the requested object.
@interface JsonCachePrefetcher : NSObject<JsonLoaderDelegate> {

}

- (id)initWithRequest:(NSURLRequest*)request;
- (id)initWithUrlString:(NSString*)urlString;

@end
