//  BWDB/RSSDB Swift Extensions
//  Copyright (c) 2010-2015 Bill Weinman. All rights reserved.

import UIKit

// This is necessary for BWDB's NSFastEnumeration to work in Swift
extension BWDB: SequenceType {
    public func generate() -> NSFastGenerator {
        return NSFastGenerator(self)
    }
}

// This is the nutso way I figured out to do namespaced string constants in Swift.
// It's weird and it duplicates code from RSSDB, but it works well.
// This is necessary because the linker won't bind static ObjC variables with Swift code.
struct _kRSSDB {
    let feedID = "id"
    let feedURL = "url"
    let feedTitle = "title"
    let feedDesc = "desc"
    let FeedPubDate = "pubdate"
    let feedGroup = "group_id"
    let itemFeedId = "feed_id"
    let itemId = "id"
    let itemURL = "url"
    let itemTitle = "title"
    let itemDesc = "desc"
    let itemPubDate = "pubdate"
    let groupId = "id"
    let groupTitle = "title"
}
let kRSSDB = _kRSSDB()
