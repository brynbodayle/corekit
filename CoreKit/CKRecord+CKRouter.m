//
//  CKRouter+CKRecord.m
//  CoreKit
//
//  Created by Matt Newberry on 8/1/11.
//  Copyright 2011 MNDCreative, LLC. All rights reserved.
//

#import "CKRecord+CKRouter.h"
#import "CKRecord.h"
#import "NSString+InflectionSupport.h"
#import "CoreSupport.h"

@implementation CKRecord (CKRouter_CKRecord)

+ (void) mapToRemotePath:(NSString *) path{
    
    [self mapToRemotePath:path forRequestMethod:CKRequestMethodALL];
}

+ (void) mapToRemotePath:(NSString *) path forRequestMethod:(CKRequestMethod) method{
    
    [[CKRouter sharedRouter] mapModel:[self class] toRemotePath:path forRequestMethod:method];
}

+ (void) mapInstancesToRemotePath:(NSString *) path{
    
    [self mapInstancesToRemotePath:path forRequestMethod:CKRequestMethodALL];
}

+ (void) mapInstancesToRemotePath:(NSString *) path forRequestMethod:(CKRequestMethod) method{
    
    [[CKRouter sharedRouter] mapInstancesOfModel:[self class] toRemotePath:path forRequestMethod:method];
}

+ (void) mapRelationship:(NSString *) relationship toRemotePath:(NSString *) path{
    
    [self mapRelationship:relationship toRemotePath:path forRequestMethod:CKRequestMethodALL];
}

+ (void) mapRelationship:(NSString *) relationship toRemotePath:(NSString *) path forRequestMethod:(CKRequestMethod) method{
    
    [[CKRouter sharedRouter] mapRelationship:relationship forModel:[self class] toRemotePath:path forRequestMethod:method];
}

+ (void) mapAttribute:(NSString *) attribute toRemoteKey:(NSString *) remoteKey{
    
    [[CKRouter sharedRouter] mapLocalAttribute:attribute toRemoteKey:remoteKey forModel:[self class]];
}

+ (NSString *) attributeForRemoteKey:(NSString *) remoteKey{
    
    return [[CKRouter sharedRouter] localAttributeForRemoteKey:remoteKey forModel:[self class]];
}

+ (NSString *) remoteKeyForAttribute:(NSString *) attribute{
    
    return [[CKRouter sharedRouter] remoteKeyForLocalAttribute:attribute forModel:[self class]];
}

+ (CKRouterMap *) mapForRequestMethod:(CKRequestMethod) method{
    
    CKRouterMap *map = [[CKRouter sharedRouter] mapForModel:[self class] forRequestMethod:method];
    
    if(map == nil){
        
        map = [CKRouterMap map];
        map.model = [self class];
        map.requestMethod = method;
        
        NSString *resourceName = [[self entityNameWithPrefix:NO] pluralForm];
        map.remotePath = $S(@"%@/%@", [self baseURL], [resourceName lowercaseString]);
    }
    
    if(map.model == 0){
        
        map.model = [self class];
    }
    
    return map;
}

- (CKRouterMap *) mapForRequestMethod:(CKRequestMethod) method{
    
    CKRouterMap *map = [[CKRouter sharedRouter] mapForInstancesOfModel:[self class] forRequestMethod:method];

    if(map == nil){
        
        CKRouterMap *classMap = [[CKRouter sharedRouter] mapForModel:[self class] forRequestMethod:method];
        
        map = [CKRouterMap map];
        map.model = [self class];
        map.isInstanceMap = YES;
        
        if(classMap == nil){
            
            NSString *resourceName = [[[self class] entityNameWithPrefix:NO] pluralForm];
            map.remotePath = [NSString stringWithFormat:@"%@/%@/(%@)", [[self class] baseURL], [resourceName lowercaseString], [[self class] primaryKeyName]];
        }
        else{
            
            map.remotePath = $S(@"%@/(%@)", classMap.remotePath, [[self class] primaryKeyName]);
        }
    }
    
    map.requestMethod = method;
    map.object = self;
    
    if(map.model == 0){
        
        map.model = [self class];
    }
    
    return map;
}

- (CKRouterMap *) mapForRelationship:(NSString *) relationship{
    
    return [self mapForRelationship:relationship forRequestMethod:CKRequestMethodALL];
}

- (CKRouterMap *) mapForRelationship:(NSString *) relationship forRequestMethod:(CKRequestMethod) method{
    
    CKRouterMap *map = [self mapForRequestMethod:CKRequestMethodGET];
    
    NSString *parentPath = [map.remotePath stringByReplacingOccurrencesOfString:[[self class] baseURL] withString:@""];
    
    if([[parentPath substringToIndex:0] isEqualToString:@"/"]){
      
        parentPath = [parentPath substringFromIndex:1];
    };
    
    NSDictionary *relationships = [[[self class] entityDescription] relationshipsByName];
    
    if([[relationships allKeys] containsObject:relationship]){
        
        map.remotePath = $S(@"%@/%@/%@", [[self class] baseURL], parentPath, relationship);
        map.localAttribute = relationship;
    }
    
    return map;
}

@end
