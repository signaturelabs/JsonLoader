//
//  JsonCache.m
//  associate.ipad
//
//  Created by Dustin Dettmer on 5/3/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "JsonCache.h"
#import "CachedRequest.h"
#import <CoreData/CoreData.h>

#define INVALIDATION_TIMEOUT (60 * 60 * 24 * 30)


@interface JsonCache ()

@property (nonatomic, retain) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, retain) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, retain) NSManagedObjectModel *managedObjectModel;

- (void)saveContext;

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
		
		if (![persistentStoreCoordinator
			  addPersistentStoreWithType:NSSQLiteStoreType
			  configuration:nil URL:storeURL
			  options:nil error:&error]) {
			
			NSLog(@"persistentStoreCoordinator error %@, %@", error, [error userInfo]);
			abort();
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
							   withExtension:@"mom"]];
	
	return managedObjectModel;
}

- (void)cleanupExpired {
	
	NSManagedObjectContext *moc = self.managedObjectContext;
	
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	
	request.entity =
	[NSEntityDescription entityForName:@"CachedRequest"
				inManagedObjectContext:moc];
	
	request.resultType = NSDictionaryResultType;
	request.propertiesToFetch =
	[NSArray arrayWithObjects:@"timestamp", @"url", nil];
	
	NSArray *array = [moc executeFetchRequest:request error:nil];
	
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
	
	for(NSDictionary *cachedRequest in array) {
		
		NSDate *date = [cachedRequest objectForKey:@"timestamp"];
		
		if(-[date timeIntervalSinceNow] > INVALIDATION_TIMEOUT)
			[self.managedObjectContext deleteObject:
			 [self getCachedRequestForUrlString:[cachedRequest objectForKey:@"url"]]];
	}
	
	[formatter release];
}

- (void)saveContext {
	
	[self cleanupExpired];
    
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

- (NSData*)cacheDataForUrl:(NSURL*)url {
	
	CachedRequest *cachedRequest = [self getCachedRequestForUrl:url];
	
	if(cachedRequest
	   && [cachedRequest.timestamp timeIntervalSinceNow] > INVALIDATION_TIMEOUT) {
		
		[self.managedObjectContext deleteObject:cachedRequest];
		return nil;
	}
	
	return cachedRequest.rawData;
}

- (NSData*)cacheDataForUrl:(NSURL*)url getAge:(NSTimeInterval*)age {
	
	CachedRequest *cachedRequest = [self getCachedRequestForUrl:url];
	
	if(cachedRequest) {
		
		if([cachedRequest.timestamp timeIntervalSinceNow] > INVALIDATION_TIMEOUT) {
			
			[self.managedObjectContext deleteObject:cachedRequest];
			return nil;
		}
		
		if(age)
			*age = [cachedRequest.timestamp timeIntervalSinceNow];
	}
	
	return cachedRequest.rawData;
}

- (void)setCacheData:(NSData*)data forUrl:(NSURL*)url {
	
	CachedRequest *cachedRequest = [self getCachedRequestForUrl:url];
	
	if(!cachedRequest)
		cachedRequest = [self createCachedRequest];
	
	cachedRequest.rawData = data;
	cachedRequest.url = [url absoluteString];
	cachedRequest.timestamp = [NSDate date];
}

- (id)init {
	
	if(self = [super init]) {
		
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
