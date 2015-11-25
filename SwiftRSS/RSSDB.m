//  RSSDB.m
//  iOS 8 version
//  Copyright (c) 2010-2015 Bill Weinman. All rights reserved.

#import "RSSDB.h"

@interface RSSDB() {
    NSMutableArray * idList;
};

@end

@implementation RSSDB

static const NSUInteger kDefaultMaxItemsPerFeed = 50;

- (NSString *) getVersion {
    return kRSSDBVersion;
}

- (RSSDB *) initWithRSSDBFilename: (NSString *) fn {
    if ((self = (RSSDB *) [super initWithDBFilename:fn])) {
        idList = [[NSMutableArray alloc] init];
    }
    [self setupDatabase];
    return self;
}

- (NSNumber *) getMaxItemsPerFeed {
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    NSNumber * maxItemsPerFeed = [defaults objectForKey:@"max_items_per_feed"];
    // the device doesn't initialize standardUserDefaults until the preference pane has been visited once
    if (!maxItemsPerFeed) maxItemsPerFeed = @(kDefaultMaxItemsPerFeed);
    return maxItemsPerFeed;
}

- (void) setupDatabase {
    [self beginTransaction];
    if (![self tableExists:kRSSFeedTableName]) {
        [self doQuery:kCreateFeed];
        [self doQuery:kInsertLynda];
        [self doQuery:kInsertLynda2];
        [self doQuery:kInsertBW];
    }
    if (![self tableExists:kRSSItemTableName]) {
        [self doQuery:kCreateItem];
    }
    if (![self tableExists:kRSSFeedGroupTableName]) {
        [self doQuery:kCreateFeedgroup];
        [self doQuery:kInsertFeedgroup];
    }
    if (![self columnExistsInTable:kRSSFeedTableName withColumnName:@"group_id"]) {
        [self doQuery:kAddColumnGroupId];
    }
    [self doQuery:kIndexFeedUrl];
    [self commitTransaction];
}

#pragma mark Feed methods

- (NSArray *) getFeedIDs {
    NSDictionary * row;
    [idList removeAllObjects];  // reset the array
    
    NSString * query = [NSString stringWithFormat:@"SELECT id FROM %@ ORDER BY LOWER(title)", kRSSFeedTableName];
    for (row in [self getQuery:query]) {
        [idList addObject:row[@"id"]];
    }
    
    return idList;
}

- (NSArray *) getFeedIDsForGroup: (NSNumber* ) groupid {
    NSDictionary * row;
    [idList removeAllObjects];  // reset the array
    
    NSString * query;
    if ([groupid isEqual:@0]) {
        query = [NSString stringWithFormat:@"SELECT id FROM %@ WHERE group_id IS NULL OR group_id = ? ORDER BY LOWER(title)", kRSSFeedTableName];
    } else {
        query = [NSString stringWithFormat:@"SELECT id FROM %@ WHERE group_id = ? ORDER BY LOWER(title)", kRSSFeedTableName];
    }
    for (row in [self getQuery:query withParams:@[groupid]]) {
        [idList addObject:row[@"id"]];
    }
    
    return idList;
}

- (NSDictionary *) getFeedRow: (NSNumber *) rowid {
    self.tableName = kRSSFeedTableName;
    return [self getRow:rowid];
}

- (NSDictionary *) getFeedRowByURL: (NSString *) urlString {
    NSString * query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE url = ?", kRSSFeedTableName];
    [self prepareQuery:query withParams:@[urlString]];
    return [self getPreparedRow];
}

- (void) deleteFeedRow: (NSNumber *) rowid {
    [self beginTransaction];
    NSString * query1 = [NSString stringWithFormat:@"DELETE FROM %@ WHERE feed_id = ?", kRSSItemTableName];
    NSString * query2 = [NSString stringWithFormat:@"DELETE FROM %@ WHERE id = ?", kRSSFeedTableName];
    [self doQuery:query1 withParams: @[rowid]];
    [self doQuery:query2 withParams: @[rowid]];
    [self commitTransaction];
}

