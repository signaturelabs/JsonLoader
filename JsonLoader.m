
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

#define REFRESH_TIMEOUT (60 * 60 * 24)


@interface JsonLoader ()

@property (nonatomic, retain) JsonLoaderInternal *jsonLoaderInteral;

@property (nonatomic, retain) NSURL *url;

@property (nonatomic, assign) BOOL updateCache;

@property (nonatomic, readwrite) BOOL loading;

- (void)didFinishLoading:(NSData*)jsonData;

@end


@implementation JsonLoader

@synthesize delegate, loading;
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
	
	if(self = [super init]) {
		
		self.delegate = del;
		
		NSTimeInterval age = 0;
		
		self.url = request.URL;
		
		NSData *data =
		[[JsonCache shared] cacheDataForUrl:self.url getAge:&age];
		
		if(data) {
			
			[self didFinishLoading:data];
			
			if(age > REFRESH_TIMEOUT)
				data = nil;
			else
				self.delegate = nil;
		}
		
		if(!data){
			
			self.updateCache = YES;
			
			self.loading = YES;
			
			self.jsonLoaderInteral =
			[[JsonLoaderInternal alloc] initWithRequest:request delegate:self];
			[self.jsonLoaderInteral release];
		}
	}
	
	return self;
}

- (void)cancel {
	
	self.loading = NO;
	
	[self.jsonLoaderInteral cancel];
}

- (void)jsonLoadedSuccessfully:(id)dictionary {
	
	self.loading = NO;
	
	if([self.delegate respondsToSelector:@selector(jsonLoadedSuccessfully:json:)])
        [self.delegate jsonLoadedSuccessfully:self json:dictionary];
}

- (BOOL)willShowError:(JsonLoader *)loader
				error:(NSString *)error
				 json:(NSString *)json {
	
	if([self.delegate respondsToSelector:@selector(willShowError:error:json:)])
		return [self.delegate willShowError:self error:error json:json];
	
	return YES;
}

- (void)jsonFailed:(JsonLoader *)loader {
	
	self.loading = NO;
	
	if([self.delegate respondsToSelector:@selector(jsonFailed:)])
		[self.delegate jsonFailed:self];
}

- (void)didFinishLoading:(NSData*)jsonData {
	
	self.loading = NO;
	
	if(self.updateCache)
		[[JsonCache shared] setCacheData:jsonData forUrl:self.url];
	
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
	
	if(!errorStr && dictionary)
		[self jsonLoadedSuccessfully:dictionary];
	
	else if([self willShowError:nil error:errorStr json:nil])
		[self jsonFailed:nil];
}

- (void)dealloc {
	
	[self.jsonLoaderInteral cancel];
	self.jsonLoaderInteral.delegate = nil;
	self.jsonLoaderInteral = nil;
	
	self.url = nil;
	
	[super dealloc];
}

@end
