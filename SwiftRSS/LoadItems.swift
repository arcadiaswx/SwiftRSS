//  loadItems.swift
//  Copyright (c) 2010-2015 Bill Weinman. All rights reserved.

import UIKit

class LoadItems: NSObject, NSURLConnectionDelegate, NSURLConnectionDataDelegate, NSXMLParserDelegate {
    
    var rssdb : RSSDB!
    var feedID : NSNumber!
    var itemsViewController: ItemsViewController?
    var feedRecord : Dictionary<NSObject, AnyObject>?
    
    // parser data
    var parsedItemsCounter = 0
    var accumulatingParsedCharacterData = false
    var didAbortParsing = false
    var rssConnection : NSURLConnection?
    var rssData : NSMutableData?
    var currentParseBatch : NSMutableArray?
    var currentParsedCharacterData : String?
    var currentItemObject : NSMutableDictionary?
    var currentFeedObject : NSMutableDictionary?
    
    // Parse dictionary keys
    let kpkItemFeedID = "feedID"
    let kpkItemUrl = "url"
    let kpkItemTitle = "title"
    let kpkItemDesc = "desc"
    let kpkItemPubDate = "pubdateSQLString"
    
    init(db: RSSDB, feedID: NSNumber) {
        super.init()
        self.feedID = feedID
        self.rssdb = db
    }
    
    init(db: RSSDB, feedID: NSNumber, tableView: ItemsViewController) {
        super.init()
        self.feedID = feedID
        self.rssdb = db
        self.itemsViewController = tableView
        
        loadFeedRecord()
        let urlString = feedRecord![kRSSDB.feedURL] as! String
        if let url = NSURL(string: urlString) {
            let request = NSURLRequest(URL: url, cachePolicy: NSURLRequestCachePolicy.UseProtocolCachePolicy, timeoutInterval: 15.0)
            rssConnection = NSURLConnection(request: request, delegate: self)
            activityIndicator(true)
        } else {
            haveAlert("invalid URL: \(urlString)")
        }
    }
    
    // MARK: Parser support
    
    // this method runs in a secondary thread
    // this sets up the NSXMLParser
    func parseRSSData(data: NSData) {
        autoreleasepool {
            self.currentParseBatch = NSMutableArray()
            self.currentParsedCharacterData = String()
            self.parsedItemsCounter = 0
            
            let parser = NSXMLParser(data: data)
            parser.delegate = self
            parser.parse()
            
            // check the count of the array and send any remnants to the items list
            if let batch = self.currentParseBatch {
                if batch.count > 0 {
                    dispatch_async(dispatch_get_main_queue(), {
                        self.addToItemsList(batch)
                    })
                }
            }
            
            self.currentParseBatch = nil
            self.currentItemObject = nil
            self.currentFeedObject = nil
            self.currentParsedCharacterData = nil
        }
    }
    
    func addToItemsList(items: NSArray) {
        // NSLog("%@ \(items.count)", __FUNCTION__)
        var row : Dictionary<NSObject,AnyObject>
        for item in items {
            row = Dictionary()
            row[kRSSDB.itemFeedId] = item[kpkItemFeedID]
            row[kRSSDB.itemURL] = item[kpkItemUrl]
            row[kRSSDB.itemTitle] = (item[kpkItemTitle] as! String).trim().flattenHTML()
            row[kRSSDB.itemDesc] = (item[kpkItemDesc] as! String).trim().flattenHTML()
            row[kRSSDB.itemPubDate] = item[kpkItemPubDate]
            rssdb.addItemRow(row)
        }
        if let tv = self.itemsViewController {
            tv.tableView.reloadData()
        }
    }
    
    // MARK: Parser constants
    
    let kxMaxItemsToParse = 50
    let kxSizeOfItemsBatch = 10
    
    let kxChannelElementName = "channel"
    let kxItemElementName = "item"
    let kxDescriptionElementName = "description"
    let kxLinkElementName = "link"
    let kxTitleElementName = "title"
    let kxUpdatedElementName = "pubDate"
    let kxPubDateElementName = "PubDate"
    let kxDCDateElementName = "dc:date"
    
    // MARK: NSXMLParserDelegate methods
    
    func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        // NSLog("%@: %@", __FUNCTION__, elementName)
        let containerElements = [
            kxLinkElementName, kxTitleElementName, kxDescriptionElementName,
            kxUpdatedElementName, kxPubDateElementName, kxDCDateElementName
        ]
        
        // abort if we've gone far enough
        if parsedItemsCounter >= kxMaxItemsToParse {
            self.didAbortParsing = true
            parser.abortParsing()
        }
        
        if elementName == kxChannelElementName {
            let channel = NSMutableDictionary()
            self.currentFeedObject = channel
            self.currentItemObject = channel
        }
        
