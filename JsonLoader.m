
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


#import "JsonLoader.h"
#import "JsonLoaderInternal.h"
#import "JsonCache.h"
#import "CJSONDeserializer.h"
#import "IFImageView.h"
#import <CommonCrypto/CommonDigest.h>


@interface JsonLoader ()

@property (nonatomic, retain) JsonLoaderInternal *jsonLoaderInteral;

@property (nonatomic, retain) NSURL *url;

@property (nonatomic, assign) BOOL updateCache;

@property (nonatomic, readwrite) BOOL loading;

@property (nonatomic, retain) NSData *cacheData;

@property (nonatomic, assign) BOOL perma;
@property (nonatomic, assign) BOOL fastMode;

- (void)didFinishLoading:(NSData*)jsonData;

@end


@implementation JsonLoader

@synthesize delegate, retainedObject, loading, cacheData, perma, fastMode, releaseWhenDone;
@synthesize jsonLoaderInteral, url, updateCache;

- (id)initWithRequest:(NSURLRequest*)request delegate:(id)del {
	
	if(self = [super init]) {
		
		self.delegate = del;

        self.url = request.URL;

		self.loading = YES;
		
		self.jsonLoaderInteral =
		[[JsonLoaderInternal alloc] initWithRequest:request delegate:self];
		[self.jsonLoaderInteral release];
	}
	
	return self;
}

- (id)initWithCacheRequest:(NSURLRequest*)request delegate:(id)del {
    
    return [self initWithCacheRequest:request delegate:del perma:NO];
}

- (id)initWithFastCacheRequest:(NSURLRequest*)request delegate:(id)del {
    
    self.fastMode = YES;
    
    return [self initWithCacheRequest:request delegate:del perma:YES];
}

- (id)initWithCacheRequest:(NSURLRequest*)request delegate:(id)del perma:(BOOL)permaP {
	
    NSLog(@"initWithCacheRequest with url: %@", [request URL]);
    
	if(self = [super init]) {
        
        self.perma = permaP;
		
		self.delegate = del;
		
		NSTimeInterval age = 0;
		
		self.url = request.URL;
        
		NSData *data = [[JsonCache shared] cacheDataForUrl:self.url getAge:&age checkForSoftUpdate:YES];
		
		if(data) {
            
            NSLog(@"initWithCacheRequest found cached data for url");
			
			[self didFinishLoading:data];
			
			self.delegate = nil;
            
            BOOL expired = [[JsonCache shared] cachedDataHasExpired:self.url];
            
            if(expired && !self.fastMode) {
                
                NSLog(@"initWithCacheRequest cached data has expired");
                
                self.cacheData = data;
                data = nil;
            }
            
		}
		
		if(!data){
            
            NSLog(@"initWithCacheRequest is fetching new content, cache is stale or missing");
            			
			self.updateCache = YES;
			
			self.loading = YES;
			
			self.jsonLoaderInteral =
			[[JsonLoaderInternal alloc] initWithRequest:request delegate:self];
			[self.jsonLoaderInteral release];
		}
	}
	
	return self;
}

- (id)initWithCacheBustingRequest:(NSURLRequest*)request delegate:(id)del perma:(BOOL)permaP {
	
	if(self = [super init]) {
		
        self.perma = permaP;
        
		self.delegate = del;
		
		self.url = request.URL;
		
		self.updateCache = YES;
		
		self.loading = YES;
		
		self.jsonLoaderInteral =
		[[JsonLoaderInternal alloc] initWithRequest:request delegate:self];
		[self.jsonLoaderInteral release];
	}
	
	return self;
}

- (id)initWithCacheBustingRequest:(NSURLRequest*)request delegate:(id)del {
    
    return [self initWithCacheRequest:request delegate:del perma:NO];
}

- (void)cancel {
	
	self.loading = NO;
	
    self.jsonLoaderInteral.delegate = nil;
	[self.jsonLoaderInteral cancel];
    
    self.cacheData = nil;
}

- (void)setRetainedObject:(NSObject*)obj {
    
    [obj retain];
    [retainedObject autorelease];
    
    retainedObject = obj;
}

