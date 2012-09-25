//
//  CKNSURLConnection.m
//  CoreKit
//
//  Created by Matt Newberry on 7/18/11.
//  Copyright 2011 MNDCreative, LLC. All rights reserved.
//

#import "CKNSURLConnection.h"
#import "CKDefines.h"
#import "CKSupport.h"
#import "CKManager.h"
#import "NSString+InflectionSupport.h"
#import <UIKit/UIKit.h>

@implementation CKNSURLConnection

@synthesize responseCode = _responseCode;
@synthesize responseData = _responseData;
@synthesize request = _request;
@synthesize connection = _connection;
@synthesize responseHeaders = _responseHeaders;
@synthesize syncronousQueue = _syncronousQueue;

#define LOG_DEBUG YES

- (id) init{
    
    self = [super init];
    if (self) {
        
        self.syncronousQueue = [[NSOperationQueue alloc] init];
        _responseData = [[NSMutableData alloc] init];
    }
    
    return self;
}

- (void) printDebug:(CKResult *) result{
    
    if(LOG_DEBUG)
        NSLog(@"%@ %i %@", [_request methodString], _responseCode, [_request remoteURL]);
}

-(BOOL) connectionVerified{
    
    BOOL connected = CK_CONNECTION_AVAILABLE();
    
	if(!connected){
        
        //standardized way to handle errors?
    }
    
	return connected;
}

- (void) cancel{
	
    [_connection cancel];
	[_request connectionCancelled:self];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    
}

- (void) send:(CKRequest *) request{
    
    self.request = request;
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    
    if(![self connectionVerified])
		return;
        
    _connection = [[NSURLConnection	alloc] initWithRequest:[_request remoteRequest] delegate:self];
    self.request.connection = _connection;
    
    do {
        
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:_request.connectionTimeout]];
    } while (!self.request.completed);
    
}

- (CKResult *) sendSyncronously:(CKRequest *) request{
	
    __block CKResult *syncResult = [CKResult resultWithRequest:request andResponseBody:nil];
    __block BOOL finished = NO;
    
    request.completionBlock = ^(CKResult *result){
        finished = YES;
    };
    
    [self send:request];
        
    NSURLResponse *response;
    NSData *responseData = [NSURLConnection sendSynchronousRequest:[request remoteRequest] returningResponse:&response error:nil];
    [syncResult setResponseBody:responseData];
    
    [self printDebug:syncResult];
    
    return syncResult;
}

- (void) connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response{
	
	_responseCode = [response statusCode];
    _responseHeaders = [response allHeaderFields];
}

- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data{
    
	if(_request.parseBlock != nil){
        
        id object = [[CKManager sharedManager] deserialize:data];
        
        [_request connection:self didParseObject:object];
    }
    
    [_responseData appendData:data];
}

- (void) connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge{
    
    [[challenge sender] useCredential:[_request credentials] forAuthenticationChallenge:challenge];
}

- (void) connection:(NSURLConnection *)connection didFailWithError:(NSError *)error{
    
    _request.failed = YES;
    _request.completed = YES;
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	
	CKResult *result = [CKResult resultWithRequest:_request andError:&error];
    
	[_request connection:self didFailWithResult:result];
    
    [self printDebug:result];
}

- (void) connectionDidFinishLoading:(NSURLConnection *)connection{
	
	NSLog(@"CON FINISHED - MAIN THREAD ? %i", [NSThread currentThread].isMainThread);
	
    _request.completed = YES;
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	
    CKResult *result = [CKResult resultWithRequest:_request andResponseBody:_responseData];
    result.responseCode = _responseCode;
    result.responseHeaders = _responseHeaders;
        
    [_request connection:self didFinishWithResult:result];
    
    [self printDebug:nil];
}

@end