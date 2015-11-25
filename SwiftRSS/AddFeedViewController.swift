//  AddFeedViewController.swift
//  Copyright (c) 2010-2015 Bill Weinman. All rights reserved.

import UIKit

protocol RSSAddViewControllerDelegate {
    func haveAddViewRecord(avRecord: [String : AnyObject])
    func haveAddViewError(error: NSError)
    func addViewMessage(message: String)
}

class AddFeedViewController: UIViewController, UITextFieldDelegate, NSURLConnectionDelegate, NSURLConnectionDataDelegate, NSXMLParserDelegate {
    
    @IBOutlet var statusLabel: UILabel!
    @IBOutlet var urlTextField: UITextField!
    
    enum BWRSSState {
        case unknown
        case discovery
        case parseHeader
    }
    
    var delegate: RSSAddViewControllerDelegate!
    var feedRecord: [String : AnyObject]? = nil
    var feedConnection: NSURLConnection? = nil
    
    var bwrssState = BWRSSState.unknown
    
    var xmlData: NSMutableData? = nil
    var feedURL: String?
    var feedHost: String?
    
    var haveTitle: Bool = false
    var haveDescription: Bool = false
    var didReturnFeed: Bool = false
    var didFinishParsing: Bool = false
    
    var currentElement: String?
    
    // MARK: Constants
    
    let kMinPageSize = 64
    let kMaxPageSize = 10240
    
    let kRSSMIMESuffix = "xml"
    
    let kTitleElementName = "title";
    let kDescriptionElementName = "description";
    let kItemElementName = "item";
    
    // MARK: View management
    
    override func viewDidLoad() {
        super.viewDidLoad()
        urlTextField.becomeFirstResponder()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        clearStatus()
    }
    
    // MARK: Actions
    
    @IBAction func cancelAction(sender: UIButton) {
        if let fc = feedConnection {
            fc.cancel()
            activityIndicator(false)
        }
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func addAction(sender: UIButton) {
        if let fc = feedConnection {
            fc.cancel()
        }
        getRSSFeed(urlTextField.text!.trim())
        urlTextField.enabled = false;
        urlTextField.textColor = UIColor.grayColor()
        activityIndicator(true)
    }
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        self.addAction(UIButton())
        return true
    }
    
    // MARK: Feed acquisition
    
    private func getRSSFeed(urlstr: String) {
        var urlString = urlstr
        if urlString.characters.count < 1 { return }  // don't bother with empty string
        if !(urlString.hasPrefix("http://") || urlString.hasPrefix("https://")) {
            urlString = "http://" + urlString
        }
        fetchURL(urlString, state: BWRSSState.discovery)
    }
    
    private func fetchURL(urlstr: String, state: BWRSSState) {
        bwrssState = state
        xmlData = NSMutableData()
        var urlRequest : NSURLRequest!
        status("Requesting \(urlstr)")
        if let url = NSURL(string: urlstr) {
            urlRequest = NSURLRequest(URL: url)
            feedConnection = NSURLConnection(request: urlRequest, delegate: self)
            if feedConnection == nil { dismissWithMessage("NSURLConnection failed") }
        } else {
            alertMessage("Invalid URL")
        }
    }
    
    func findFeedURL() {
        var len = xmlData?.length ?? 0
        if len < kMinPageSize { alertMessage("Empty Page"); return; }
        if len > kMaxPageSize { len = kMaxPageSize }
        let pageString = String(bytesNoCopy: xmlData!.mutableBytes, length: len, encoding: NSUTF8StringEncoding, freeWhenDone: false)!
        
        let rssLink = rssLinkFromHTML(pageString)
        xmlData?.length = 0     // reset the data buffer
        if let linkdict = rssLink {
            fetchURL(linkdict["href"] as! String, state: BWRSSState.parseHeader)
        } else {
            dismissWithMessage("I did not find a feed.")
        }
        
    }
    
    private func haveFeed() {
        if var rec = feedRecord {
            if rec[kTitleElementName] == nil { rec[kTitleElementName] = feedHost }
            if rec[kDescriptionElementName] == nil { rec[kDescriptionElementName] = "" }
            
            rec[kRSSDB.feedTitle] = (rec[kTitleElementName] as! String).trim().flattenHTML()
            rec[kRSSDB.feedDesc] = (rec[kDescriptionElementName] as! String).trim().flattenHTML()
            rec[kDescriptionElementName] = nil // not a database column
            rec[kRSSDB.feedGroup] = 1
            
            delegate.haveAddViewRecord(rec)
            dismissViewControllerAnimated(true, completion: nil)
        }
    }
    
    private func parseRSSHeader() {
        let parser = NSXMLParser(data: xmlData!)
        parser.delegate = self
        parser.parse()
    }
    
    // MARK: RSS discovery methods
    
