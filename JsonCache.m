
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


#import "JsonCache.h"
#import "CachedRequest.h"
#import "JsonLoader.h"
#import <CoreData/CoreData.h>
#import "CJSONDeserializer.h"

@interface JsonCache ()

@property (nonatomic, retain) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, retain) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, retain) NSManagedObjectModel *managedObjectModel;

- (void)saveContext;
- (void)saveContext:(BOOL)cleanupExpired;

- (CachedRequest*)getCachedRequestForUrl:(NSURL*)url;
- (CachedRequest*)getCachedRequestForUrlString:(NSString*)urlString;

@end


@implementation JsonCache

@synthesize managedObjectContext;
@synthesize persistentStoreCoordinator;
@synthesize managedObjectModel;

- (NSURL *)applicationDocumentsDirectory {
	
    return [[[NSFileManager defaultManager]
			 URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask]
			lastObject];
}

- (NSManagedObjectContext*)managedObjectContext {
	
	if(!managedObjectContext) {
		
		managedObjectContext = [[NSManagedObjectContext alloc] init];
		managedObjectContext.persistentStoreCoordinator = self.persistentStoreCoordinator;
	}
	
	return managedObjectContext;
}

- (NSPersistentStoreCoordinator*)persistentStoreCoordinator {
    
	if(!persistentStoreCoordinator) {
		
		NSURL *storeURL = [[self applicationDocumentsDirectory]
						   URLByAppendingPathComponent:@"JsonCache.sqlite"];
		
		persistentStoreCoordinator =
		[[NSPersistentStoreCoordinator alloc]
		 initWithManagedObjectModel:self.managedObjectModel];
        
		NSError *error = nil;
        
        
        // check if we actually need to migrate (for debug purposes)
        NSDictionary *sourceMetadata =
        [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType
                                                                   URL:storeURL
                                                                 error:&error];
        if (sourceMetadata == nil) {
            // deal with error
            NSLog(@"JsonCache: sourceMetadata == nil, cannot check if JSON cache needs to be migrated");
        }
        else {
            NSManagedObjectModel *destinationModel = [persistentStoreCoordinator managedObjectModel];
            BOOL pscCompatibile = [destinationModel
                                   isConfiguration:nil
                                   compatibleWithStoreMetadata:sourceMetadata];
            if (pscCompatibile) {
                NSLog(@"JsonCache: existing JSON cache is compatible , no need to migrate");
                // no need to migrate
            }
            else {
                NSLog(@"JsonCache: existing JSON cache is not compatible, need to migrate");
            }            
        }

        
        NSDictionary *options =
        [NSDictionary dictionaryWithObjectsAndKeys:
         [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
         [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption,
         nil];
		
		if (![persistentStoreCoordinator
			  addPersistentStoreWithType:NSSQLiteStoreType
			  configuration:nil URL:storeURL
			  options:options error:&error]) {
            
            NSLog(@"persistentStoreCoordinator addPersistentStoreWithType error %@, %@", error, [error userInfo]);
            NSLog(@"persistentStoreCoordinator store: %@ ", storeURL); 

            // try to delete the store and try again
            error = nil;
            NSFileManager *fileMgr = [NSFileManager defaultManager];
            
            [fileMgr removeItemAtURL:storeURL error:&error];
            
            if(error) {
                NSLog(@"could not delete store at %@", storeURL); 
            }
            else {
                NSLog(@"deleted store at %@", storeURL); 
            }
            
            if ([fileMgr fileExistsAtPath:[storeURL path]]) {
                NSLog(@"store at %@ is still there!  deleting didnt work", storeURL); 
            }
            else {
                NSLog(@"store at %@ is gone - deleting worked", storeURL); 
            }
            
            if (![persistentStoreCoordinator
                  addPersistentStoreWithType:NSSQLiteStoreType
                  configuration:nil URL:storeURL
                  options:options error:&error]) {
                
                NSLog(@"persistentStoreCoordinator addPersistentStoreWithType failed again!  store: %@ ", storeURL); 
                NSLog(@"persistentStoreCoordinator addPersistentStoreWithType error %@, %@", error, [error userInfo]);

                NSLog(@"calling recursively as last act of desperation");
                persistentStoreCoordinator = nil;
                return [self persistentStoreCoordinator];
                
            }
            else {
                NSLog(@"persistentStoreCoordinator addPersistentStoreWithType apparently worked second attempt");
            }

		}  
        else {
            NSLog(@"persistentStoreCoordinator addPersistentStoreWithType succeeded");
        }
	}
	
	return persistentStoreCoordinator;
}

- (NSManagedObjectModel*)managedObjectModel {
	
	if(!managedObjectModel)
		managedObjectModel = [[NSManagedObjectModel alloc]
							  initWithContentsOfURL:
							  [[NSBundle mainBundle]
							   URLForResource:@"JsonCache"
							   withExtension:@"momd"]];
	
	return managedObjectModel;
}

- (void)cleanupExpired {
	
	NSManagedObjectContext *moc = self.managedObjectContext;
	
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	
	request.entity =
	[NSEntityDescription entityForName:@"CachedRequest"
				inManagedObjectContext:moc];
	
	request.resultType = NSDictionaryResultType;
    
    NSMutableArray *ary =
	[NSMutableArray arrayWithObjects:@"timestamp", @"url", nil];
    
    NSDictionary *props = request.entity.propertiesByName;
    
    // This is here because migration is not working.  So instead of
    // crashing, we disable the perma functionality.
    if([props objectForKey:@"perma"])
        [ary addObject:@"perma"];
    
	request.propertiesToFetch = ary;
	
	NSArray *array = [moc executeFetchRequest:request error:nil];
	
	for(NSDictionary *cachedRequest in array) {
		
		NSDate *date = [cachedRequest objectForKey:@"timestamp"];
		NSNumber *expire = [cachedRequest objectForKey:@"expire"];
		
		if(-[date timeIntervalSinceNow] > [expire intValue]) {
            
            if (![[cachedRequest objectForKey:@"perma"] boolValue]) {
                
                id obj = [self getCachedRequestForUrlString:[cachedRequest objectForKey:@"url"]];
                
                if(obj)
                    [self.managedObjectContext deleteObject:obj];
                
                NSLog(@"Deleting expired cached json for url: %@", [cachedRequest objectForKey:@"url"]);                
            }
            else {
                NSLog(@"url is permacached, not touching it: %@", [cachedRequest objectForKey:@"url"]);                
            }
            
        }
	}
}

- (void)clearCache {
	
	NSManagedObjectContext *moc = self.managedObjectContext;
	
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	
	request.entity =
	[NSEntityDescription entityForName:@"CachedRequest"
				inManagedObjectContext:moc];
	
	request.resultType = NSDictionaryResultType;
	request.propertiesToFetch =
	[NSArray arrayWithObjects:@"timestamp", @"url", nil];
	
	NSArray *array = [moc executeFetchRequest:request error:nil];
	
	for(NSDictionary *cachedRequest in array) {
		
        id obj = [self getCachedRequestForUrlString:[cachedRequest objectForKey:@"url"]];
        
        if(obj)
            [self.managedObjectContext deleteObject:obj];
	}
    
    [self saveContext:FALSE];

	
}


- (void)saveContext {
    [self saveContext:TRUE];
}

- (void)saveContext:(BOOL)cleanupExpired {
	
    if (cleanupExpired) {
        [self cleanupExpired];
    }
    
    NSError *error = nil;
	
    if (self.managedObjectContext && [managedObjectContext hasChanges]
		&& ![managedObjectContext save:&error]) {
            
            NSLog(@"managedObjectContext save error %@, %@",
				  error, [error userInfo]);
            abort();
    }
}

+ (id)shared {
	
	static JsonCache *jsonCache = nil;
	
	if(!jsonCache)
		jsonCache = [[JsonCache alloc] init];
	
	return jsonCache;
}

- (void)saveAndQuit {
	
	[self saveContext];
	
	[self release];
}

- (CachedRequest*)getCachedRequestForUrl:(NSURL*)url {
    
        
    return [self getCachedRequestForUrlString:[url absoluteString]];
        
    
}

- (CachedRequest*)getCachedRequestForUrlString:(NSString*)urlString {
	
	NSManagedObjectContext *moc = self.managedObjectContext;
	
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	
	request.entity =
	[NSEntityDescription entityForName:@"CachedRequest" inManagedObjectContext:moc];
	
	request.predicate =
	[NSPredicate predicateWithFormat:@"url = %@", urlString];
	
	NSArray *array = [moc executeFetchRequest:request error:nil];
	
	if (array == nil)
		return nil;
	
	return [array lastObject];
}

- (CachedRequest*)createCachedRequest {
	
        
    return
        [NSEntityDescription
         insertNewObjectForEntityForName:@"CachedRequest"
         inManagedObjectContext:self.managedObjectContext];
        
    
	
}

- (void)checkForSoftUpdate:(CachedRequest*)cachedRequest url:(NSURL*)url perma:(BOOL)perma {
	
	if([[NSDate date] earlierDate:
		[cachedRequest.timestamp dateByAddingTimeInterval:
		 [cachedRequest.expire intValue] / 2]] != cachedRequest.timestamp) {
			
			NSLog(@"checkForSoftUpdate running: %@", url);
			
			NSURLRequest *req = [NSURLRequest requestWithURL:url];
			
			JsonLoader *updater =
			[[JsonLoader alloc] initWithCacheBustingRequest:req delegate:nil perma:perma];
			
			updater.releaseWhenDone = YES;
	}
	else {
		NSLog(@"checkForSoftUpdate not running: %@", url);
	}
	
}

- (BOOL)cachedDataHasExpired:(NSURL*)url {
    
	CachedRequest *cachedRequest = [self getCachedRequestForUrl:url];
	
	if(cachedRequest
	   && [cachedRequest.timestamp timeIntervalSinceNow] >
	   [cachedRequest.expire intValue]) {
		
		return YES;
	}
    
    return NO;
}

- (void)clearDataForUrl:(NSURL*)url {
    
    CachedRequest *cachedRequest = [self getCachedRequestForUrl:url];
	
    [self.managedObjectContext deleteObject:cachedRequest];
}

- (NSData*)cacheDataForUrl:(NSURL*)url checkForSoftUpdate:(BOOL)checkForSoftUpdate {
	
	CachedRequest *cachedRequest = [self getCachedRequestForUrl:url];
	
    if (checkForSoftUpdate) {
       [self checkForSoftUpdate:cachedRequest url:url perma:[cachedRequest.perma boolValue]]; 
    }
	
	return cachedRequest.rawData;
}

- (NSData*)cacheDataForUrl:(NSURL*)url getAge:(NSTimeInterval*)age checkForSoftUpdate:(BOOL)checkForSoftUpdate {
	
    @try {

        NSLog(@"cacheDataForUrl called for: %@", url);
		
        CachedRequest *cachedRequest = [self getCachedRequestForUrl:url];
        
        if(cachedRequest) {
            
            NSTimeInterval timeIntervalSinceNow = [cachedRequest.timestamp timeIntervalSinceNow];
            int timeIntervalSinceNowInt = (int) timeIntervalSinceNow;
            timeIntervalSinceNowInt = abs(timeIntervalSinceNowInt);
            
            NSLog(@"cachedRequest.expire: %d", [cachedRequest.expire intValue]);
            NSLog(@"cachedRequest.timestamp timeIntervalSinceNow: %d", timeIntervalSinceNowInt);
            
            if([cachedRequest.expire intValue] == 0 || 
               timeIntervalSinceNowInt >
               [cachedRequest.expire intValue]) {

                if (![cachedRequest.perma boolValue]) {
                    
                    NSLog(@"cacheDataForUrl deleting stale cache content for: %@", url);
                    [self.managedObjectContext deleteObject:cachedRequest];
                    return nil;
                }
                else {
                    NSLog(@"url is permacached, going to use cached data even though it appears stale: %@", url);
                }
            }
            else {
                
                NSLog(@"cacheDataForUrl found valid cached content for: %@", url);
                
            }
            
            if(age)
                *age = [cachedRequest.timestamp timeIntervalSinceNow];
        }
        else {
            
            NSLog(@"cacheDataForUrl nothing in cache found for: %@", url);
            
        }
        
        if (checkForSoftUpdate) {
			NSLog(@"checkForSoftUpdate: %@", url);
            [self checkForSoftUpdate:cachedRequest url:url perma:[cachedRequest.perma boolValue]]; 
        }
        
        return cachedRequest.rawData;

        
    }
    @catch (NSException *exception) {
		
		NSLog(@"Caught %@: %@ when trying to cache data for url: %@", [exception name], [exception  reason], url);
		return nil;
	}
    
}

- (void)setCacheData:(NSData*)data forUrl:(NSURL*)url expire:(int)inSeconds perma:(BOOL)perma {
	
    @try {
		
		// make sure this is valid json before saving in cache
		NSError *error = nil;
		id deserialized = [[CJSONDeserializer deserializer] deserialize:data error:&error];
//		NSString *tempDebug = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		if (error || !deserialized) {
			NSLog(@"setCacheData not setting cache data because json invalid for url: %@", url);
			return;
		}
		
        CachedRequest *cachedRequest = [self getCachedRequestForUrl:url];
	
        if(!cachedRequest) {
            cachedRequest = [self createCachedRequest];
        }
        cachedRequest.rawData = data;
        cachedRequest.url = [url absoluteString];
        cachedRequest.timestamp = [NSDate date];
        
        cachedRequest.perma = [NSNumber numberWithBool:perma];
        
        if(inSeconds != -1) {
            cachedRequest.expire = [NSNumber numberWithInt:inSeconds];
        }
        
    }
    @catch (NSException *exception) {
        NSLog(@"Caught %@: %@ when trying to set cache data for url: %@", [exception name], [exception  reason], url);
    }
    
}

- (void)setCacheData:(NSData*)data forUrl:(NSURL*)url {
	
	[self setCacheData:data forUrl:url expire:-1 perma:NO];
}

- (id)init {
	
	if((self = [super init])) {
		
		[[NSNotificationCenter defaultCenter]
		 addObserver:self
		 selector:@selector(saveAndQuit)
		 name:UIApplicationWillTerminateNotification
		 object:nil];
		
		[[NSNotificationCenter defaultCenter]
		 addObserver:self
		 selector:@selector(saveContext)
		 name:UIApplicationDidEnterBackgroundNotification
		 object:nil];
	}
	
	return self;
}

- (void)dealloc {
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	self.managedObjectContext = nil;
	self.persistentStoreCoordinator = nil;
	self.managedObjectModel = nil;
	
	[super dealloc];
}

@end