// note legacy behavior: this returns nil for new rows
- (NSNumber *) addFeedRow: (NSDictionary *) feed {
    self.tableName = kRSSFeedTableName;
    NSString * query = [NSString stringWithFormat:@"SELECT id FROM %@ WHERE url = ?", kRSSFeedTableName];
    NSNumber * rowid = [self valueFromQuery:query withParams: @[feed[kRSSFeedURLKey]]];
    
    [self beginTransaction];
    if (rowid) {
        [self updateRow:feed forRowID:rowid];
    } else {
        [self insertRow:feed];
    }
    [self commitTransaction];
    return rowid ? rowid : nil;
}

- (void) updateFeed: (NSDictionary *) feed forRowID: (NSNumber *) rowid {
    self.tableName = kRSSFeedTableName;
    NSDictionary * rec = @{@"title": feed[@"title"], @"desc": feed[@"desc"]};
    [self beginTransaction];
    [self updateRow:rec forRowID:rowid];
    [self commitTransaction];
}

- (NSNumber *) countFeeds {
    return [self valueFromQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM %@", kRSSFeedTableName]];
}

#pragma mark - Item methods

- (NSDictionary *) getItemRow: (NSNumber *) rowid {
    self.tableName = kRSSItemTableName;
    return [self getRow:rowid];
}

- (void) deleteItemRow: (NSNumber *) rowid {
    self.tableName = kRSSItemTableName;
    [self beginTransaction];
    [self deleteRow:rowid];
    [self commitTransaction];
}

- (void) deleteOldItems:(NSNumber *)feedID {
    NSString * query = [NSString stringWithFormat:@"DELETE FROM %@ WHERE feed_id = ? AND id NOT IN "
                        @"(SELECT id FROM %@ WHERE feed_id = ? ORDER BY pubdate DESC LIMIT ?)", kRSSItemTableName, kRSSItemTableName];
    [self beginTransaction];
    [self doQuery:query withParams: @[feedID, feedID, [self getMaxItemsPerFeed]]];
    [self commitTransaction];
}

- (NSArray *) getItemIDs:(NSNumber *)feedID {
    NSDictionary * row;
    [idList removeAllObjects];  // reset the array
    
    NSString * query = [NSString stringWithFormat:@"SELECT id FROM %@ WHERE feed_id = ? ORDER BY pubdate DESC", kRSSItemTableName];
    for (row in [self getQuery:query withParams: @[feedID]]) {
        [idList addObject:row[@"id"]];
    }
    
    return idList;
}

- (NSNumber *) addItemRow: (NSDictionary *) item {
    self.tableName = kRSSItemTableName;
    NSString * query = [NSString stringWithFormat:@"SELECT id FROM %@ WHERE url = ? AND feed_id = ?", kRSSItemTableName];
    NSNumber * rowid = [self valueFromQuery:query withParams: @[item[kRSSItemURLKey], item[kRSSItemFeedIdKey]]
                        ];
    [self beginTransaction];
    if (rowid) {
        [self updateRow:item forRowID:rowid];
    } else {
        rowid = [self insertRow:item];
    }
    [self commitTransaction];
    return rowid;
}

- (NSNumber *) countItems:(NSNumber *)feedID {
    NSString * query = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE feed_id = ?", kRSSItemTableName];
    return [self valueFromQuery:query withParams: @[feedID]];
}

#pragma mark Feedgroup methods

- (NSDictionary *) getGroupRow:(NSNumber *) groupid {
    self.tableName = kRSSFeedGroupTableName;
    return [self getRow:groupid];
}

- (NSNumber *) countFeedsInGroup: (NSNumber *) groupid {
    NSString * query = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE group_id = ?", kRSSFeedTableName];
    NSNumber * rs = [self valueFromQuery:query withParams:@[groupid]];
    return rs;
}

- (NSNumber *) countFeedsInNoGroup {
    NSString * query = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE group_id IS NULL OR group_id = ?", kRSSFeedTableName];
    NSNumber * rs = [self valueFromQuery:query withParams:@[@0]];
    return rs;
}

- (NSArray*) getGroupIDs {
    NSDictionary * row;
    [idList removeAllObjects];  // reset the array
    
    NSString * query = [NSString stringWithFormat:@"SELECT id FROM %@ ORDER BY LOWER(title)", kRSSFeedGroupTableName];
    for (row in [self getQuery:query]) {
        [idList addObject:row[@"id"]];
    }
    
    return idList;
}

- (NSNumber *) countFeedgroups {
    return [self valueFromQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM %@", kRSSFeedGroupTableName]];
}

@end
