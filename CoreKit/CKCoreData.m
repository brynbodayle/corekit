//
//  CKCoreData.m
//  CoreKit
//
//  Created by Matt Newberry on 7/15/11.
//  Copyright 2011 MNDCreative, LLC. All rights reserved.
//

#import "CKCoreData.h"
#import "CKBindings.h"
#import <UIKit/UIKit.h>

@implementation CKCoreData

#define ckCoreDataApplicationStorageType		NSSQLiteStoreType
#define ckCoreDataTestingStorageType            NSInMemoryStoreType
#define ckCoreDataStoreFileName                 @"CoreDataStore.sqlite"
#define ckCoreDataThreadKey                     @"ckCoreDataThreadKey"


- (id)init{
    
    self = [super init];
    if (self) {

        self.managedObjectModel = [self managedObjectModel];
		self.persistentStoreCoordinator = [self persistentStoreCoordinator];
		self.mainThreadManagedObjectContext = [self newManagedObjectContext:NSMainQueueConcurrencyType];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            
            //[self setupModels];
        });
    }
    
    return self;
}

- (void) setupModels{
    
    NSDictionary *models = [self.managedObjectModel entitiesByName];
    
    for(NSString *model in [models allKeys]){
        
        Class record = NSClassFromString(model);
        [record setup];
    }
}

- (NSManagedObjectContext *) managedObjectContext{
    
    if ([NSThread isMainThread])
		return _mainThreadManagedObjectContext;
    else{
		
		NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
		NSManagedObjectContext *backgroundThreadContext = threadDictionary[ckCoreDataThreadKey];
		
		if (backgroundThreadContext == nil) {
			
			backgroundThreadContext = [self newManagedObjectContext:NSPrivateQueueConcurrencyType];
            backgroundThreadContext.parentContext = self.mainThreadManagedObjectContext;
		}
        
        threadDictionary[ckCoreDataThreadKey] = backgroundThreadContext;
        
		return backgroundThreadContext;
	}
}

- (NSManagedObjectContext*) newManagedObjectContext:(NSManagedObjectContextConcurrencyType) concurrencyType{
	
	__block NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:concurrencyType];
    
    if(concurrencyType == NSMainQueueConcurrencyType)
        moc.persistentStoreCoordinator = [self persistentStoreCoordinator];
    
    moc.undoManager = nil;
    moc.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
	
	[[NSNotificationCenter defaultCenter] addObserverForName:NSManagedObjectContextDidSaveNotification object:moc queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
		
		[moc mergeChangesFromContextDidSaveNotification:note];
	}];
    
	return moc;
}

- (NSManagedObjectModel *) managedObjectModel{
    
    if( _managedObjectModel != nil)
		return _managedObjectModel;
    
    if([self persistentStoreType] == ckCoreDataApplicationStorageType){
        
        NSArray *files = [[NSBundle mainBundle] URLsForResourcesWithExtension:@"momd" subdirectory:@"."];
        
        if([files count] > 0)
            _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:files[0]];
    }
        
    if(_managedObjectModel == nil)
        _managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:@[[NSBundle bundleForClass:[self class]]]];
    
    
	return _managedObjectModel;
}

- (NSPersistentStoreCoordinator*) persistentStoreCoordinator{
    
	if( _persistentStoreCoordinator != nil)
		return _persistentStoreCoordinator;
	
	NSString* storePath = [self storePath];    
    NSURL *storeURL = [self storeURL];
    
    NSError* error;
	
	_persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
	
	NSDictionary* options = [self persistentStoreOptions];
    NSString *storageType = [self persistentStoreType];
    
    if (![_persistentStoreCoordinator addPersistentStoreWithType:storageType configuration:nil URL:storeURL options:options error:&error]){
                
		[[NSFileManager defaultManager] removeItemAtPath:storePath error:nil];
		
		if (![_persistentStoreCoordinator addPersistentStoreWithType:storageType configuration:nil URL:storeURL options:options error:&error]){
            
            NSLog(@"%@", error);
            abort();
        }
	}
	
	return _persistentStoreCoordinator;
}

- (NSString *) persistentStoreType{
    
    return [[UIApplication sharedApplication] delegate] == nil ? ckCoreDataTestingStorageType : ckCoreDataApplicationStorageType;
}

- (NSDictionary *) persistentStoreOptions{
    
    return @{NSMigratePersistentStoresAutomaticallyOption: @YES, NSInferMappingModelAutomaticallyOption: @YES};
}

- (NSString *) storePath{
    
    return [[self applicationDocumentsDirectory] stringByAppendingPathComponent:ckCoreDataStoreFileName];
}

- (NSURL *) storeURL{
    
    return [NSURL fileURLWithPath:[self storePath]];
}

- (NSString *) applicationDocumentsDirectory {	
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? paths[0] : nil;
    return basePath;
}

- (BOOL) save{
    
    if(![self.managedObjectContext hasChanges])
        return YES;
	
	[self.managedObjectContext lock];
	
    int insertedObjectsCount = [[self.managedObjectContext insertedObjects] count];
	int updatedObjectsCount = [[self.managedObjectContext updatedObjects] count];
	int deletedObjectsCount = [[self.managedObjectContext deletedObjects] count];
    
	NSDate *startTime = [NSDate date];
    
	NSError *error = nil;
    @try {
        [self.managedObjectContext save:&error];
    }
    @catch (NSException *exception) {
        NSLog(@"******** CORE DATA FAILURE: Failed to save to data store: %@", [error localizedDescription]);
		NSArray* detailedErrors = [error userInfo][NSDetailedErrorsKey];
		if(detailedErrors != nil && [detailedErrors count] > 0) {
			for(NSError* detailedError in detailedErrors) {
				NSLog(@"  DetailedError: %@", [detailedError userInfo]);
			}
		}
		else {
			NSLog(@"******** CORE DATA FAILURE: %@", [error userInfo]);
		}
    }
    @finally {
        
    }
	
    NSLog(@"Created: %i, Updated: %i, Deleted: %i, Time: %f seconds %@", insertedObjectsCount, updatedObjectsCount, deletedObjectsCount, ([startTime timeIntervalSinceNow] *-1), [NSThread currentThread].isMainThread ? @"(on main thread)" : @"");
    
    if(self.managedObjectContext.parentContext != nil){
        
        [self.managedObjectContext.parentContext performBlock:^{
           
            [self.managedObjectContext.parentContext save:nil];
        }];
    }
	
	[self.managedObjectContext unlock];
    
    return YES;
}

- (NSManagedObject *)objectWithURI:(NSURL *)uri {
    
    NSManagedObjectID *objectID =
    [[self persistentStoreCoordinator] managedObjectIDForURIRepresentation:uri];
    
    if (!objectID) {
        return nil;
    }
    
    NSManagedObject *objectForID = [self.managedObjectContext objectWithID:objectID];
    
    if (![objectForID isFault]){
        return objectForID;
    }
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:[objectID entity]];
    
    NSPredicate *predicate = [NSComparisonPredicate predicateWithLeftExpression: [NSExpression expressionForEvaluatedObject] rightExpression: [NSExpression expressionForConstantValue:objectForID] modifier:NSDirectPredicateModifier type:NSEqualToPredicateOperatorType options:0];
    
    [request setPredicate:predicate];
    
    NSArray *results = [self.managedObjectContext executeFetchRequest:request error:nil];
    if ([results count] > 0 )
    {
        return results[0];
    }
    
    return nil;
}


@end
