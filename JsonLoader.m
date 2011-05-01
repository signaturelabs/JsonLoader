//
//  JsonLoader.m
//  GeoPhoto
//
//  Created by Dustin Dettmer on 12/18/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "JsonLoader.h"
#import "CJSONDeserializer.h"
#import "Util.h"

@interface JsonLoader ()

@property (nonatomic, retain) NSURLConnection *connection;
@property (nonatomic, retain) NSMutableData *requestData;

@end


@implementation JsonLoader

@synthesize delegate;
@synthesize connection, requestData;

- (id)initWithRequest:(NSURLRequest *)request delegate:(id)del {
	
	if(self = [super init]) {
		
		self.delegate = del;
		
		if ([Util isNotEmpty:request.URL]) {
		
			DLog(@"jsonloader.initWithRequest called with url: %@", request.URL);
			
			self.connection = [NSURLConnection
							   connectionWithRequest:request
							   delegate:self];
			
		}
		else {
			
			DLog(@"jsonloader.initWithRequest called with empty url");
						
			if([self.delegate respondsToSelector:@selector(jsonFailed:)])
				[self.delegate jsonFailed:self];
			
		}
		
	}
	
	return self;
}

- (void)showError:(NSString*)errorStr json:(NSString*)json {
	
	if(errorStr) {
		
		if([self.delegate respondsToSelector:@selector(willShowError:error:json:)])
			if(![self.delegate willShowError:self error:errorStr json:json])
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

- (void)doneLoading:(NSString*)json {
	
	NSData *jsonData = [json dataUsingEncoding:NSUTF32BigEndianStringEncoding];
	NSDictionary *dictionary =
	[[CJSONDeserializer deserializer]
	 deserializeAsDictionary:jsonData
	 error:nil];
	
	NSString *errorStr = nil;
	
	if(!errorStr)
		errorStr = [dictionary objectForKey:@"error"];
	
	if(!errorStr && dictionary) {
		
		if([self.delegate respondsToSelector:@selector(jsonLoadedSuccessfully:json:)])
			[self.delegate jsonLoadedSuccessfully:self json:dictionary];
	}
	else if(!errorStr) {
		
		NSError *error = nil;
		
		id jsonObject =
		[[CJSONDeserializer deserializer]
		 deserialize:jsonData
		 error:&error];
		
		if(error || !jsonObject) {
			
			errorStr = [NSString stringWithFormat:@"Json validation error: %@", [error localizedDescription]];
		}
		else if([self.delegate respondsToSelector:@selector(jsonLoadedSuccessfully:json:)]) {
			
			[self.delegate jsonLoadedSuccessfully:self json:jsonObject];
		}
	}
	
	if(errorStr) {
		
		[self showError:errorStr json:json];
		
		if([self.delegate respondsToSelector:@selector(jsonFailed:)])
			[self.delegate jsonFailed:self];
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	
	self.requestData = [NSMutableData data];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	
	[self.requestData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	NSString *str = [[[NSString alloc]
					  initWithData:self.requestData
					  encoding:NSUTF8StringEncoding]
					 autorelease];
	[self doneLoading:str];
	
	self.connection = nil;
	self.requestData = nil;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	
	[self showError:[NSString stringWithFormat:@"Can't get internet.\n\n%@",
					 [error localizedDescription]] json:nil];
	
	if([self.delegate respondsToSelector:@selector(jsonFailed:)])
		[self.delegate jsonFailed:self];
	
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
