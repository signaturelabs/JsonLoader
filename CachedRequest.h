//
//  CachedRequest.h
//  associate.ipad
//
//  Created by Dustin Dettmer on 5/3/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <CoreData/CoreData.h>


@interface CachedRequest :  NSManagedObject  
{
}

@property (nonatomic, retain) NSString * url;
@property (nonatomic, retain) NSData * rawData;
@property (nonatomic, retain) NSDate * timestamp;

@end
