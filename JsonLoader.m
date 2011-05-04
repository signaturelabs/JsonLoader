//
//  JsonLoader.m
//  associate.ipad
//
//  Created by Dustin Dettmer on 5/3/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "JsonLoader.h"
#import "JsonLoaderInternal.h"
#import "JsonCache.h"
#import "CJSONDeserializer.h"

#define REFRESH_TIMEOUT (60 * 60 * 24)


@interface JsonLoader ()

@property (nonatomic, retain) JsonLoaderInternal *jsonLoaderInteral;

@property (nonatomic, retain) NSURL *url;

@property (nonatomic, assign) BOOL updateCache;

- (void)didFinishLoading:(NSData*)jsonData;

@end


@implementation JsonLoader

@synthesize delegate;
@synthesize jsonLoaderInteral, url, updateCache;

- (id)initWithRequest:(NSURLRequest*)request delegate:(id)del {
	
	if(self = [super init]) {
		
		self.delegate = del;
		
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
			
			self.jsonLoaderInteral =
			[[JsonLoaderInternal alloc] initWithRequest:request delegate:self];
			[self.jsonLoaderInteral release];
		}
	}
	
	return self;
}

- (void)cancel {
	
	[self.jsonLoaderInteral cancel];
}

- (void)jsonLoadedSuccessfully:(id)dictionary {
	
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
	
	if([self.delegate respondsToSelector:@selector(jsonFailed:)])
		[self.delegate jsonFailed:self];
}

- (void)didFinishLoading:(NSData*)jsonData {
	
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
