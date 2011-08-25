
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


@interface JsonLoader : NSObject {

}

@property (nonatomic, assign) id<JsonLoaderDelegate> delegate;

@property (nonatomic, readonly) BOOL loading;

@property (nonatomic, assign) BOOL releaseWhenDone;

- (id)initWithRequest:(NSURLRequest*)request delegate:(id)delegate;

/// Tries to load from the cache first, falling back on a web request.
/// The cache is updated according to a cache updating policy decided
/// internally.
- (id)initWithCacheRequest:(NSURLRequest*)request delegate:(id)delegate;

/// Returns whatever we have in cache immediately.  If we don't have this
/// item in the cache, we pull it from the server.  If the cache data was
/// expired, we start a background task to update it.
- (id)initWithFastCacheRequest:(NSURLRequest*)request delegate:(id)delegate;

/// Like initwithCacheRequest:: but allows you make the item permanent (perma).
/// Perma means the object is kept alive in cache and returned in cases
/// where there is not internet or the server fails.
- (id)initWithCacheRequest:(NSURLRequest*)request delegate:(id)delegate perma:(BOOL)perma;

/// Like initWithCacheRequest but loads from the server no matter what
- (id)initWithCacheBustingRequest:(NSURLRequest*)request delegate:(id)delegate;

/// Like initWithCacheRequest but loads from the server no matter what
- (id)initWithCacheBustingRequest:(NSURLRequest*)request delegate:(id)delegate perma:(BOOL)perma;

- (void)cancel;

@end
