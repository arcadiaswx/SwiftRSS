//  BWDB.m
//  iOS 8 version
//  Copyright (c) 2010-2015 Bill Weinman. All rights reserved.

#import "BWDB.h"

@interface BWDB ()

@property (nonatomic, retain) NSFileManager * filemanager;

@end

@implementation BWDB

#pragma mark ctor/dtor

- (BWDB *) initWithAppGroup: (NSString *) appGroup andDBFilename: (NSString *) fn {
    if ((self = [super init])) {
        self.appGroupName = appGroup;
        self.databaseFileName = fn;
        self.tableName = nil;
        database = NULL;
        statement = NULL;
        [self openDB];
    }
    return self;
}

- (BWDB *) initWithDBFilename:(NSString *)fn {
    if ((self = [super init])) {
        self.databaseFileName = fn;
        self.tableName = nil;
        self.appGroupName = nil;
        database = NULL;
        statement = NULL;
        [self openDB];
    }
    return self;
}

- (BWDB *) initWithDBFilename: (NSString *) fn andTableName: (NSString *) tn {
    // NSLog(@"%s", __FUNCTION__);
    if ((self = [super init])) {
        self.databaseFileName = fn;
        self.tableName = tn;
        database = NULL;
        statement = NULL;
        [self openDB];
    }
    return self;
}

- (void) dealloc {
    [self closeDB];
}

#pragma mark open/close db

// Check to see if the file exists in the documents directory
// otherwise try to copy a default file from the resource path
- (void) openDB {
    // NSLog(@"%s", __FUNCTION__);
    if (database) return;
    self.filemanager = [[NSFileManager alloc] init];
    if (![self getDBPath]) {
        NSAssert(0, @"Error: openDB: could not get db path");
        return;
    }
    
    if (![self.filemanager fileExistsAtPath:self.dbPath]) {
        // try to copy from default, if we have it
        NSString * defaultDBPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:self.databaseFileName];
        if ([self.filemanager fileExistsAtPath:defaultDBPath]) {
            // NSLog(@"copy default DB");
            [self.filemanager copyItemAtPath:defaultDBPath toPath:self.dbPath error:NULL];
        }
    }
    if (sqlite3_open([self.dbPath UTF8String], &database) != SQLITE_OK) {
        NSAssert1(0, @"Error: initializeDatabase: could not open database (%s)", sqlite3_errmsg(database));
    }
    self.filemanager = nil;
}

- (void) closeDB {
    // NSLog(@"%s", __FUNCTION__);
    if (database) sqlite3_close(database);
    database = NULL;
    statement = NULL;
    self.filemanager = nil;
}

- (NSString *) getDBPath {
    // NSLog(@"%s", __FUNCTION__);
    if (self.dbPath) {
        return self.dbPath;
    } else if (self.appGroupName) {
        NSString * groupPath = [[self.filemanager containerURLForSecurityApplicationGroupIdentifier:self.appGroupName] path];
        self.dbPath = [groupPath stringByAppendingPathComponent:self.databaseFileName];
    } else {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = paths[0];
        self.dbPath = [documentsDirectory stringByAppendingPathComponent:self.databaseFileName];
    }
    return self.dbPath;
}

#pragma mark utilities

- (NSString *) getVersion {
    return kBWDBVersion;
}

- (NSString *) getTableName {
    return self.tableName;
}

- (NSNumber *) lastInsertId {
    return [NSNumber numberWithLongLong:sqlite3_last_insert_rowid(database)];
}

- (BOOL) tableExists: (NSString *) tableName {
    if ([self valueFromQuery:@"SELECT tbl_name FROM sqlite_master WHERE type = ? AND name = ?;" withParams:@[@"table", tableName]]) {
        return true;
    } else {
        return false;
    }
}

- (BOOL) columnExistsInTable: (NSString *) tableName withColumnName: (NSString *) columnName {
    NSString * query = [NSString stringWithFormat:@"PRAGMA table_info(%@)", tableName];
    for (NSDictionary * row in [self getQuery:query]) {
        if([row[@"name"] isEqualToString:columnName]) {
            return true;
        }
    }
    return false;
}

- (void) beginTransaction {
    [self doQuery:@"BEGIN TRANSACTION"];
}

- (void) commitTransaction {
    [self doQuery:@"COMMIT"];
}

- (void) finalizeStatement {
    if (statement) {
        sqlite3_finalize(statement);
        statement = NULL;
    }
}

- (void) errorMessage:(NSString *) message {
    [self commitTransaction];
    NSLog(@"%@", message);
}

#pragma mark SQL queries