- (void)jsonLoadedSuccessfully:(id)dictionary {
		
	self.loading = NO;
	
    self.retainedObject = nil;
    
    if(self.releaseWhenDone)
		[self autorelease];
	
    self.cacheData = nil;
    
    // This must be the last line in function because delegates can release us.
	if([self.delegate respondsToSelector:@selector(jsonLoadedSuccessfully:json:)])
        [self.delegate jsonLoadedSuccessfully:self json:dictionary];
}

- (BOOL)willShowError:(JsonLoader *)loader
				error:(NSString *)error
				 json:(NSString *)json {
	
    // This must be the last line in function because delegates can release us.
	if([self.delegate respondsToSelector:@selector(willShowError:error:json:)])
		return [self.delegate willShowError:self error:error json:json];
	
	return YES;
}

- (void)jsonFailed:(JsonLoader *)loader {
    
    NSLog(@"jsonFailed called for url: %@", self.url);
	
	self.loading = NO;
	
    self.retainedObject = nil;
    
	if(self.releaseWhenDone)
		[self autorelease];
    
    NSLog(@"try to fallback to stale cached data for url: %@", self.url);
    NSData *temp = [[JsonCache shared] cacheDataForUrl:self.url checkForSoftUpdate:NO];      
    
    NSError *error = nil;

    NSDictionary *dictionary =
	[[CJSONDeserializer deserializer]
	 deserialize:temp
	 error:&error];
    
    self.cacheData = nil;
    
    // This must be the last line in function because delegates can release us.
    if(dictionary && [self.delegate respondsToSelector:@selector(jsonLoadedSuccessfully:json:)]) {
        NSLog(@"found stale cached data for url: %@, calling jsonLoadedSuccessfully", self.url);
        [self.delegate jsonLoadedSuccessfully:self json:dictionary];
    }
    else {
        NSLog(@"could not find stale cached data for url: %@, caling delegate jsonFailed", self.url);
        if([self.delegate respondsToSelector:@selector(jsonFailed:)])
            [self.delegate jsonFailed:self];
    }
}

- (void)jsonFailedWithAuthError:(JsonLoader *)loader {
    
    NSLog(@"jsonFailedWithAuthError called for url: %@", self.url);
	
	self.loading = NO;
	
    self.retainedObject = nil;
    
	if(self.releaseWhenDone)
		[self autorelease];
    
	if([self.delegate respondsToSelector:@selector(jsonFailedWithAuthError:)]) {
		[self.delegate jsonFailedWithAuthError:self];
    }
    else if([self.delegate respondsToSelector:@selector(jsonFailed:)]) {
        [self.delegate jsonFailed:self];
    }
}

- (void)jsonCanceled {
    
    self.cacheData = nil;
    
    if([self.delegate respondsToSelector:@selector(jsonCanceled)])
        [self.delegate jsonCanceled];
    
    self.retainedObject = nil;
	
	if(self.releaseWhenDone)
		[self release];
}

- (void)didFinishLoading:(NSData*)jsonData {
	
    self.retainedObject = nil;
	
	self.loading = NO;
		
	if(self.updateCache) {
		
		int maxAge = -1;
		
		if([self.jsonLoaderInteral.response isKindOfClass:[NSHTTPURLResponse class]]) {
			
			NSHTTPURLResponse *response = (NSHTTPURLResponse*)
			self.jsonLoaderInteral.response;
			
			NSDictionary *head = [response allHeaderFields];
			
			NSString *str = [head objectForKey:@"Cache-Control"];
			
			if(str) {
				
				NSRange r = [str rangeOfString:@"max-age="];
				
				if(r.location != NSNotFound)
					maxAge = [[str substringFromIndex:r.location + r.length] intValue]; 
			}
		}

		NSLog(@"JsonLoader#didFinishLoading going to update cache, self.updateCache is true");
		[[JsonCache shared] setCacheData:jsonData forUrl:self.url expire:maxAge perma:self.perma];
	}
	
	NSError *error = nil;
	
	NSDictionary *dictionary =
	[[CJSONDeserializer deserializer]
	 deserialize:jsonData
	 error:&error];
	
	NSString *errorStr = nil;
	
	if(error)
		errorStr = [NSString stringWithFormat:@"Json validation error: %@",
					[error localizedDescription]];
	
	if(!errorStr && [dictionary isMemberOfClass:[NSDictionary class]])
		errorStr = [dictionary objectForKey:@"error"];
	
	//READ ME!!
    // This else if chain must be the last line in function because delegates can release us.
	if(!errorStr && dictionary) {
        
		[self jsonLoadedSuccessfully:dictionary];
	}
	else if([self willShowError:nil error:errorStr json:nil]) {
        
        NSLog(@"Failed to create dictionary from cached data.  Error: %@", errorStr);
        
        NSString* aStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        NSLog(@"Cached data: %@", aStr);
        [aStr release];
               
		[self jsonFailed:nil];
    }
	else if(self.releaseWhenDone) {
        
		[self autorelease];
    }
	
	// Scroll up to read me first!!
}

