//
//  CKRecord.m
//  CoreKit
//
//  Created by Matt Newberry on 7/19/11.
//  Copyright 2011 MNDCreative, LLC. All rights reserved.
//

#import "CKRecord.h"
#import "CKManager.h"
#import "CKDefines.h"
#import "CKSupport.h"
#import "CKCoreData.h"
#import "CKRecordPrivate.h"
#import "CKResult.h"
#import "CKRecord+CKRouter.h"
#import "CKRequest.h"
#import "NSString+InflectionSupport.h"

@implementation CKRecord

@synthesize attributes = _attributes,delegate=_delegate;

- (id) initWithEntity:(NSEntityDescription *)entity insertIntoManagedObjectContext:(NSManagedObjectContext *)context{
    
    self = [super initWithEntity:entity insertIntoManagedObjectContext:context];
    
    if (self) {        
        _attributes = [[[self class] entityDescription] propertiesByName];
    }
    
    return self;
}

#pragma mark -
#pragma mark Entity Methods

+ (void) setup{
    
}

+ (NSString *) entityName {
	
	return [self entityNameWithPrefix:YES];
}

+ (NSString *) entityNameWithPrefix:(BOOL) includePrefix{
    
    NSMutableString *name = [NSMutableString stringWithString:[NSString stringWithFormat:@"%@", self]];

    if([ckCoreDataClassPrefix length] > 0 && !includePrefix)
        [name replaceOccurrencesOfString:ckCoreDataClassPrefix withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [ckCoreDataClassPrefix length])];
	
	return name;
}

+ (NSEntityDescription *) entityDescription{
	
	return [NSEntityDescription entityForName:[self entityName] inManagedObjectContext:[self managedObjectContext]];
}

+ (NSFetchRequest *) fetchRequest{
	
	NSFetchRequest *fetch = [[NSFetchRequest alloc] init];
	[fetch setEntity:[self entityDescription]];
    [fetch setFetchBatchSize:20];
    
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:[self primaryKeyName] ascending:NO];
    NSArray *sortDescriptors = @[sortDescriptor];
    [fetch setSortDescriptors:sortDescriptors];
    
	return fetch;
}


#pragma mark -
#pragma mark Saving
+ (BOOL) save{
        
    return [[[CKManager sharedManager] coreData] save];
}

- (BOOL) save{
    
    return [[self class] save];
}

#pragma mark -
#pragma mark Creating, Updating, Deleting

+ (id) blank{
    
    return [[self alloc] initWithEntity:[self entityDescription] insertIntoManagedObjectContext:[self managedObjectContext]];
}

+ (id) build:(id) data{
    
    if ([data isKindOfClass:[NSArray class]]) {
        
        NSMutableArray *returnValue = [NSMutableArray arrayWithCapacity:[data count]];
        
        [data enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
           
            id object = [self build:obj];
            
            if(object != nil)
                [returnValue addObject:object];
        }];
        
        return returnValue;
    }
    
    else if ([data isKindOfClass:[NSDictionary class]]) {
        
        if([[data allKeys] containsObject:[self primaryKeyName]]){
            
            id resourceId = data[[self primaryKeyName]];
            
            if (resourceId != nil){
                
                id __strong resource = [self findById:resourceId];
                
                NSMutableArray *__strong returnValue = resource == nil ? [self create:data] : [resource update:data];
                return returnValue;
            }
            else{
                NSMutableArray *__strong returnValue = [self create:data];
                return returnValue;
            }
        }
    }
        
    return nil;
}

+ (id) create:(id) data{
               
	id returnValue = [[self blank] update:data];
        
    return returnValue;
}

- (id) update:(NSDictionary *) data{
                            
        [data enumerateKeysAndObjectsWithOptions:0 usingBlock:^(id key, id obj, BOOL *stop){
            
            NSString *localKey = [[CKRouter sharedRouter] localAttributeForRemoteKey:key forModel:[self class]];
            NSPropertyDescription *propertyDescription = [self propertyDescriptionForKey:localKey];
            
            if(propertyDescription != nil){
                
                if([propertyDescription isKindOfClass:[NSRelationshipDescription class]])
                    [self setRelationship:localKey value:obj relationshipDescription:(NSRelationshipDescription *) propertyDescription];
                else if([propertyDescription isKindOfClass:[NSAttributeDescription class]]){
                    
                    NSAttributeDescription *attributeDescription = (NSAttributeDescription *) propertyDescription;
                    [self setProperty:localKey value:obj attributeType:[attributeDescription attributeType]];
                }
            }
        }];
            
        if(![self isInserted]){
            
            [self didInsertRecord:self withData:data];
        }
        
        [self didUpdateRecord:self withData:data];
        
        NSError *error = nil;
        if(![self validateForUpdate:&error]){
            NSLog(@"%@", error);
        }
        
        [[self managedObjectContext] refreshObject:self mergeChanges:YES];
     
    return self;
}

