//  BWCRUD.h
//  iOS 8 version
//  Copyright (c) 2010-2015 Bill Weinman. All rights reserved.

#import "BWDB.h"

static NSString * const kBWCRUDVersion = @"2.1.1";

@interface BWCRUD : BWDB

- (const NSString *) getVersion;
- (BWDB *) initWithDBFilename: (NSString *) fn andTableName: (NSString *) tn;

- (NSNumber *) insertRow:(NSDictionary *) record;
- (void) updateRow:(NSDictionary *) record forRowID: (NSNumber *) rowID;
- (void) deleteRow:(NSNumber *) rowID;
- (NSDictionary *) getRow: (NSNumber *) rowID;
- (NSNumber *) countRows;

@end
