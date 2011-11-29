
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

@class JsonLoader;

@protocol JsonLoaderDelegate<NSObject>

- (void)jsonLoadedSuccessfully:(JsonLoader*)loader json:(id)jsonObject;

@optional

// Override this and return NO the given error alert
- (BOOL)willShowError:(JsonLoader*)loader error:(NSString*)error json:(NSString*)json;

- (void)jsonFailed:(JsonLoader*)loader;

- (void)jsonFailedWithAuthError:(JsonLoader*)loader;

- (void)jsonCanceled;

@end
