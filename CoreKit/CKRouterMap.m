//
//  CKRouterMap.m
//  CoreKit
//
//  Created by Matt Newberry on 7/28/11.
//  Copyright 2011 MNDCreative, LLC. All rights reserved.
//

#import "CKRouterMap.h"
#import "CKRecord.h"

@implementation CKRouterMap

@synthesize model = _model;
@synthesize object = _object;
@synthesize remotePath = _remotePath;
@synthesize localAttribute = _localAttribute;
@synthesize remoteAttribute = _remoteAttribute;
@synthesize requestMethod = _requestMethod;
@synthesize isInstanceMap = _isInstanceMap;

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

+ (CKRouterMap *) map{
    
    return [[[CKRouterMap alloc] init] autorelease];
}

- (NSString *) remotePath{
    
    NSMutableString *path = [NSMutableString stringWithString:_remotePath];
    
    if(_object != nil){
     
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\((.*?)\\)" options:0 error:nil];
        
        [regex enumerateMatchesInString:path options:0 range:NSMakeRange(0, [path length]) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop){

            NSString *keyPath = [_remotePath substringWithRange:[result rangeAtIndex:1]];
                        
            id value = [_object valueForKeyPath:keyPath];
            
            if(value != nil){
                
                if(![value isKindOfClass:[NSString class]])
                    value = [value stringValue];
                
                [path replaceCharactersInRange:[path rangeOfString:[_remotePath substringWithRange:result.range]] withString:value];
            }
        }];
    }
    
    return [path lowercaseString];
}

- (BOOL) isAttributeMap{
    
    return ([_localAttribute length] > 0 && [_remoteAttribute length] > 0);
}

- (BOOL) isRelationshipMap{
    
    NSEntityDescription *entity = [_model entityDescription];
    
    if(entity){
        
        return [[[entity relationshipsByName] allKeys] containsObject:_localAttribute];
    }
    
    return NO;
}

- (BOOL) isRemotePathMap{
    
    return [_remotePath length] > 0;
}

@end
