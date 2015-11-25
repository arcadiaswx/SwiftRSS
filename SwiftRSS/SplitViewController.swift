//  SplitViewController.swift
//  Copyright (c) 2010-2015 Bill Weinman. All rights reserved.

import UIKit

class SplitViewController : UISplitViewController, UISplitViewControllerDelegate {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.delegate = self
        setStatusBarHidden(false)
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.All
    }
    
    // MARK: UISplitViewControllerDelegate methods
    
    // this makes sure the initial view controller is correct
    func splitViewController(splitViewController: UISplitViewController, collapseSecondaryViewController secondaryViewController: UIViewController, ontoPrimaryViewController primaryViewController: UIViewController) -> Bool {
        if let svc = secondaryViewController as? UINavigationController where svc.title == nil {
            return true
        }
        return false
    }
    
    // This works around a bug in the new splitview controller
    // without this the items tableview could be presented as the detail view
    // and could cause crashes on the iPhone 6+
    func splitViewController(splitViewController: UISplitViewController, separateSecondaryViewControllerFromPrimaryViewController primaryViewController: UIViewController) -> UIViewController? {
        if let pvc = primaryViewController as? UINavigationController {
            for controller in pvc.viewControllers {
                if let navcontroller = controller as? UINavigationController where navcontroller.visibleViewController!.isKindOfClass(DetailViewController) {
                    return navcontroller
                }
            }
        }
        
        // no detail view present
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        // must set identifier in "Storyboard ID" field in the storyboard
        let detailView = storyboard.instantiateViewControllerWithIdentifier("detailView") as! UINavigationController
        return detailView
    }
    
}
