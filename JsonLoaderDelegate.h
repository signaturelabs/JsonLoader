


@class JsonLoader;

@protocol JsonLoaderDelegate<NSObject>

- (void)jsonLoadedSuccessfully:(JsonLoader*)loader json:(id)jsonObject;

@optional

// Override this and return NO the given error alert
- (BOOL)willShowError:(JsonLoader*)loader error:(NSString*)error json:(NSString*)json;

- (void)jsonFailed:(JsonLoader*)loader;

@end
