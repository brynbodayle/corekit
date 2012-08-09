//
//  CKRequest.m
//  CoreKit
//
//  Created by Matt Newberry on 7/18/11.
//  Copyright 2011 MNDCreative, LLC. All rights reserved.
//

#import "CKRequest.h"
#import "CKDefines.h"
#import "CKRouterMap.h"
#import "CKManager.h"
#import "NSString+InflectionSupport.h"
#import <UIKit/UIKit.h>
#import "zlib.h"


static NSString * const BOUNDRY = @"0xKhTmLbOuNdArY";

@implementation CKRequest

@synthesize routerMap = _routerMap;
@synthesize username = _username;
@synthesize password = _password;
@synthesize remotePath = _remotePath ;
@synthesize method = _method;
@synthesize headers = _headers;
@synthesize parameters = _parameters;
@synthesize body = _body;
@synthesize syncronous = _syncronous;
@synthesize started = _started;
@synthesize completed = _completed;
@synthesize failed = _failed;
@synthesize batch = _batch;
@synthesize isBatched = _isBatched;
@synthesize secure = _secure;
@synthesize batchPageString = _batchPageString;
@synthesize batchMaxPerPageString = _batchMaxPerPageString;
@synthesize batchNumPerPage = _batchNumPerPage;
@synthesize batchMaxPages = _batchMaxPages;
@synthesize batchCurrentPage = _batchCurrentPage;
@synthesize connectionTimeout = _connectionTimeout;
@synthesize interval = _interval;
@synthesize connection = _connection;
@synthesize parser = _parser;
@synthesize completionBlock = _completionBlock;
@synthesize errorBlock = _errorBlock;
@synthesize parseBlock = _parseBlock;
@synthesize baseURL=_baseURL;
@synthesize relationshipObject = _relationshipObject;
@synthesize hasFile = _hasFile;

- (id) initWithRouterMap:(CKRouterMap *) map{

    self = [super init];
    if (self) {
        
        _interval = CKRequestIntervalNone;
        _headers = [[NSMutableDictionary alloc] init];
        _parameters = [[NSMutableDictionary alloc] init];
        self.batchMaxPerPageString = @"limit";
        self.batchPageString = @"page";
        _batchNumPerPage = 50;
        _batchMaxPages = 5;
        _batchCurrentPage = 1;
        _connectionTimeout = 60;
        _secure = NO;
        _completionBlock = nil;
        _errorBlock = nil;
        _parseBlock = nil;
        _delegateThread = dispatch_get_main_queue();
        self.routerMap = map;
    }
    
    return self;
}

+ (CKRequest *) request{
    
    return [self requestWithMap:nil];
}

+ (CKRequest *) requestWithRemotePath:(NSString *) remotePath{
    
    CKRouterMap *map = [CKRouterMap mapWithRemotePath:remotePath];
    return [self requestWithMap:map];
}

+ (CKRequest *) requestWithMap:(CKRouterMap *) map{
    
    return [[self alloc] initWithRouterMap:map];
}

- (NSURLCredential *) credentials{
    
    NSString *user = [_username length] > 0 ? _username : [CKManager sharedManager].httpUser;
    NSString *password = [_password length] > 0 ? _password : [CKManager sharedManager].httpPassword;
    
    return [NSURLCredential credentialWithUser:user password:password persistence:NSURLCredentialPersistenceNone];
}

- (void) setBody:(id)body{
    
    if(![body isKindOfClass:[NSData class]]){
        
        _body = [[CKManager sharedManager] serialize:body];
    }
    else{
        
        _body = body;
    }
}