+ (void)installPreloadedCachedJson:(NSString*)preloadPath {
    
    NSLog(@"Install PreloadedCached Json. Preload path: %@", preloadPath);
	
    NSFileManager *mng = [NSFileManager defaultManager];
    
    for(NSString *component in [mng contentsOfDirectoryAtPath:preloadPath error:nil]) {
        
        if([component.pathExtension isEqual:@"url"]) {
            
            NSString *str = [NSString stringWithContentsOfFile:
							 [preloadPath stringByAppendingPathComponent:component] encoding:NSUTF8StringEncoding error:nil];
			
			// check for junk newline ending and remove it.
			while(str.length && [str characterAtIndex:str.length - 1] == '\n')
				str = [str substringToIndex:str.length - 1];
            
            const char *cStr = [str UTF8String];
            
            unsigned char result[CC_MD5_DIGEST_LENGTH];
            CC_MD5(cStr, strlen(cStr), result);
            
            NSString *md5 = [NSString stringWithFormat:
                             @"%02x%02x%02x%02x%02x"
                             @"%02x%02x%02x%02x%02x"
                             @"%02x%02x%02x%02x%02x"
                             @"%02x",
                             result[0],  result[1],  result[2],  result[3],  result[4],
                             result[5],  result[6],  result[7],  result[8],  result[9],
                             result[10], result[11], result[12], result[13], result[14],
                             result[15]];
            
            NSURL *url = [NSURL URLWithString:str];
            
            // for images, just copy them to destination directory
            if([str.pathExtension isEqual:@"png"] || [str.pathExtension isEqual:@"jpg"]) {
                
                NSString *cachePath =
                [preloadPath stringByAppendingPathComponent:
                 [md5.lowercaseString stringByAppendingPathExtension:str.pathExtension]];
                
                NSString *filename = [IFImageView getStoreageFilename:url];
                
                if([mng fileExistsAtPath:cachePath] && ![mng fileExistsAtPath:filename])
                    [mng copyItemAtPath:cachePath toPath:filename error:nil];
            }
            else {
                
                // everything else, we assume to be json and save metadata about cache object in db 
                
                // Skip it if it's already in the cache.
                if([[JsonCache shared] cacheDataForUrl:url checkForSoftUpdate:NO])
                    continue;
                
                NSString *cachePath =
                [preloadPath stringByAppendingPathComponent:
                 [md5.lowercaseString stringByAppendingPathExtension:@"cache"]];
                
                NSLog(@"Saving json cache object in db for url: %@ and md5: %@", url, md5);
                
                NSData *data = [NSData dataWithContentsOfFile:cachePath];
                
                [[JsonCache shared] setCacheData:data forUrl:url expire:-1 perma:YES];
                
            }
        }
    }
}

- (void)dealloc {
	
	self.releaseWhenDone = NO;
    
    self.retainedObject = nil;
	
	[self.jsonLoaderInteral cancel];
	self.jsonLoaderInteral.delegate = nil;
	self.jsonLoaderInteral = nil;
	
    self.cacheData = nil;
    
    self.url = nil;
	
	[super dealloc];
}

@end
