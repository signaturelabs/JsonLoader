//
//  JsonLoader.h
//  GeoPhoto
//
//  Created by Dustin Dettmer on 12/18/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@class JsonLoader;

@protocol JsonLoaderDelegate<NSObject>

- (void)jsonLoadedSuccessfully:(JsonLoader*)loader json:(id)jsonObject;

@optional

// Override this and return NO the given error alert
- (BOOL)willShowError:(JsonLoader*)loader error:(NSString*)error json:(NSString*)json;

- (void)jsonFailed:(JsonLoader*)loader;

@end


/// Loads some json from the server, alerting the user
/// of any error either in json decoding or error attribute
/// of the json hash
@interface JsonLoader : NSObject {

}

@property (nonatomic, assign) id<JsonLoaderDelegate> delegate;

- (id)initWithRequest:(NSURLRequest*)request delegate:(id)delegate;

- (void)cancel;

@end
