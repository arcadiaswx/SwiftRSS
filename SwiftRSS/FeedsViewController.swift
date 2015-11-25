//  FeedsViewController.swift
//  Created by Bill Weinman on 2015-04-29.

import UIKit

class FeedsViewController: UITableViewController, RSSAddViewControllerDelegate, UIGestureRecognizerDelegate {

    var rssdb: RSSDB!
    var feedIDs: Array<Int>!
    var newFeed: [String : AnyObject]?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "BW RSS"
        self.navigationItem.leftBarButtonItem = self.editButtonItem()
        self.navigationController?.navigationBar.tintColor = RSSDefaultTint

        let lpgr = UILongPressGestureRecognizer(target: self, action: "handleLongPress:")
        lpgr.minimumPressDuration = 1.0 // seconds
        lpgr.delegate = self
        self.tableView.addGestureRecognizer(lpgr)
}

    // MARK: - Table View
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        loadFeedIDs()
        return feedIDs.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("FeedCell", forIndexPath: indexPath) 

        loadFeedIDsIfEmpty()
        let feedRow = rssdb.getFeedRow(feedIDs[indexPath.row])

        if let textlabel = cell.textLabel {
            textlabel.font = UIFont.boldSystemFontOfSize(UIFont.labelFontSize())
            textlabel.text = feedRow[kRSSDB.feedTitle] as? String
        }

        if let detaillabel = cell.detailTextLabel {
            detaillabel.font = UIFont.systemFontOfSize(UIFont.smallSystemFontSize())
            detaillabel.text = feedRow[kRSSDB.feedDesc] as? String
        }

        cell.layoutIfNeeded() // make sure the cell is properly rendered
        return cell
    }

    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        loadFeedIDsIfEmpty()
        if editingStyle == UITableViewCellEditingStyle.Delete {
            let del_id = feedIDs[indexPath.row]
            rssdb.deleteFeedRow(del_id)
            loadFeedIDs()
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Fade)
        }
    }
    
    // MARK: Action sheet for copying URL

    func handleLongPress(gestureRegognizer : UILongPressGestureRecognizer ) {
        if gestureRegognizer.state == UIGestureRecognizerState.Began {
            let touchPoint = gestureRegognizer.locationOfTouch(0, inView: self.tableView)
            if let indexPath = self.tableView.indexPathForRowAtPoint(touchPoint) {
                let feedRow = rssdb.getFeedRow(feedIDs[indexPath.row])
                let urlString = feedRow[kRSSDB.feedURL] as! String
                let feedTitleString = feedRow[kRSSDB.feedTitle] as! String
                let feedDescString = feedRow[kRSSDB.feedDesc] as! String
                let titleString = feedDescString.isEmpty ? feedTitleString : "\(feedTitleString) - \(feedDescString)"
                
                let actionController = UIAlertController(title: urlString, message: titleString, preferredStyle: UIAlertControllerStyle.ActionSheet)
                let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: {
                    ( action ) -> Void in
                    actionController.dismissViewControllerAnimated(true, completion: nil)
                })
                let copyAction = UIAlertAction(title: "Copy feed URL", style: UIAlertActionStyle.Default, handler: {
                    ( action ) -> Void in
                    UIPasteboard.generalPasteboard().string = urlString
                    actionController.dismissViewControllerAnimated(true, completion: nil)
                })
                actionController.addAction(copyAction)
                actionController.addAction(cancelAction)
                if let popover = actionController.popoverPresentationController {
                    popover.sourceRect = CGRectMake(touchPoint.x, 12.0, 1.0, 1.0)
                    popover.sourceView = self.tableView.cellForRowAtIndexPath(indexPath)?.contentView
                }
                self.presentViewController(actionController, animated: true, completion: nil)
            }
        }
    }
    
    // MARK: - Segues
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "ItemsSegue" {
            let rssItemsViewController = segue.destinationViewController as! ItemsViewController
            let path = tableView.indexPathForSelectedRow!
            rssItemsViewController.feedID = feedIDs[path.row]
            rssItemsViewController.rssdb = rssdb
        }
        else if segue.identifier == "ToAddView" {
            let addFeedViewController = segue.destinationViewController as! AddFeedViewController
            addFeedViewController.delegate = self
        }
    }
    
    // MARK: Database methods

    private func loadFeedIDs() -> Array<Int> {
        loadDB()
        feedIDs = rssdb.getFeedIDs() as! Array<Int>
        return feedIDs
    }

    private func loadFeedIDsIfEmpty() -> Array<Int> {
        loadDB()
        if feedIDs == nil || feedIDs.count == 0 {
            feedIDs = rssdb.getFeedIDs() as! Array<Int>
        }
        return feedIDs
    }

    private func loadDB() -> RSSDB {
        if rssdb == nil {
            rssdb = RSSDB(RSSDBFilename: "bwrss.db")
        }
        return rssdb
    }
    
    private func loadNewFeed() {
        if let newFeed = self.newFeed {
            self.newFeed = nil
            let rc = rssdb.addFeedRow(newFeed)
            let idx = indexPathForDBRec(newFeed)
            if let indexPath = idx {
                if rc == nil { // inserted new row
                    tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Left)
                }
                tableView.scrollToRowAtIndexPath(indexPath, atScrollPosition: UITableViewScrollPosition.None, animated: true)
                if rc != nil {
                    tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Left)
                }
            }
        }
    }
    
    private func indexPathForDBRec(dbRec: NSDictionary) -> NSIndexPath? {
        let urlString = dbRec[kRSSDB.feedURL] as! String
        let row = rssdb.getFeedRowByURL(urlString)
        if let rowID = row?[kRSSDB.feedID] as? Int {
            let tempFeedIDs = rssdb.getFeedIDs() as NSArray
            return NSIndexPath(forRow: tempFeedIDs.indexOfObject(rowID), inSection: 0)
        } else {
            return nil
        }
    }
    
    // MARK: RSSAddViewControllerDelegate methods
    
    func haveAddViewRecord(avRecord: [String : AnyObject]) {
        self.newFeed = avRecord;
        loadNewFeed()
    }
    
    func haveAddViewError(error: NSError) {
        let alertView = UIAlertView(title: "URL Error", message: error.localizedDescription, delegate: nil, cancelButtonTitle: "OK")
        alertView.show()
    }
    
    func addViewMessage(message: String) {
        let alertView = UIAlertView(title: "BW RSS", message: message, delegate: nil, cancelButtonTitle: "OK")
        alertView.show()
    }
    
}