+ (void) updateWithPredicate:(NSPredicate *)predicate withData:(NSDictionary *)data{
 
    [[self findWithPredicate:predicate] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
       
        [obj update:data];
    }];
}

+ (void) removeAll{
    
	[self removeAllWithPredicate:nil];
}

+ (void) removeAllWithPredicate:(NSPredicate *) predicate{
	
	NSFetchRequest *request = [self fetchRequest];
    [request setPredicate:predicate];
    
    NSError *error = nil;
    NSArray *results = [[self managedObjectContext] executeFetchRequest:request error:&error];
    
    [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
       
        [obj remove];
    }];
}

- (void) remove{
	
	[[self managedObjectContext] deleteObject:self];
}

- (void) removeLocallyAndRemotely{
    
    [self removeRemotely:nil errorBlock:nil];
    [self remove];
}

#pragma mark -
#pragma mark Remote Syncronization
+ (void) get:(CKParseBlock) parseBlock completionBlock:(CKResultBlock) completionBlock errorBlock:(CKResultBlock) errorBlock{
    
    CKRequest *request = [self requestForGet];
    request.parseBlock = parseBlock;
    request.completionBlock = completionBlock;
    request.errorBlock = errorBlock;
    
    [[CKManager sharedManager] sendRequest:request];    
}

+ (CKRequest *) requestForGet{
    
    CKRequest *request = [CKRequest requestWithMap:[self mapForRequestMethod:CKRequestMethodGET]];
    request.baseURL = [self baseURL];
    
    return request;
}

- (void) post:(CKParseBlock) parseBlock completionBlock:(CKResultBlock) completionBlock errorBlock:(CKResultBlock) errorBlock{
    
    [self sync:[self requestForPost] parseBlock:parseBlock completionBlock:completionBlock errorBlock:errorBlock];
}

- (CKRequest *) requestForPost{
    
    CKRequest *request = [CKRequest requestWithMap:[self mapForRequestMethod:CKRequestMethodPOST]];
    request.body = [self serialize];
    request.baseURL = [[self class] baseURL];
    
    return request;    
}

- (void) put:(CKParseBlock) parseBlock completionBlock:(CKResultBlock) completionBlock errorBlock:(CKResultBlock) errorBlock{
        
    [self sync:[self requestForPut] parseBlock:parseBlock completionBlock:completionBlock errorBlock:errorBlock];
}

- (CKRequest *) requestForPut{
    
    CKRequest *request = [CKRequest requestWithMap:[self mapForRequestMethod:CKRequestMethodPUT]];
    request.body = [self serialize];
    request.baseURL = [[self class] baseURL];
    
    return request;
}

- (void) get:(CKParseBlock) parseBlock completionBlock:(CKResultBlock) completionBlock errorBlock:(CKResultBlock) errorBlock{
    
    CKResultBlock updatedCompletionBlock = ^(CKResult *result){
        
        [self.managedObjectContext refreshObject:self mergeChanges:YES];
        
        if(completionBlock != nil)
            completionBlock(result);
    };
        
    [self sync:[self requestForGet] parseBlock:parseBlock completionBlock:updatedCompletionBlock errorBlock:errorBlock];
}

- (void) getWithRelationships:(CKResultBlock) completionBlock errorBlock:(CKResultBlock) errorBlock{
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    __block NSMutableDictionary *data = [NSMutableDictionary dictionary];
    
    dispatch_group_async(group, queue, ^{
        
        CKRequest *request = [self requestForGet];
        dispatch_group_async(group, queue, ^{
            
            CKResult *result = [request sendSyncronously];
            
            if(result.object != nil){
                
                data[[[self class] entityName]] = result.object;
            }
            
            for(__block NSString *relationship in [self relationshipsToFetch]){
                
                dispatch_group_async(group, queue, ^{
                    
                    CKRequest *relationshipRequest = [self requestForRelationship:relationship];
                    CKResult *relationshipResult = [relationshipRequest sendSyncronously];
                    
                    if(relationshipResult.object != nil){
                        
                        data[relationship] = relationshipResult.object;
                    }
                });
            }
        });
    });
    
    dispatch_group_notify(group, queue, ^{
        
        CKResult *result = [CKResult resultWithRequest:[self requestForGet] andError:nil];
        [result setObjects:@[data]];
        
        if(completionBlock != nil && ![result isError])
            completionBlock(result);
        else if(errorBlock != nil && [result isError])
            errorBlock(result);
        
        dispatch_release(queue);
    });
}

