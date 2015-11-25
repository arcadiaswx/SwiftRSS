//  BWDB.h
//  iOS 8 version
//  Copyright (c) 2010-2015 Bill Weinman. All rights reserved.

#import <Foundation/Foundation.h>
#import <sqlite3.h>

static NSString * const kBWDBVersion = @"2.3.3";

@interface BWDB : NSObject <NSFastEnumeration> {
    sqlite3 * database;
    sqlite3_stmt * statement;
}

@property (nonatomic, retain) NSString * appGroupName;
@property (nonatomic, retain) NSString * databaseFileName;
@property (nonatomic, retain) NSString * dbPath;
@property (nonatomic, retain) NSString * tableName;

// ctors dtors etc
- (BWDB *) initWithDBFilename: (NSString *) fn;
- (BWDB *) initWithAppGroup: (NSString *) appGroup andDBFilename: (NSString *) fn;
- (BWDB *) initWithDBFilename: (NSString *) fn andTableName: (NSString *) tn;
- (void) closeDB;
- (void) dealloc;

// utilities
- (const NSString *) getVersion;
- (NSString *) getDBPath;
- (NSString *) getTableName;
- (NSNumber *) lastInsertId;
- (BOOL) tableExists: (NSString *) tableName;
- (BOOL) columnExistsInTable: (NSString *) tableName withColumnName: (NSString *) columnName;
- (void) beginTransaction;
- (void) commitTransaction;
- (void) finalizeStatement;
- (void) errorMessage:(NSString *) message;

// SQL queries
- (void) bindSQL:(const char *) cQuery withArray:(NSArray *) params;
- (NSNumber *) doQuery: (NSString *) query withParams: (NSArray *) params;
- (NSNumber *) doQuery: (NSString *) query;
- (id) valueFromQuery: (NSString *) query withParams: (NSArray *) params;
- (id) valueFromQuery: (NSString *) query;
- (BWDB *) getQuery:(NSString *) query withParams: (NSArray *) params;
- (BWDB *) getQuery:(NSString *) query;
- (void) prepareQuery:(NSString *) query withParams: (NSArray *) params;

// NSFastEnumeration
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len;

// raw results
- (NSDictionary *) getPreparedRow;
- (id) getPreparedValue;

@end
