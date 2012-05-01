
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

#import "JsonLoaderInternal.h"
#import "CJSONDeserializer.h"
#import "Util.h"


@interface JsonLoaderInternal ()

-(void)dumpResponse;

@property (nonatomic, retain) NSURLConnection *connection;
@property (nonatomic, retain) NSMutableData *requestData;
@property (nonatomic, readwrite, retain) NSURLResponse *response;

@end

@implementation JsonLoaderInternal

@synthesize delegate, response;
@synthesize connection, requestData;

- (id)initWithRequest:(NSURLRequest *)request delegate:(id)del {
	
	if(self = [super init]) {
		
		self.delegate = del;
		
		if ([Util isNotEmpty:request.URL]) {
					
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

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)res {
	
	self.response = res;
	
	self.requestData = [NSMutableData data];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	
	[self.requestData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    
    NSHTTPURLResponse *hRes = nil;
    
    if([self.response isKindOfClass:[NSHTTPURLResponse class]])
        hRes = (NSHTTPURLResponse*)self.response;
	
    if(hRes && hRes.statusCode != 200) {

        [self dumpResponse];
        
        if(hRes.statusCode == 401 && [self.delegate respondsToSelector:@selector(jsonFailedWithAuthError:)]) {
            [self.delegate jsonFailedWithAuthError:nil];
        }
        else if ([self.delegate respondsToSelector:@selector(jsonFailed:)]) {
            [self.delegate jsonFailed:nil];
        }
    }
    else
        [self.delegate performSelector:@selector(didFinishLoading:)
                            withObject:self.requestData];
	
	self.connection = nil;
	self.requestData = nil;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	
	NSLog(@"JsonLoaderError: %@", error.localizedDescription);
	
	[self showError:[NSString stringWithFormat:@"Can't get internet.\n\n%@",
					 [error localizedDescription]] json:nil];
	
	if([self.delegate respondsToSelector:@selector(jsonFailed:)])
		[self.delegate jsonFailed:nil];
	
	self.connection = nil;
	self.requestData = nil;
}

- (void)cancel {
	
	if([self.delegate respondsToSelector:@selector(jsonCanceled)])
		[self.delegate performSelector:@selector(jsonCanceled)];
	
	[self.connection cancel];
	self.connection = nil;
}

- (void)dealloc {
	
	self.delegate = nil;
	self.response = nil;
	
	[self cancel];
	
	self.connection = nil;
	self.requestData = nil;
	
	[super dealloc];
}

#pragma mark - Private

-(void)dumpResponse {
    
    NSString* responseStr = [[NSString alloc] initWithData:self.requestData 
                                                  encoding:NSUTF8StringEncoding];
    
    NSRange stringRange = {0,100};
    if ([responseStr length] > 100) {
        NSLog(@"jsonFailed - response (truncated): %@", [responseStr substringWithRange:stringRange]);
    }
    else {
        NSLog(@"jsonFailed - response: %@", responseStr);
    }

    
}

@end