    private func rssLinkFromHTML(pageString: String) -> Dictionary<String,AnyObject>? {
        // NSLog("%@ %d", __FUNCTION__, countElements(pageString))
        var rssLink: Dictionary<String,AnyObject>?
        let pageScanner = NSScanner(string: pageString)
        pageScanner.caseSensitive = false
        pageScanner.charactersToBeSkipped = NSCharacterSet.whitespaceAndNewlineCharacterSet()
        
        while pageScanner.scanUpToString("<link ", intoString: nil) {
            var linkString : NSString?
            if pageScanner.scanUpToString(">", intoString: &linkString) {
                rssLink = getHTMLAttributes(linkString as! String)
                let attRel = rssLink!["rel"] as! String?
                let attType = rssLink!["type"] as! String?

                // the following uses new multiple optional bindings for if-let in Swift 1.2
                if let rel = attRel, type = attType
                    where rel.lowercaseString == "alternate"
                    && [ "application/rss+xml", "application/atom+xml" ].contains(type.lowercaseString)
                {
                    break;
                } else {
                    rssLink = nil
                }

            }
        }
        if rssLink?["href"] == nil { rssLink = nil }
        return rssLink
    }
    
    
    private func getHTMLAttributes(htmlTag: String) -> Dictionary<String, String>? {
        // NSLog("%@ %d", __FUNCTION__, htmlTag)
        
        var attribs = Dictionary<String, String>()
        var attributeString: NSString?
        var valueString: NSString?
        
        let linkScanner = NSScanner(string: htmlTag)
        linkScanner.caseSensitive = false
        linkScanner.charactersToBeSkipped = NSCharacterSet.whitespaceAndNewlineCharacterSet()
        linkScanner.scanUpToCharactersFromSet(NSCharacterSet.alphanumericCharacterSet(), intoString: nil)
        
        while linkScanner.scanCharactersFromSet(NSCharacterSet.alphanumericCharacterSet(), intoString: &attributeString) {
            if linkScanner.scanString("=\"", intoString: nil) && linkScanner.scanUpToString("\"", intoString: &valueString) {
                attribs[attributeString! as String] = valueString! as String
            }
            linkScanner.scanUpToCharactersFromSet(NSCharacterSet.alphanumericCharacterSet(), intoString: nil)
        }
        return attribs
    }
    
    // MARK: NSXMLParserDelegate
    
    func parserDidStartDocument(parser: NSXMLParser) {
        // reset the environment
        status("Parsing \(feedURL)")
        feedRecord = Dictionary()
        feedRecord![kRSSDB.feedURL] = feedURL
        haveTitle = false
        haveDescription = false
        didReturnFeed = false
    }
    
    func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        if didFinishParsing { return }
        if elementName == kTitleElementName || elementName == kDescriptionElementName {
            currentElement = elementName
            feedRecord?[elementName] = nil
        } else if elementName == kItemElementName {
            didFinishParsing = true
            parser.abortParsing()
        } else {
            currentElement = nil
        }
    }
    
    func parser(parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if didFinishParsing { return }
        
        if elementName == kTitleElementName {
            haveTitle = true
        } else if elementName == kDescriptionElementName {
            haveDescription = true
        }
        
        if haveTitle && haveDescription {
            didFinishParsing = true
            parser.abortParsing()
        }
    }
    
    func parser(parser: NSXMLParser, foundCharacters string: String?) {
        if didFinishParsing { return }
        if currentElement == kTitleElementName || currentElement == kDescriptionElementName {
            if let foundString = string {
                if feedRecord![currentElement!] != nil {
                     feedRecord![currentElement!] = feedRecord![currentElement!]?.stringByAppendingString(foundString)
                } else {
                    feedRecord![currentElement!] = string
                }
            }
        }
    }
    
    // abortParsing raises an error, so we should end up here
    func parser(parser: NSXMLParser, parseErrorOccurred parseError: NSError) {
        if didFinishParsing && !didReturnFeed {
            didReturnFeed = true
            haveFeed()
        }
    }
    
    // not normally called, should end with abortParsing
    func parserDidEndDocument(parser: NSXMLParser) {
        haveFeed()
    }
    
    // MARK: NSURLConnectionDelegate & NSURLConnectionDataDelegate
    
    func connection(connection: NSURLConnection, didReceiveResponse response: NSURLResponse) {
        status("Connected to \(response.URL!)")
        activityIndicator(true)
        switch bwrssState {
        case BWRSSState.discovery:
            if response.MIMEType!.hasSuffix(kRSSMIMESuffix) {
                feedURL = response.URL!.absoluteString
                bwrssState = BWRSSState.parseHeader
            }
        case BWRSSState.parseHeader:
            feedURL = response.URL!.absoluteString
            feedHost = response.URL!.host!
        default:
            dismissWithMessage("unknown BWRSSState")
        }
        xmlData?.length = 0
    }
    
    func connection(connection: NSURLConnection, didReceiveData data: NSData) {
        if bwrssState == BWRSSState.discovery && xmlData!.length > kMaxPageSize {
            connection.cancel()
            activityIndicator(false)
            findFeedURL()
        } else {
            xmlData!.appendData(data)
        }
    }
    
    func connectionDidFinishLoading(connection: NSURLConnection) {
        feedConnection = nil
        activityIndicator(false)
        switch bwrssState {
        case BWRSSState.discovery:
            findFeedURL()
        case BWRSSState.parseHeader:
            parseRSSHeader()
        default:
            dismissWithMessage("Parse error: Inavlid state")
        }
    }
    
    func connection(connection: NSURLConnection, didFailWithError error: NSError) {
        dismissWithError(error)
    }
    
    // MARK: status label
    
    private func status(m: String) {
        statusLabel.text = m
    }
    
    private func clearStatus() {
        statusLabel.text = ""
    }
    
    // MARK: Utility functions
    
    private func dismissWithError(error: NSError) {
        activityIndicator(false)
        delegate.haveAddViewError(error)
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    private func dismissWithMessage(message: String) {
        activityIndicator(false)
        delegate.addViewMessage(message)
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    private func alertMessage(message: String) {
        let alertView = UIAlertView(title: "BW RSS", message: message, delegate: nil, cancelButtonTitle: "OK")
        alertView.show()
    }
    
    private func activityIndicator(state: Bool) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = state
    }
    
}
