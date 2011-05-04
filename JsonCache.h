//
//  JsonCache.h
//  associate.ipad
//
//  Created by Dustin Dettmer on 5/3/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//


@interface JsonCache : NSObject {

}

+ (id)shared;

- (NSData*)cacheDataForUrl:(NSURL*)url;
- (NSData*)cacheDataForUrl:(NSURL*)url getAge:(NSTimeInterval*)age;

- (void)setCacheData:(NSData*)data forUrl:(NSURL*)url;

@end
