
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


@interface JsonCache : NSObject {

}

+ (id)shared;

- (void)clearCache;

/// Returns YES if the data exists in the database and it has expired.
/// Otherwise NO is returned.
- (BOOL)cachedDataHasExpired:(NSURL*)url;

/// Call this if the cached data has expired for the url to clear it out.
- (void)clearDataForUrl:(NSURL*)url;

/// Returns the data for url.  If nothing is found nil
/// is returned.
- (NSData*)cacheDataForUrl:(NSURL*)url checkForSoftUpdate:(BOOL)checkForSoftUpdate;

/// Returns the data for url.  If nothing is found nil
/// is returned.  *age will be set to the age of the item if found.
- (NSData*)cacheDataForUrl:(NSURL*)url getAge:(NSTimeInterval*)age checkForSoftUpdate:(BOOL)checkForSoftUpdate;

- (void)setCacheData:(NSData*)data forUrl:(NSURL*)url;

/// pass -1 for 'inSeconds' for the default expiration
- (void)setCacheData:(NSData*)data forUrl:(NSURL*)url expire:(int)inSeconds perma:(BOOL)perma;

@end
