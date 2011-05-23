//
//  JsonCachePrefetcher.m
//  enduser
//
//  Created by Dustin Dettmer on 5/23/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "JsonCachePrefetcher.h"
#import "JsonLoader.h"


@interface JsonCachePrefetcher ()

@property (nonatomic, retain) JsonLoader *jsonLoader;

@end

@implementation JsonCachePrefetcher

@synthesize jsonLoader;

- (id)initWithRequest:(NSURLRequest*)request {
	
	if(self = [super init]) {
		
		[self retain];
		
		self.jsonLoader =
		[[JsonLoader alloc]
		 initWithCacheRequest:request
		 delegate:self];
		
		if(!self.jsonLoader)
			[self release];
		
		[self.jsonLoader release];
	}
	
	return self;
}

- (id)initWithUrlString:(NSString*)urlString {
	
	return [self initWithRequest:
			[NSURLRequest requestWithURL:
			 [NSURL URLWithString:urlString]]];
}

- (void)jsonLoadedSuccessfully:(JsonLoader*)loader json:(id)jsonObject {
	
	[self release];
}

- (void)jsonFailed:(JsonLoader*)loader {
	
	[self release];
}

- (void)dealloc {
	
	self.jsonLoader.delegate = nil;
	self.jsonLoader = nil;
	
	[super dealloc];
}

@end