        if elementName == kxItemElementName {
            if self.currentFeedObject != nil {
                self.feedRecord![kRSSDB.feedTitle] = (self.currentFeedObject![kpkItemTitle] as! String).trim().flattenHTML()
                self.feedRecord![kRSSDB.feedDesc] = (self.currentFeedObject![kpkItemDesc] as! String).trim().flattenHTML()
                self.rssdb.updateFeed(self.feedRecord, forRowID: feedID)
                self.currentFeedObject = nil
            }
            self.currentItemObject = NSMutableDictionary()
            self.currentItemObject![kpkItemFeedID] = self.feedID
        } else if containerElements.contains(elementName) {
            self.accumulatingParsedCharacterData = true
            self.currentParsedCharacterData = ""
        }
        
    }
    
    func parser(parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        // NSLog("%@", __FUNCTION__)
        if elementName == kxItemElementName {
            self.currentParseBatch!.addObject(currentItemObject!)
            ++self.parsedItemsCounter
            // NSLog("%@: %@ batch count: %d", __FUNCTION__, elementName, self.currentParseBatch!.count)
            if self.parsedItemsCounter % kxSizeOfItemsBatch == 0 {
                // NSLog("%@: calling dispatch \(self.currentParseBatch!.count)", __FUNCTION__)
                if let batch = self.currentParseBatch {
                    dispatch_async(dispatch_get_main_queue()) {
                        self.addToItemsList(batch)
                    }
                }
                self.currentParseBatch = NSMutableArray() // reset batch
            }
        } else if self.currentParsedCharacterData == nil {
            return
        } else if let curItem = self.currentItemObject {
            if elementName == kxDescriptionElementName {
                // NSLog("%@: %@ [%@]", __FUNCTION__, elementName, currentParsedCharacterData!)
                curItem[kpkItemDesc] = String(self.currentParsedCharacterData!)
            } else if elementName == kxTitleElementName {
                // NSLog("%@: %@ [%@]", __FUNCTION__, elementName, currentParsedCharacterData!)
                curItem[kpkItemTitle] = String(self.currentParsedCharacterData!)
            } else if elementName == kxLinkElementName {
                // NSLog("%@: %@ [%@]", __FUNCTION__, elementName, currentParsedCharacterData!)
                curItem[kpkItemUrl] = String(self.currentParsedCharacterData!)
            } else if elementName == kxUpdatedElementName || elementName == kxPubDateElementName || elementName == kxDCDateElementName {
                // NSLog("%@: %@ [%@]", __FUNCTION__, elementName, currentParsedCharacterData!)
                curItem[kpkItemPubDate] = stringToSQLDate(String(self.currentParsedCharacterData!))
            }
        }

        self.accumulatingParsedCharacterData = false
    }
    
    func parser(parser: NSXMLParser, foundCharacters string: String?) {
        // NSLog("%@", __FUNCTION__)
        if self.accumulatingParsedCharacterData {
            self.currentParsedCharacterData = self.currentParsedCharacterData! + string!
        }
    }
    
    func parserDidEndDocument(parser: NSXMLParser) {
        // NSLog("%@ \(self.currentParseBatch!.count)", __FUNCTION__)
        if self.currentParseBatch == nil { return }
        dispatch_async(dispatch_get_main_queue(), {
            if let batch = self.currentParseBatch { self.addToItemsList(batch) }
        })
    }
    
    func parser(parser: NSXMLParser, parseErrorOccurred parseError: NSError) {
        // NSLog("%@", __FUNCTION__)
        if didAbortParsing == false {
            dispatch_async(dispatch_get_main_queue(), {
                self.haveError(parseError)
            })
        }
    }
    
    // MARK: NSURLConnection delegate methods
    
    func connection(connection: NSURLConnection, didReceiveResponse response: NSURLResponse) {
        activityIndicator(true)
        if rssData == nil { rssData = NSMutableData() }
    }
    
    func connection(connection: NSURLConnection, didReceiveData data: NSData) {
        rssData?.appendData(data)
    }
    
    func connectionDidFinishLoading(connection: NSURLConnection) {
        activityIndicator(false)
        rssConnection = nil
        if let data = rssData {
            dispatch_async (dispatch_get_global_queue (DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                self.parseRSSData(data)
            }
        }
        rssData = nil
    }
    
    func connection(connection: NSURLConnection, didFailWithError error: NSError) {
        activityIndicator(false)
        if error.code == NSURLErrorNotConnectedToInternet {
            let userInfo = [NSLocalizedDescriptionKey: "I don't seem to be connected to the Internet."]
            let noConnectionError = NSError(domain: NSCocoaErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: userInfo)
            haveError(noConnectionError)
        } else {
            haveError(error)
        }
        rssConnection = nil
    }
    
    // MARK: Utilities
    
    private func loadFeedRecord() -> NSDictionary {
        if feedRecord == nil { feedRecord = rssdb.getFeedRow(feedID) }
        return feedRecord!
    }
    
    private func haveError( error : NSError ) {
        if let tv = self.itemsViewController {
            tv.handleError(error)
        } else {
            NSLog("loadItems: @", error.description)
        }
    }
    
    private func haveAlert( message : String ) {
        if let tv = self.itemsViewController {
            tv.alertMessage(message)
        } else {
            NSLog("loadItems: @", message)
        }
    }
}