// bindSQL:withArray
// binds NSArray arguments to the SQL query.
// cQuery is a C string, params is an NSArray of objects
//   objects are tested for type
- (void) bindSQL:(const char *) cQuery withArray:(NSArray *) params {
    // NSLog(@"%s: %s", __FUNCTION__, cQuery);
    NSInteger param_count;
    
    // preparing the query here allows SQLite to determine
    // the number of required parameters
    if (sqlite3_prepare_v2(database, cQuery, -1, &statement, NULL) != SQLITE_OK) {
        NSLog(@"bindSQL:withArray: could not prepare statement (%s) %s", sqlite3_errmsg(database), cQuery);
        statement = NULL;
        return;
    }
    
    param_count = sqlite3_bind_parameter_count(statement);
    if (param_count != [params count]) {
        NSLog(@"bindSQL:withArray: wrong number of parameters (%s)", cQuery);
        statement = NULL;
        return;
    }
    
    if (param_count) {
        for (int i = 0; i < param_count; i++) {
            id o = params[i];
            
            // determine the type of the parameter
            if ([o isEqual:[NSNull null]]) {
                sqlite3_bind_null(statement, i + 1);
            } else if ([o respondsToSelector:@selector(objCType)]) {
                if (strchr("islqISLBQ", *[o objCType])) { // integer
                    sqlite3_bind_int(statement, i + 1, [o intValue]);
                } else if (strchr("fd", *[o objCType])) {   // double
                    sqlite3_bind_double(statement, i + 1, [o doubleValue]);
                } else {    // unhandled types
                    NSLog(@"bindSQL:withArray: Unhandled objCType: %s query: %s", [o objCType], cQuery);
                    statement = NULL;
                    return;
                }
            } else if ([o isKindOfClass:[NSString class]]) { // string
                sqlite3_bind_text(statement, i + 1, [o UTF8String], -1, SQLITE_TRANSIENT);
            } else {    // unhhandled type
                NSLog(@"bindSQL:withArray: Unhandled parameter type: %@ query: %s", [o class], cQuery);
                statement = NULL;
                return;
            }
        }
    }
    return;
}

- (NSNumber *) doQuery: (NSString *) query withParams: (NSArray *) params {
    // NSLog(@"%s: %@", __FUNCTION__, query);
    const char *cQuery = [query UTF8String];
    [self bindSQL:cQuery withArray:params];
    if (statement == NULL) return @0;
    
    sqlite3_step(statement);
    if(sqlite3_finalize(statement) == SQLITE_OK) {
        return @(sqlite3_changes(database));
    } else {
        NSLog(@"doQuery: sqlite3_finalize failed (%s) query: %s", sqlite3_errmsg(database), cQuery);
        return @0;
    }
}

- (NSNumber *) doQuery: (NSString *) query {
    return [self doQuery:query withParams:@[]];
}

- (id) valueFromQuery: (NSString *) query withParams: (NSArray *) params {
    const char *cQuery = [query UTF8String];
    [self bindSQL:cQuery withArray:params];
    if (statement == NULL) return nil;
    return [self getPreparedValue];
}

- (id) valueFromQuery: (NSString *) query {
    return [self valueFromQuery:query withParams:@[]];
}

- (BWDB *) getQuery:(NSString *) query withParams: (NSArray *) params {
    const char *cQuery = [query UTF8String];
    [self bindSQL:cQuery withArray:params];
    if (statement == NULL) return nil;
    return self;
}

- (BWDB *) getQuery:(NSString *) query {
    return [self getQuery:query withParams:@[]];
}

- (void) prepareQuery:(NSString *) query withParams: (NSArray *) params {
    // NSLog(@"%s: %@", __FUNCTION__, query);
    const char *cQuery = [query UTF8String];
    [self bindSQL:cQuery withArray:params];
    if (statement == NULL) return;
}

#pragma mark NSFastEnumeration

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len {
    static __unsafe_unretained NSDictionary * NSFErow;
    if (len < 1) return 0;
    if ((NSFErow = [self getPreparedRow])) {
        state->itemsPtr = &NSFErow;
        state->state = 1;
        state->mutationsPtr = state->extra;
        return 1;
    } else {
        NSFErow = nil;
        state->itemsPtr = nil;
        state->state = 0;
        state->mutationsPtr = state->extra;
        return 0;
    }
}

#pragma mark raw results

- (NSDictionary *) getPreparedRow {
    static NSMutableDictionary * dRow = nil;    // must be static for use with NSFastEnumeration
    int rc = sqlite3_step(statement);
    if (rc == SQLITE_DONE) {
        sqlite3_finalize(statement);
        return nil;
    } else  if (rc == SQLITE_ROW) {
        int col_count = sqlite3_column_count(statement);
        if (col_count >= 1) {
            dRow = [NSMutableDictionary dictionaryWithCapacity:col_count];
            for(int i = 0; i < col_count; i++) {
                dRow[ @(sqlite3_column_name(statement, i)) ] = [self columnValue:i];
            }
            return dRow;
        }
    } else {    // rc != SQLITE_ROW
        NSLog(@"getPreparedRow: could not get row: %s", sqlite3_errmsg(database));
        return nil;
    }
    return nil;
}

// returns one value from the first column of the query
- (id) getPreparedValue {
    int rc = sqlite3_step(statement);
    if (rc == SQLITE_DONE) {
        sqlite3_finalize(statement);
        return nil;
    } else  if (rc == SQLITE_ROW) {
        int col_count = sqlite3_column_count(statement);
        if (col_count < 1) return nil;  // shouldn't really ever happen
        id o = [self columnValue:0];
        sqlite3_finalize(statement);
        return o;
    } else {    // rc == SQLITE_ROW
        NSLog(@"getPreparedValue: could not get row: %s", sqlite3_errmsg(database));
        return nil;
    }
}

#pragma mark private methods

- (id) columnValue:(int) columnIndex {
    id o = nil;
    switch(sqlite3_column_type(statement, columnIndex)) {
        case SQLITE_INTEGER:
            o = @(sqlite3_column_int(statement, columnIndex));
            break;
        case SQLITE_FLOAT:
            o = [NSNumber numberWithFloat:sqlite3_column_double(statement, columnIndex)];
            break;
        case SQLITE_TEXT:
            o = @((const char *) sqlite3_column_text(statement, columnIndex));
            break;
        case SQLITE_BLOB:
            o = [NSData dataWithBytes:sqlite3_column_blob(statement, columnIndex) length:sqlite3_column_bytes(statement, columnIndex)];
            break;
        case SQLITE_NULL:
            o = [NSNull null];
            break;
    }
    return o;
}

@end
