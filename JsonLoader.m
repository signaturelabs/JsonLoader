
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


@interface JsonLoader ()

@property (nonatomic, retain) JsonLoaderInternal *jsonLoaderInteral;

@property (nonatomic, retain) NSURL *url;

@property (nonatomic, assign) BOOL updateCache;

@property (nonatomic, readwrite) BOOL loading;

@property (nonatomic, retain) NSData *cacheData;

- (void)didFinishLoading:(NSData*)jsonData;

@end


@implementation JsonLoader

@synthesize delegate, loading, cacheData, releaseWhenDone;
@synthesize jsonLoaderInteral, url, updateCache;

- (id)initWithRequest:(NSURLRequest*)request delegate:(id)del {
	
	if(self = [super init]) {
		
		self.delegate = del;
		
		self.loading = YES;
		
		self.jsonLoaderInteral =
		[[JsonLoaderInternal alloc] initWithRequest:request delegate:self];
		[self.jsonLoaderInteral release];
	}
	
	return self;
}

- (id)initWithCacheRequest:(NSURLRequest*)request delegate:(id)del {
	
    NSLog(@"initWithCacheRequest with url: %@", [request URL]);
    
	if(self = [super init]) {
		
		self.delegate = del;
		
		NSTimeInterval age = 0;
		
		self.url = request.URL;
        
		NSData *data = [[JsonCache shared] cacheDataForUrl:self.url getAge:&age checkForSoftUpdate:YES];
		
		if(data) {
            
            NSLog(@"initWithCacheRequest found cached data for url");
			
			[self didFinishLoading:data];
			
			self.delegate = nil;
            
            if([[JsonCache shared] cachedDataHasExpired:self.url]) {
                
                NSLog(@"initWithCacheRequest cached data has expired");
                
                self.cacheData = data;
                data = nil;
            }
            else {
                
                NSLog(@"initWithCacheRequest cached data has not expired");
                
                [self didFinishLoading:data];
                
                self.delegate = nil;
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

- (id)initWithCacheBustingRequest:(NSURLRequest*)request delegate:(id)del {
	
	if(self = [super init]) {
		
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

- (void)cancel {
	
	self.loading = NO;
	
    self.jsonLoaderInteral.delegate = nil;
	[self.jsonLoaderInteral cancel];
    
    self.cacheData = nil;
}

- (void)jsonLoadedSuccessfully:(id)dictionary {
	
	self.loading = NO;
	
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
    
    NSLog(@"jsonFailed called");
	
	self.loading = NO;
	
	if(self.releaseWhenDone)
		[self autorelease];
    
    NSLog(@"try to fallback to stale cached data");
    NSData *temp = [[JsonCache shared] cacheDataForUrl:self.url checkForSoftUpdate:NO];      
    
    NSError *error = nil;

    NSDictionary *dictionary =
	[[CJSONDeserializer deserializer]
	 deserialize:temp
	 error:&error];
    
    self.cacheData = nil;
    
    // This must be the last line in function because delegates can release us.
    if(dictionary && [self.delegate respondsToSelector:@selector(jsonLoadedSuccessfully:json:)]) {
        NSLog(@"found stale cached data, calling jsonLoadedSuccessfully");
        [self.delegate jsonLoadedSuccessfully:self json:dictionary];
    }
    else {
        NSLog(@"NOT calling jsonLoadedSuccessfully, caling delegate jsonFailed");
        if([self.delegate respondsToSelector:@selector(jsonFailed:)])
            [self.delegate jsonFailed:self];
    }

    
}

- (void)jsonCanceled {
    
    self.cacheData = nil;
	
	if(self.releaseWhenDone)
		[self release];
}

- (void)didFinishLoading:(NSData*)jsonData {
	
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
		
		[[JsonCache shared] setCacheData:jsonData forUrl:self.url expire:maxAge];
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
    
}

- (void)dealloc {
	
	self.releaseWhenDone = NO;
	
	[self.jsonLoaderInteral cancel];
	self.jsonLoaderInteral.delegate = nil;
	self.jsonLoaderInteral = nil;
	
    self.cacheData = nil;
    
    self.url = nil;
	
	[super dealloc];
}

@end