- (CKRequest *) requestForGet{
    
    CKRequest *request = [CKRequest requestWithMap:[self mapForRequestMethod:CKRequestMethodGET]];
    request.baseURL = [[self class] baseURL];
    
    return request;
}

- (void) removeRemotely:(CKResultBlock) completionBlock errorBlock:(CKResultBlock) errorBlock{
    
   [self sync:[self requestForRemoveRemotely] parseBlock:nil completionBlock:completionBlock errorBlock:errorBlock];
}

- (CKRequest *) requestForRemoveRemotely{
    
    CKRequest *request = [CKRequest requestWithMap:[self mapForRequestMethod:CKRequestMethodDELETE]];
    request.baseURL = [[self class] baseURL];
    
    return request;
}

- (CKResult *) fetchRelationshipSyncronously:(NSString *) relationship{
    
    CKRequest *request = [self requestForRelationship:relationship];
    CKResult *result = [request sendSyncronously];
        
    if(!result.error){
     
        for(NSManagedObject *obj in result.objects){
            
            NSString *key = [self keyForInverseOfSelfInObject:(CKRecord *)obj];
            
            if(key)
                [obj setValue:self forKey:key];
        }
    }
    
    [self save];
    
    return  result;
}

- (void) fetchRelationship:(NSString *) relationship parseBlock:(CKParseBlock) parseBlock completionBlock:(CKResultBlock) completionBlock errorBlock:(CKResultBlock) errorBlock{
        
    CKResultBlock updatedCompletionBlock = ^(CKResult *result){
        
        if([result.objects count] > 0){
         
            [self update:@{ relationship : result.objects }];
            [self save];
            
            [self.managedObjectContext refreshObject:self mergeChanges:YES];
        }
        
        if(completionBlock != nil)
            completionBlock(result);
    };
    
    [self sync:[self requestForRelationship:relationship] parseBlock:parseBlock completionBlock:updatedCompletionBlock errorBlock:errorBlock];    
}

- (CKRequest *) requestForRelationship:(NSString *) relationship{
    
    CKRequest *request = [CKRequest requestWithMap:[self mapForRelationship:relationship forRequestMethod:CKRequestMethodGET]];
    //request.relationshipObject = self;
    
    return request;
}

- (void) sync{
    
    if(![self isInserted])
        [self put:nil completionBlock:nil errorBlock:nil];
    
    else if([self isUpdated])
        [self post:nil completionBlock:nil errorBlock:nil];
    
    else if([self isDeleted])
        [self removeRemotely:nil errorBlock:nil];
    
    else
        [self get:nil completionBlock:nil errorBlock:nil];
}

- (void) sync:(CKRequest *) request parseBlock:(CKParseBlock) parseBlock completionBlock:(CKResultBlock) completionBlock errorBlock:(CKResultBlock) errorBlock{
    
    if(request.parseBlock == nil)
        request.parseBlock = parseBlock;
    
    if(request.completionBlock == nil)
        request.completionBlock = completionBlock;
    
    if(request.errorBlock == nil)
        request.errorBlock = errorBlock;    
    
    [request send];
}


- (id) serialize{
        
    return [[CKManager sharedManager] serialize:[self serializedValue]];
}

