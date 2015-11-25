//  SafariActivity.swift
//  Copyright (c) 2010-2015 Bill Weinman. All rights reserved.

import UIKit

class SafariActivity: UIActivity {

    var _url : NSURL?
    
    override func activityType() -> String? {
        return NSStringFromClass(SafariActivity)
    }

    override func activityTitle() -> String? {
        return "Open in Safari"
    }
    
    override func activityImage() -> UIImage? {
        return UIImage(named: "SafariIcon")
    }

    override func canPerformWithActivityItems(activityItems: [AnyObject]) -> Bool {
        for item in activityItems {
            if item.isKindOfClass(NSURL) && UIApplication.sharedApplication().canOpenURL(item as! NSURL) {
                return true
            }
        }
        return false
    }
    
    override func prepareWithActivityItems(activityItems: [AnyObject]) {
        for item in activityItems {
            if item.isKindOfClass(NSURL) {
                _url = (item as! NSURL)
            }
        }
    }
    
    override func performActivity() {
        if let url = _url {
            let completed = UIApplication.sharedApplication().openURL(url)
            self.activityDidFinish(completed)
        }
    }
    
}
