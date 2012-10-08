//
//  CKTableViewDataSource.h
//  CoreKit
//
//  Created by Matt Newberry on 9/20/11.
//  Copyright (c) 2011 MNDCreative, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "CKManager.h"

@protocol CKTableViewDelegate <NSObject>

@optional
- (void) dataSourceDidLoad;
- (void) dataSourceWillLoad;
- (void) configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath withObject:(id) object;
- (Class) classForObject:(id) object;

@end

@interface CKTableViewDataSource : NSObject <NSFetchedResultsControllerDelegate, UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSEntityDescription *entityDescription;
@property (nonatomic, assign) Class cellClass;
@property (nonatomic, strong) id <CKTableViewDelegate> delegate;

+ (id) dataSourceForEntity:(NSString *) entity andTableView:(UITableView *) tableView;
- (NSInteger) count;
- (id) objectAtIndexPath:(NSIndexPath *) indexPath;

@end