- (NSMutableDictionary *) serializedValue{
	
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    for (NSPropertyDescription *prop in [[[self class] entityDescription] properties]) {
        
        NSString *key = prop.name;
        
        //if ((only == nil || [only containsObject:key]) && (except == nil || ![except containsObject:key])) {
            id value = [self valueForKey:key];
        
            if (value == nil)
                value = [NSNull null];
            
            // For attributes, simply set the value
            if ([prop isKindOfClass:[NSAttributeDescription class]]) {
                // Serialize dates if serializeDates is set
                if ([value isKindOfClass:[NSDate class]])
                    value = [[self dateFormatter] stringFromDate:value];
                
                dict[key] = value;
            }
			
            else{
                
                NSRelationshipDescription *rel = (NSRelationshipDescription *)prop;
                
                if ([rel isToMany]) {
                    
                    NSSet *relResources = value;
                    NSMutableArray *relArray = [NSMutableArray arrayWithCapacity:[relResources count]];
                    
                    for (CKRecord *resource in relResources) {

                        [relArray addObject:[resource serializedValue]];
                    }
                    dict[key] = relArray;
                }
                else {
                    
                    dict[key] = value;
                }
            }
        //}
    }
    
    return dict;
}

#pragma mark -
#pragma mark Counting

+ (NSUInteger) count{
	
	return [self countWithPredicate:nil];
}

+ (NSUInteger) countWithPredicate:(NSPredicate *) predicate{
	
	NSFetchRequest *fetch = [self fetchRequest];
	[fetch setPredicate:predicate];
	
	return [[self managedObjectContext] countForFetchRequest:fetch error:nil];
}

#pragma mark -
#pragma mark Searching

+ (id) first{
    
    NSArray *results = [self findWithPredicate:nil sortedBy:nil withLimit:1];
    
    return [results count] == 1 ? results[0] : nil;
}

+ (id) last{
    
    NSArray *results = [self all];
    
    return [results count] > 0 ? [results lastObject] : nil;
}

+ (BOOL) exists:(NSNumber *)itemID{
    
    id result = [self findById:itemID];
    
    return result == nil;
}

+ (NSArray *) all{
    
    return [self allSortedBy:nil];
}

+ (NSArray *) allSortedBy:(NSString *)sortBy{
    
    return [self findWithPredicate:nil sortedBy:sortBy withLimit:0];
}

+ (NSArray *) findWithPredicate:(NSPredicate *)predicate{
    
    return [self findWithPredicate:predicate sortedBy:nil withLimit:0];
}

+ (NSArray *) findWithPredicate:(NSPredicate *)predicate sortedBy:(NSString *)sortedBy withLimit:(NSUInteger)limit{
    
    NSFetchRequest *request = [self fetchRequest];
    [request setPredicate:predicate];
    
    if([sortedBy length] > 0)
        [request setSortDescriptors:CK_SORT(sortedBy)];
    
    if(limit > 0)
        [request setFetchLimit:limit];
    
    return [[self managedObjectContext] executeFetchRequest:request error:nil];
}

+ (NSArray *) findWhereAttribute:(NSString *)attribute contains:(id)value{
    
    return [self findWithPredicate:[NSPredicate predicateWithFormat:@"%K CONTAINS %@", attribute, value]];
}

+ (NSArray *) findWhereAttribute:(NSString *)attribute equals:(id)value{
    
    return [self findWithPredicate:[NSPredicate predicateWithFormat:@"%K == %@", attribute, value]];
}

+ (id) findById:(id) itemId{
        
    NSArray *results = [self findWithPredicate:[NSPredicate predicateWithFormat:@"%K == %@", [self primaryKeyName], itemId] sortedBy:nil withLimit:1];
    
    return [results count] > 0 ? results[0] : nil;
}


#pragma mark -
#pragma mark Aggregates

+ (NSNumber *) average:(NSString *)attribute{
    
    return [self aggregateForKeyPath:[NSString stringWithFormat:@"@avg.%@", attribute]];
}

+ (NSNumber *) minimum:(NSString *)attribute{
    
    return [self aggregateForKeyPath:[NSString stringWithFormat:@"@min.%@", attribute]];
}

+ (NSNumber *) maximum:(NSString *)attribute{
    
    return [self aggregateForKeyPath:[NSString stringWithFormat:@"@max.%@", attribute]];
}

+ (NSNumber *) sum:(NSString *)attribute{
    
    return [self aggregateForKeyPath:[NSString stringWithFormat:@"@sum.%@", attribute]];
}

#pragma mark -
#pragma mark Fixtures

+ (id) fixtureNamed:(NSString *) name{
    
    return [self fixtureNamed:name atPath:nil];
}

+ (id) fixtures{
    
    return [self fixtureNamed:nil atPath:nil];
}

+ (NSArray *) fixturesAsArray{
        
    return [[self fixtures] allValues];
}

