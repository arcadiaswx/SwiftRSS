//  BWCRUD.m
//  iOS 8 version
//  Copyright (c) 2010-2015 Bill Weinman. All rights reserved.

#import "BWCRUD.h"

@implementation BWCRUD

- (NSString *) getVersion {
    return kBWCRUDVersion;
}

- (BWDB *) initWithDBFilename: (NSString *) fn andTableName: (NSString *) tn {
    return [super initWithDBFilename:fn andTableName:tn];
}

- (NSNumber *) insertRow:(NSDictionary *) record {
    // NSLog(@"%s", __FUNCTION__);
    NSString * tableName = [self getTableName];
    NSInteger dictSize = [record count];
    NSArray * vArray = [record allValues];
    
    // construct the query
    NSMutableArray * placeHoldersArray = [NSMutableArray arrayWithCapacity:dictSize];
    for (NSInteger i = 0; i < dictSize; ++i)  // array of ? markers for placeholders in query
        [placeHoldersArray addObject: @"?"];
    
    NSString * query = [NSString stringWithFormat:@"insert into %@ (%@) values (%@)",
                        tableName,
                        [[record allKeys] componentsJoinedByString:@","],
                        [placeHoldersArray componentsJoinedByString:@","]];

    [self bindSQL:[query UTF8String] withArray:vArray];
    sqlite3_step(statement);
    if(sqlite3_finalize(statement) == SQLITE_OK) {
        return [self lastInsertId];
    } else {
        [self errorMessage:[NSString stringWithFormat:@"insertRow: sqlite3_finalize failed (%s)", sqlite3_errmsg(database)]];
        return @0;
    }
}

- (void) updateRow:(NSDictionary *) record forRowID:(NSNumber *)rowID {
    // NSLog(@"%s", __FUNCTION__);
    NSString * tableName = [self getTableName];
    NSInteger dictSize = (int) [record count];
    
    NSMutableArray * vArray = [NSMutableArray arrayWithCapacity:dictSize + 1];
    [vArray addObjectsFromArray:[record allValues]];
    [vArray addObject:rowID];
    
    NSString * query = [NSString stringWithFormat:@"update %@ set %@ = ? where id = ?",
                        tableName,
                        [[record allKeys] componentsJoinedByString:@" = ?, "]];
    
    [self bindSQL:[query UTF8String] withArray:vArray];
    sqlite3_step(statement);
    if(sqlite3_finalize(statement) != SQLITE_OK) {
        [self errorMessage:[NSString stringWithFormat:@"updateRow: sqlite3_finalize failed (%s)", sqlite3_errmsg(database)]];
    }
}

- (void) deleteRow:(NSNumber *) rowID {
    // NSLog(@"%s", __FUNCTION__);
    NSString * tableName = [self getTableName];
    
    NSString * query = [NSString stringWithFormat:@"delete from %@ where id = ?", tableName];
    [self doQuery:query withParams:@[rowID]];
}

// updated to finalize the statement after getPreparedRow
- (NSDictionary *) getRow: (NSNumber *) rowID {
    NSString * tableName = [self getTableName];
    NSString * query = [NSString stringWithFormat:@"select * from %@ where id = ?", tableName];
    [self prepareQuery:query withParams:@[rowID]];
    NSDictionary * row = [self getPreparedRow];
    [self finalizeStatement];
    return row;
}

- (NSNumber *) countRows {
    [self getQuery:[NSString stringWithFormat:@"select count(*) from %@", [self getTableName]]];
    return [self getPreparedValue];
}

@end
