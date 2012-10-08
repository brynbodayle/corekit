//
//  CKResult.m
//  CoreKit
//
//  Created by Matt Newberry on 7/18/11.
//  Copyright 2011 MNDCreative, LLC. All rights reserved.
//

#import "CKResult.h"
#import "CKDefines.h"
#import "CKManager.h"
#import "CKRecord.h"
#import "CKRouterMap.h"
#import "NSDictionary+NSDictionary_KeyPath.h"
#import "NSString+InflectionSupport.h"
#import "CKRecordPrivate.h"

@implementation CKResult

@synthesize objects = _objects;
@synthesize error = _error;
@synthesize request = _request;
@synthesize responseBody = _responseBody;
@synthesize responseHeaders = _responseHeaders;
@synthesize responseCode = _responseCode;

+ (CKResult *) resultWithRequest:(CKRequest *) request andResponseBody:(NSData *) responseBody{

    return [[self alloc] initWithRequest:request responseBody:responseBody httpResponse:nil error:nil];
}

+ (CKResult *) resultWithRequest:(CKRequest *) request andError:(NSError **) error{
 
    return [[self alloc] initWithRequest:request responseBody:nil httpResponse:nil error:error];
}

- (id) initWithRequest:(CKRequest *) request responseBody:(NSData *) responseBody httpResponse:(NSHTTPURLResponse *) httpResponse error:(NSError **) error{
    
    self = [super init];
    if (self) {
        
        self.request = request;
        self.responseBody = responseBody;
        
        if(httpResponse != nil){
            
            _responseCode = [httpResponse statusCode];
            self.responseHeaders = [httpResponse allHeaderFields];
        }
        
        if(error != nil)
            self.error = *error;
    }
    
    return self;
}

- (id) initWithObjects:(NSArray *) objects{
    
    id init = [self initWithRequest:nil responseBody:nil httpResponse:nil error:nil];
    self.objects = objects;
    
    return init;
}

- (id) object{
	
	return _objects != nil && [_objects count] > 0 ? _objects[0] : nil;
}

- (void) setResponseBody:(NSData *)responseBody{
    
    _responseBody = responseBody;
	   
	if([NSThread currentThread].isMainThread){
		NSLog(@"*************** PARSING RESPONSE BODY ON MAIN THREAD *************");
	}
	
	@autoreleasepool {
		
        if (responseBody != nil && [responseBody length] > 0){
            
            NSMutableArray *parts = [NSMutableArray arrayWithArray:[_request.remotePath componentsSeparatedByString:@"/"]];
            
            NSLog(@"PARTS - %@", parts);
            
            if([[parts lastObject] intValue] > 0)
                [parts removeLastObject];
            
            Class model = _request.routerMap.model == 0 ? NSClassFromString([[[parts lastObject] singularForm] capitalizedString]) : _request.routerMap.model;
            
            NSString *pathEntity = NSStringFromClass(model);
            NSString *entityName = [[pathEntity singularForm] lowercaseString];
            NSString *pluralEntityName = [[pathEntity pluralForm] lowercaseString];
            
            NSLog(@"model - %@ - %@", model, [[pathEntity singularForm] uppercaseString]);
			
            if(_request.routerMap.isRelationshipMap){
                
                NSEntityDescription *entity = [_request.routerMap.model entityDescription];
                
                if(entity){
                    
                    NSRelationshipDescription *relationship = [entity relationshipsByName][_request.routerMap.localAttribute];
                    model = NSClassFromString(relationship.destinationEntity.managedObjectClassName);
                }
            }
			
            id parsed = [[CKManager sharedManager] deserialize:responseBody];
            NSLog(@"**** PARSED \n %@", parsed);
            
            if(![parsed isKindOfClass:[NSArray class]] && ![parsed isKindOfClass:[NSDictionary class]])
                return;
			
            
            id finalData;
			
            NSLog(@"entity name: %@ - pluralName: %@ responsePath: %@", entityName, pluralEntityName, _request.routerMap.responseKeyPath);
            
            if([parsed isKindOfClass:[NSDictionary class]]){
				
                if([_request.routerMap.responseKeyPath length] > 0)
                    finalData = [parsed objectForKeyPath:_request.routerMap.responseKeyPath];
                else if ([[parsed allKeys] containsObject:pluralEntityName])
                    finalData = parsed[pluralEntityName];
                else if ([[parsed allKeys] containsObject:entityName])
                    finalData = parsed[entityName];
                else
                    finalData = parsed;
            }
            else{
                
                finalData = parsed;
            }
            
            NSLog(@"**** FINAL DATA \n %@", finalData);
            
            NSMutableArray *builtObjects = [NSMutableArray array];
			
            if(finalData != nil && [finalData isKindOfClass:[NSArray class]]){
                
                for(id obj in finalData){
                    
					id built = [model build:obj];
                    [builtObjects addObject:built];
                }
            }
            
            else if(parsed != nil && finalData != nil && [parsed isKindOfClass:[NSDictionary class]] && [finalData isKindOfClass:[NSDictionary class]] && ![parsed isEqualToDictionary:finalData]){
                
                id obj = [model build:finalData];
                
                NSLog(@" *** %@ built %@ object from data: %@", obj, model, finalData);
                if(obj != nil){
                    [builtObjects addObject:obj];
                }
            }
            else{
                [builtObjects addObject:finalData];
            }
            
			NSLog(@"**** BUILT OBJECTS \n %@", builtObjects);
			
            if(builtObjects > 0){
                
                self.objects = builtObjects;
            }
            else if(finalData != nil)
                self.objects = [finalData isKindOfClass:[NSArray class]] ? finalData : @[finalData];
			
            id errorHash = [parsed objectForKeyPath:_request.routerMap.errorKeyPath];
            NSLog(@"%@", errorHash);
            if(errorHash != nil && [errorHash isKindOfClass:[NSDictionary class]]){
                
                //self.error = [NSError errorWithDomain:@"com.corekit" code:_responseCode userInfo:@{ NSLocalizedDescriptionKey : errorHash }];
                
                if(_request.errorBlock != nil){
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        //_request.errorBlock(self);
                    });
                }
            }
			
			[[CKManager sharedManager].coreData save];
        }
        else
            self.objects = @[];
        
	}
}

- (BOOL) isError{
    
    return self.error != nil;
}

- (NSUInteger) countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(__unsafe_unretained id [])buffer count:(NSUInteger)len{
    
    return [_objects countByEnumeratingWithState:state objects:buffer count:len];
}

- (NSString *) stringResponseBody{
    
    NSString *string = [[NSString alloc] initWithData:_responseBody encoding:NSUTF8StringEncoding];
    
    return string;
}

- (NSArray *) resultsForQueue:(dispatch_queue_t) queue{
    
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:[self.objects count]];
    
    dispatch_sync(queue, ^{
        
        for(id object in self.objects){
            
            if([object isKindOfClass:[NSManagedObject class]]){
                
                id obj = [[CKManager sharedManager].coreData objectWithURI:[[object objectID] URIRepresentation]];
                [results addObject:obj];
            }
        }
    });
    
    return results;
}


@end