- (void) addFile:(NSData *) fileData withName:(NSString *) name forKey:(NSString *) key{
    
    _hasFile = YES;
    
    _headers[@"Content-Type"] = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", BOUNDRY];
    NSMutableData *postData = [NSMutableData dataWithCapacity:[fileData length] + 512];
    [postData appendData:[[NSString stringWithFormat:@"--%@\r\n", BOUNDRY] dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n\r\n", key,name] dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:fileData];
    [postData appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", BOUNDRY] dataUsingEncoding:NSUTF8StringEncoding]];
        
    _body = postData;
}

- (void) addHeaders:(NSDictionary *) data{
    
    [_headers addEntriesFromDictionary:data];
}

- (void) addParameters:(NSDictionary *) data{
    
    [_parameters addEntriesFromDictionary:data];
}

- (void) setRouterMap:(CKRouterMap *)routerMap{
    
    _routerMap = routerMap;
    
    self.remotePath = _routerMap.remotePath;
    self.method = _routerMap.requestMethod;
}

- (NSString *) methodString {
    
    switch (_method) {
            
        default:
		case CKRequestMethodGET:
			return @"GET";
			break;
            
		case CKRequestMethodPOST:
			return @"POST";
			break;
            
		case CKRequestMethodPUT:
			return @"PUT";
			break;
            
		case CKRequestMethodDELETE:
			return @"DELETE";
			break;
            
        case CKRequestMethodHEAD:
			return @"HEAD";
			break;
	}
}

- (NSURL *) remoteURL{
    
    NSMutableString *url = [_remotePath mutableCopy];
    NSMutableString *baseURL = [self.baseURL length] > 0 ? [self.baseURL mutableCopy] : [[CKManager sharedManager].baseURL mutableCopy];
    
    if([url rangeOfString:@"http"].location == NSNotFound){
        
        if([baseURL length] == 0){
            
            return [NSURL URLWithString:[url stringByAddingPercentEscapesUsingEncoding:4]];
        }
        
        if([baseURL length] > 0 && [url length] > 0){
            
            [url replaceOccurrencesOfString:baseURL withString:@"" options:0 range:NSMakeRange(0, [url length])];
            [url replaceOccurrencesOfString:@"//" withString:@"/" options:0 range:NSMakeRange(0, [url length])];
        }
        
        BOOL baseURLContainsTrailingSlash = [baseURL length] > 0 ? [[baseURL substringWithRange:NSMakeRange([baseURL length] - 1, 1)] isEqualToString:@"/"] : YES;
        
        if([[url substringToIndex:1] isEqualToString:@"/"] && baseURLContainsTrailingSlash)
            [url replaceCharactersInRange:NSMakeRange(0, 1) withString:@""];
        else if(!baseURLContainsTrailingSlash)
            [baseURL appendString:@"/"];
        
        if([baseURL rangeOfString:@"http"].location == NSNotFound)
            [baseURL insertString: self.secure || [CKManager sharedManager].secureAllConnections ? @"https://" : @"http://" atIndex:0];
        
        if([baseURL length] > 0)
            [url insertString:baseURL atIndex:0];
    }
    
    if(_batch || _isBatched || [CKManager sharedManager].batchAllRequests){
        
        if(!_parameters[_batchMaxPerPageString])
            _parameters[_batchMaxPerPageString] = [NSString stringWithFormat:@"%i", _batchNumPerPage];
        
        _parameters[_batchPageString] = [NSString stringWithFormat:@"%i", _batchCurrentPage];
    }
        
    if([_parameters count] > 0)
        [url appendString:[@"" stringByAddingQueryDictionary:_parameters]];
        
    return [NSURL URLWithString:[url stringByAddingPercentEscapesUsingEncoding:4]];
}

- (NSMutableURLRequest *) remoteRequest{
    
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:[self remoteURL]];
	
	[urlRequest setHTTPMethod:[self methodString]];
	[urlRequest setAllHTTPHeaderFields:_headers];
    
    if(_body != nil)
        [urlRequest setHTTPBody:_body];
    
    return urlRequest;
}

- (id) connection{
    
    return _connection == nil ? [[[CKManager sharedManager].connectionClass alloc] init] : _connection;
}

- (void) send{
    
    if(self.interval)
        [self scheduleRepeatRequest];
    
    [[CKManager sharedManager] sendRequest:self];
}

- (CKResult *) sendSyncronously{
    
    return [[CKManager sharedManager] sendSyncronousRequest:self];
}

- (void) scheduleRepeatRequest{
    
    if(self.interval < CKRequestIntervalAppDidBecomeActive){
        
        [NSTimer scheduledTimerWithTimeInterval:self.interval target:self selector:@selector(scheduledRequest:) userInfo:self repeats:YES];
    }
    
    else if(self.interval == CKRequestIntervalAppDidBecomeActive)        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sendRequest:) name:UIApplicationDidBecomeActiveNotification object:self];
    
    else if(self.interval == CKRequestIntervalAppDidEnterBackground)        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sendRequest:) name:UIApplicationDidEnterBackgroundNotification object:self];
}

- (void) scheduledRequest:(NSTimer *) timer{
    
    CKRequest *request = [timer userInfo];
    request.interval = CKRequestIntervalNone;
    [[CKManager sharedManager] sendRequest:request];
}


// delegate methods

- (void) connection:(id<CKConnection>)connection didFailWithResult:(CKResult *)result{
    
    if(_errorBlock != nil){
        
        dispatch_async(_delegateThread, ^{
                
            _errorBlock(result);
        });
    }
}

- (void) connection:(id<CKConnection>)connection didFinishWithResult:(CKResult *)result{
    
    if(_completionBlock != nil && ![result isError]){
        
        dispatch_async(_delegateThread, ^{
            
            _completionBlock(result);
        });
    }
    else if(_errorBlock != nil && [result isError]){
        
        dispatch_async(_delegateThread, ^{
            
            _errorBlock(result);
        });
    }
}

- (void) connection:(id<CKConnection>)connection didParseObject:(id)object{
    
    if(_parseBlock != nil){
        
        dispatch_async(_delegateThread, ^{
            
            _parseBlock(object);
        });
    }
}

@end
