//
//  CKRecordPrivate.m
//  CoreKit
//
//  Created by Matt Newberry on 7/21/11.
//  Copyright 2011 MNDCreative, LLC. All rights reserved.
//

#import "CKRecordPrivate.h"
#import "CKManager.h"

@implementation CKRecord (CKRecordPrivate)

+ (NSManagedObjectContext *) managedObjectContext{
    
    return [[CKManager sharedManager] managedObjectContext];
}

- (NSPropertyDescription *) propertyDescriptionForKey:(NSString *) key{
    
    return [[self.attributes allKeys] containsObject:key] ? (self.attributes)[key] : nil;
}

- (void) setProperty:(NSString *) property value:(id) value attributeType:(NSAttributeType) attributeType{
    
    if(value != nil && value != [NSNull null] && ![value isKindOfClass:[NSArray class]] && ![value isKindOfClass:[NSDictionary class]]){
        
        switch (attributeType) {
                
            case NSDateAttributeType:
                if(![value isKindOfClass:[NSDate class]] && [value isKindOfClass:[NSString class]]){
                    
                    NSDateFormatter *formatter = [self dateFormatter];
                    value = [formatter dateFromString:value];
                }
                
                break;
                
            case NSStringAttributeType:
                if(![value isKindOfClass:[NSString class]])
                    value = [value respondsToSelector:@selector(stringValue)] && ![value isEqual:[NSNull null]] ? [value stringValue] : [NSNull null];
                break;
            
            case NSBinaryDataAttributeType:
                value = [[CKManager sharedManager] serialize:value];
                break;
                
            case NSInteger16AttributeType:
            case NSInteger32AttributeType:
            case NSInteger64AttributeType:
                value = @([value intValue]);
                break;
                
            case NSFloatAttributeType:
            case NSDecimalAttributeType:
                value = @([value floatValue]);
                break;
                
            case NSDoubleAttributeType:
                value = @([value doubleValue]);
                break;
                
            case NSBooleanAttributeType:
                value = @([value boolValue]);
                break;
        }
    }
    else
        value = nil;
    
    if(value == [NSNull null])
        value = nil;
    
    NSError *error = nil;
    if(![self validateValue:&value forKey:property error:&error]){
        NSLog(@"ERROR - %@", error);
    }
    else
        [self setValue:value forKey:property];
}

- (void) setRelationship:(NSString *) key value:(id) value relationshipDescription:(NSRelationshipDescription *) relationshipDescription {
    
    id existingValue = [self valueForKey:key];
    
    Class relationshipClass = NSClassFromString([[relationshipDescription destinationEntity] managedObjectClassName]);
    id newValue = nil;
    
    if([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]]){
        
        newValue = [relationshipClass findById:@([value intValue])];
        
    }
    else if([value isKindOfClass:[NSManagedObject class]]){
        
        newValue = [[CKManager sharedManager].coreData objectWithURI:[[value objectID] URIRepresentation]];
    }
    else{
        
        if([relationshipDescription isToMany]){
            
            if([value isKindOfClass:[NSArray class]] && [value count] > 0){
                
                BOOL needToBuild = [[value objectAtIndex:0] isKindOfClass:[NSDictionary class]];
                
                if(needToBuild){
                    
                    NSMutableArray *results = [NSMutableArray array];
                    
                    for(NSDictionary * data in value){
                        
                        id builtObject = [relationshipClass build:data];
                        
                        if(builtObject != nil)
                            [results addObject:builtObject];
                    }
                    
                    newValue = [NSSet setWithArray:results];
                }
                else{
                    
                    newValue = [NSSet setWithArray:value];
                }
            }
            else if([value isKindOfClass:[NSDictionary class]]){
             
                id builtObject = [relationshipClass build:value];
                
                if(builtObject != nil)
                    newValue = [NSSet setWithArray:@[builtObject]];
            }
        }
        else{
            
            newValue = [relationshipClass build:value];
        }
    }

    if(![existingValue isEqual:newValue])
        [self setValue:newValue forKey:key];
}

+ (NSNumber *) aggregateForKeyPath:(NSString *) keyPath{
    
    NSArray *results = [[self class] all];
    
    return [results valueForKeyPath:keyPath];
}

@end
