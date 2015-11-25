//  RSSDB.h
//  iOS 8 version
//  Copyright (c) 2010-2015 Bill Weinman. All rights reserved.

#import "BWCRUD.h"

static NSString * const kRSSDBVersion = @"2.3.0";

// Alas, Swift can't use these -- it won't link to them.
// ObjC sucks at constants.
static NSString * const kRSSFeedTableName = @"feed";
static NSString * const kRSSItemTableName = @"item";
static NSString * const kRSSFeedIdKey = @"id";
static NSString * const kRSSFeedURLKey = @"url";
static NSString * const kRSSFeedTitleKey = @"title";
static NSString * const kRSSFeedDescKey = @"desc";
static NSString * const kRSSItemFeedIdKey = @"feed_id";
static NSString * const kRSSItemIdKey = @"id";
static NSString * const kRSSItemURLKey = @"url";
static NSString * const kRSSItemTitleKey = @"title";
static NSString * const kRSSItemDescKey = @"desc";
static NSString * const kRSSFeedGroupTableName = @"feedgroup";
static NSString * const kRSSGroupIdKey = @"id";
static NSString * const kRSSGroupTitleKey = @"title";

static NSString * const kCreateFeed = @"CREATE TABLE feed ( id INTEGER PRIMARY KEY, group_id INTEGER, url TEXT, title TEXT, desc TEXT, pubdate TEXT, stamp TEXT );";
static NSString * const kCreateItem = @"CREATE TABLE item ( id INTEGER PRIMARY KEY, feed_id INTEGER, url TEXT, title TEXT, desc TEXT, pubdate TEXT, body TEXT, stamp TEXT );";
static NSString * const kCreateFeedgroup = @"CREATE TABLE feedgroup ( id INTEGER PRIMARY KEY, title TEXT, stamp TEXT );";
static NSString * const kInsertFeedgroup = @"INSERT INTO feedgroup (title, stamp) VALUES ( 'main', DATETIME('now') );";
static NSString * const kAddColumnGroupId = @"ALTER TABLE feed ADD COLUMN group_id INTEGER;";
static NSString * const kInsertLynda = @"INSERT INTO feed (url, title, desc, group_id) VALUES ( 'http://feeds.feedburner.com/lyndablog', 'lynda.blog', 'the blog of lynda.com', 1 );";
static NSString * const kInsertLynda2 = @"INSERT INTO feed (url, title, desc, group_id) VALUES ( 'http://feeds.feedburner.com/lyndacom-new-releases', 'lynda.com New Releases', 'lynda.com New Releases', 1 );";
static NSString * const kInsertBW = @"INSERT INTO feed (url, title, desc, group_id) VALUES ( 'https://billweinman.wordpress.com/feed/', 'Bill Weinman''s Technology Blog', 'because it''s all about the data', 1 );";
static NSString * const kIndexFeedUrl = @"CREATE UNIQUE INDEX IF NOT EXISTS feedUrl ON feed(url);";

@interface RSSDB : BWCRUD

- (const NSString *) getVersion;
- (RSSDB *) initWithRSSDBFilename: (NSString *) fn;

// Feed methods
- (NSArray *) getFeedIDs;
- (NSArray *) getFeedIDsForGroup: (NSNumber *) groupid;
- (NSDictionary *) getFeedRow: (NSNumber *) rowid;
- (NSDictionary *) getFeedRowByURL: (NSString *) urlString;
- (void) deleteFeedRow: (NSNumber *) rowid;
- (NSNumber *) addFeedRow: (NSDictionary *) feed;
- (void) updateFeed: (NSDictionary *) feed forRowID: (NSNumber *) rowid;
- (NSNumber *) countFeeds;

// Item methods
- (NSDictionary *) getItemRow: (NSNumber *) rowid;
- (void) deleteItemRow: (NSNumber *) rowid;
- (void) deleteOldItems:(NSNumber *) feedID;
- (NSArray *) getItemIDs:(NSNumber *) feedID;
- (NSNumber *) addItemRow: (NSDictionary *) item;
- (NSNumber *) countItems:(NSNumber *) feedID;

// Feedgroup methods
- (NSDictionary *) getGroupRow: (NSNumber *) groupid;
- (NSNumber *) countFeedsInGroup: (NSNumber *) groupid;
- (NSNumber *) countFeedsInNoGroup;
- (NSArray *) getGroupIDs;
- (NSNumber *) countFeedgroups;

@end
