//
//  JsonLoader.m
//  GeoPhoto
//
//  Created by Dustin Dettmer on 12/18/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "JsonLoaderInternal.h"
#import "CJSONDeserializer.h"
#import "Util.h"


@interface JsonLoaderInternal ()

@property (nonatomic, retain) NSURLConnection *connection;
@property (nonatomic, retain) NSMutableData *requestData;

@end

@implementation JsonLoaderInternal

@synthesize delegate;
@synthesize connection, requestData;

- (id)initWithRequest:(NSURLRequest *)request delegate:(id)del {
	
	if(self = [super init]) {
		
		self.delegate = del;
		
		if ([Util isNotEmpty:request.URL]) {
		
			DLog(@"jsonLoaderInternal.initWithRequest called with url: %@", request.URL);
			
			self.connection = [NSURLConnection
							   connectionWithRequest:request
							   delegate:self];
			
		}
		else {
			
			DLog(@"jsonLoaderInternal.initWithRequest called with empty url");
						
			if([self.delegate respondsToSelector:@selector(jsonFailed:)])
				[self.delegate jsonFailed:nil];
			
		}
		
	}
	
	return self;
}

- (void)showError:(NSString*)errorStr json:(NSString*)json {
	
	if(errorStr) {
		
		if([self.delegate respondsToSelector:@selector(willShowError:error:json:)])
			if(![self.delegate willShowError:nil error:errorStr json:json])
				return;
		
		/* this should be disabled by default, but a developer could enable these types of debug alerts by setting a #define 
		   disabling until we have that in place.
		 
		UIAlertView *alert =
		[[UIAlertView alloc] 
		 initWithTitle:@"Issue"
		 message:errorStr
		 delegate:nil
		 cancelButtonTitle:@"Alright"
		 otherButtonTitles:nil];
		
		[alert show];
		[alert release];
		*/
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	
	self.requestData = [NSMutableData data];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	
	[self.requestData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	
	[self.delegate performSelector:@selector(didFinishLoading:)
						withObject:self.requestData];
	
	self.connection = nil;
	self.requestData = nil;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	
	[self showError:[NSString stringWithFormat:@"Can't get internet.\n\n%@",
					 [error localizedDescription]] json:nil];
	
	if([self.delegate respondsToSelector:@selector(jsonFailed:)])
		[self.delegate jsonFailed:nil];
	
	self.connection = nil;
	self.requestData = nil;
}

- (void)cancel {
	
	[self.connection cancel];
	self.connection = nil;
}

- (void)dealloc {
	
	self.delegate = nil;
	
	[self cancel];
	
	self.connection = nil;
	self.requestData = nil;
	
	[super dealloc];
}


@end
