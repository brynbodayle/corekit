//
//  CKCoreData.h
//  CoreKit
//
//  Created by Matt Newberry on 7/15/11.
//  Copyright 2011 MNDCreative, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CKCoreData : NSObject

@property (nonatomic, strong) NSManagedObjectContext *mainThreadManagedObjectContext;
@property (nonatomic, strong) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, strong) NSPersistentStoreCoordinator *persistentStoreCoordinator;

- (NSManagedObjectContext*) newManagedObjectContext:(NSManagedObjectContextConcurrencyType) concurrencyType;
- (NSManagedObjectContext *) managedObjectContext;
- (NSString *) storePath;
- (NSURL *) storeURL;
- (NSString *) persistentStoreType;
- (NSDictionary *) persistentStoreOptions;
- (BOOL) save;
- (NSString *) applicationDocumentsDirectory;
- (void) setupModels;
- (NSManagedObject *)objectWithURI:(NSURL *)uri;

@end