+ (id) fixtureNamed:(NSString *) name atPath:(NSString *) path{
    
    NSString *fixturePath = CKPathForBundleResource([NSBundle bundleForClass:[self class]], ckFixturePath);

    if(path == nil){
        
        NSError *error;
        
        NSArray *fixtures = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:fixturePath error:&error];
        NSArray *classFiles = [fixtures filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self BEGINSWITH %@", [self entityNameWithPrefix:NO]]];
        
        if([classFiles count] > 0)
            fixturePath = [fixturePath stringByAppendingFormat:@"/%@", classFiles[0]];
    }
    else
        fixturePath = [fixturePath stringByAppendingFormat:@"/%@", path];
    
    id contents = [[CKManager sharedManager] deserialize:[NSData dataWithContentsOfFile:fixturePath]];

    if([contents isKindOfClass:[NSDictionary class]] && name != nil && [[contents allKeys] containsObject:name])
        contents = contents[name];
    
    return contents;
}

#pragma mark -
#pragma mark Value Formatting
- (id) stringValueForKeyPath:(NSString *) keyPath{
    
    id value = [self valueForKeyPath:keyPath];
    NSString *stringValue = [NSString string];
    
    if([value isKindOfClass:[NSString class]])
        stringValue = value;
    
    else if ([value isKindOfClass:[NSNumber class]]){
        
        NSNumberFormatter *formatter = [self numberFormatter];
        
        NSAttributeDescription *description = (NSAttributeDescription *) [self propertyDescriptionForKey:keyPath];
        
        switch ([description attributeType]) {
            
            default:
                break;
                
            case NSFloatAttributeType:
            case NSDecimalAttributeType:
            case NSDoubleAttributeType:
                [formatter setMaximumFractionDigits:2];
                break;
        }
        
        stringValue = [formatter stringFromNumber:value];
    }
    
    else if([value isKindOfClass:[NSDate class]]){
        
        stringValue = [[self dateFormatter] stringFromDate:value];
    }
     
    return stringValue;
}

- (NSDateFormatter *) dateFormatter{
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = [CKManager sharedManager].dateFormat;
    
    if([formatter.dateFormat length] == 0)
        [formatter setDateFormat:[[self class] dateFormat]];
    
    return formatter;
}

- (NSNumberFormatter *) numberFormatter{
    
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    
    return formatter;
}

#pragma mark -
#pragma mark Seeds

+ (BOOL) seed{
    
    return [self seedGroup:nil];
}

+ (BOOL) seedGroup:(NSString *) groupName{
    
    NSArray *files = [CKManager seedFiles];
    NSArray *seeds = [files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self BEGINSWITH %@", [self entityNameWithPrefix:NO]]];
    return [[CKManager sharedManager] loadSeedFiles:seeds groupName:groupName];
}


#pragma mark -
#pragma mark Defaults

+ (NSString *) dateFormat{
    
    return [CKManager sharedManager].dateFormat == nil ? ckDateDefaultFormat : [CKManager sharedManager].dateFormat;
}

+ (NSDictionary *) attributeMap{
    
    return [[CKRouter sharedRouter] attributeMapForModel:[self class]];
}

+ (NSString *) primaryKeyName{
    
    return @"id";
}

+ (NSString *) baseURL{
    
    return [[CKManager sharedManager] baseURL];
}

- (NSArray *) relationshipsToFetch{
    
    return [[self relationships] allKeys];
}

- (NSDictionary *) relationships{

    return [self.entity relationshipsByName];
}

- (NSString *) keyForInverseOfSelfInObject:(CKRecord *) object{
    
    if(![object isKindOfClass:[CKRecord class]])
        return nil;
    
    __block NSString *relationshipKey;
    
    [[object relationships] enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop){
        
        NSRelationshipDescription *desc = (NSRelationshipDescription *) obj;
        
        if([desc.destinationEntity.managedObjectClassName isEqualToString:[self entity].managedObjectClassName]){
            relationshipKey = key;
        }
    }];
    
    return relationshipKey;
}

- (CKRecord *) threadedSafeSelf{
    
    return (CKRecord *) [[CKManager sharedManager].coreData objectWithURI:[[self objectID] URIRepresentation]];
}

#pragma mark -
#pragma mark Delegate
- (void) didInsertRecord:(CKRecord *) record withData:(NSDictionary *) data{
    
}


- (void) didUpdateRecord:(CKRecord *) record withData:(NSDictionary *) data{
    
}

@end
