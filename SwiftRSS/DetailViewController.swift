//  DetailViewController.swift
//  Copyright (c) 2010-2015 Bill Weinman. All rights reserved.

import UIKit
import WebKit

class DetailViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate {
    
    //var buttonItems:[AnyObject] = [AnyObject]()
    var buttonItems:[UIBarButtonItem] = [UIBarButtonItem]()
    var leftButton : UIBarButtonItem?
    var rightButton : UIBarButtonItem?
    var reloadButton : UIBarButtonItem?
    var stopButton : UIBarButtonItem?
    var shareButton : UIBarButtonItem?
    let flexSpaceButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.FlexibleSpace, target: nil, action: "")
    let fixedSpaceButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.FixedSpace, target: nil, action: "")
    var progress : UIProgressView?
    
    var titleLabel = UILabel()
    var subtitleLabel = UILabel()
    
    var webView : WKWebView?
    var primaryVC : UIViewController?
    
    var detailItem : String?
    
    deinit {
        setStatusBarHidden(false)
        self.webView?.navigationDelegate = nil
        self.webView?.scrollView.delegate = nil
        self.webView?.removeObserver(self, forKeyPath: "estimatedProgress")
        self.webView = nil
        self.detailItem = nil
        self.progress = nil
        self.title = nil
    }
    
    // MARK: UIViewController delegate methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem()
        self.navigationController?.toolbar.tintColor = RSSDefaultTint
        self.navigationController?.navigationBar.tintColor = RSSDefaultTint
        self.configureView()
    }
    
    override func loadView() {
        if let detailURL = self.detailItem {
            self.webView = WKWebView()
            if let wv = self.webView {
                self.view = wv
                wv.navigationDelegate = self
                wv.UIDelegate = self
                wv.scrollView.delegate = self
                wv.addObserver(self, forKeyPath: "estimatedProgress", options: NSKeyValueObservingOptions.New, context: nil)

                let url = NSURL(string: detailURL)
                let req = NSURLRequest(URL: url!)
                setStatusBarHidden(false)
                wv.loadRequest(req)
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // when the device rotates - restore the toolbars
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        
        // turn on the tool bars
        if let nav = self.navigationController {
            toolBarsOn(nav)
        }
    }

    // MARK: Support methods
    
    func configureView() {
        // Update the user interface for the detail item.
        if let detail = self.detailItem {
            let navC = navigationController
            self.setupToolBar()
            self.setupNavSubtitleView()
            setupProgressBar()
            self.title = detail
        } else {
            self.title = nil
        }
    }
    
    func setupNavSubtitleView() {
        let outerViewFrame = CGRectMake(0, 4, 1000, 44)
        let titleLabelFrame = CGRectMake(0, 0, 1000, 24)
        let subTitleLabelFrame = CGRectMake(0, 20, 1000, 20)
        let titleSubTitleView = UIView(frame: outerViewFrame)
        
        titleSubTitleView.autoresizingMask = UIViewAutoresizing.FlexibleWidth
        titleSubTitleView.autoresizesSubviews = true
        
        titleLabel.frame = titleLabelFrame
        titleLabel.font = UIFont.boldSystemFontOfSize(UIFont.labelFontSize())
        titleLabel.autoresizingMask = UIViewAutoresizing.FlexibleWidth
        titleLabel.textAlignment = NSTextAlignment.Left
        titleLabel.text = ""
        
        subtitleLabel.frame = subTitleLabelFrame
        subtitleLabel.font = UIFont.systemFontOfSize(UIFont.smallSystemFontSize() * 0.8)
        subtitleLabel.autoresizingMask = UIViewAutoresizing.FlexibleWidth
        subtitleLabel.textColor = UIColor.grayColor()
        subtitleLabel.textAlignment = NSTextAlignment.Left
        subtitleLabel.text = detailItem
        
        titleSubTitleView.addSubview(titleLabel)
        titleSubTitleView.addSubview(subtitleLabel)
        self.navigationItem.titleView = titleSubTitleView
    }
    
    func setupToolBar() {
        // setup bar button items
        if buttonItems.count == 0 {
            leftButton = UIBarButtonItem(image: UIImage(named: "BackIcon"), style: UIBarButtonItemStyle.Plain, target: self.webView, action: "goBack")
            rightButton = UIBarButtonItem(image: UIImage(named: "FwdIcon"), style: UIBarButtonItemStyle.Plain, target: self.webView, action: "goForward")
            reloadButton = UIBarButtonItem(image: UIImage(named: "ReloadIcon"), style: UIBarButtonItemStyle.Plain, target: self.webView, action: "reload")
            stopButton = UIBarButtonItem(image: UIImage(named: "StopIcon"), style: UIBarButtonItemStyle.Plain, target: self.webView, action: "stopLoading")
            shareButton = UIBarButtonItem(image: UIImage(named: "ShareIcon"), style: UIBarButtonItemStyle.Plain, target: self, action: "shareAction")
            
            fixedSpaceButton.width = 35.0
            
            buttonItems.append(leftButton!)
            buttonItems.append(fixedSpaceButton)
            buttonItems.append(rightButton!)
            buttonItems.append(flexSpaceButton)
            buttonItems.append(reloadButton!)
            buttonItems.append(fixedSpaceButton)
            buttonItems.append(shareButton!)
        }
        
        // must set navigation toolbar items through the view controller
        self.setToolbarItems(buttonItems, animated: true)
        if let navcontroller = self.navigationController {
            navcontroller.setToolbarHidden(false, animated: false)
        }
    }
    
    func setupProgressBar() {
        progress = UIProgressView(progressViewStyle: UIProgressViewStyle.Bar)
        if let pv = progress {
            pv.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(pv)
            self.view.addConstraint(NSLayoutConstraint(item: pv, attribute: NSLayoutAttribute.Left, relatedBy: NSLayoutRelation.Equal, toItem: self.view, attribute: NSLayoutAttribute.Left, multiplier: 1, constant: 0))
            self.view.addConstraint(NSLayoutConstraint(item: pv, attribute: NSLayoutAttribute.Right, relatedBy: NSLayoutRelation.Equal, toItem: self.view, attribute: NSLayoutAttribute.Right, multiplier: 1, constant: 0))
            self.view.addConstraint(NSLayoutConstraint(item: pv, attribute: NSLayoutAttribute.Top, relatedBy: NSLayoutRelation.Equal, toItem: self.topLayoutGuide, attribute: NSLayoutAttribute.Bottom, multiplier: 1, constant: 0))
            pv.translatesAutoresizingMaskIntoConstraints = false
            pv.hidden = true
            pv.setProgress(0, animated: false)
            pv.tintColor = RSSDefaultTint
            self.view.bringSubviewToFront(pv)
        }
    }
    
    // MARK: tool bar utilities
    
    func shareAction() {
        if let shareURL = webView?.URL {
            let activityItems = [shareURL]
            let applicationActivities = [SafariActivity(), ChromeActivity()]
            let avc = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
            avc.popoverPresentationController?.barButtonItem = shareButton
            self.presentViewController(avc, animated: true, completion: nil)
        }
    }

    func toolBarsOn(nav: UINavigationController) {
        nav.setToolbarHidden(false, animated: true)
        nav.setNavigationBarHidden(false, animated: true)
        setStatusBarHidden(false)
    }
    
    func toolBarsOff(nav: UINavigationController) {
        nav.setToolbarHidden(true, animated: true)
        nav.setNavigationBarHidden(true, animated: true)
        setStatusBarHidden(true)
    }
    
    func updateReloadStopButton (newItem : UIBarButtonItem) {
        let buttonPosition = 4
        if(buttonItems.count > buttonPosition) {
            buttonItems[buttonPosition] = newItem
            self.setToolbarItems(buttonItems, animated: true)
        }
    }
    
    func setBackFwdEnabled(webVeiw: WKWebView) {
        leftButton?.enabled = webView!.canGoBack
        rightButton?.enabled = webView!.canGoForward
    }
    
    func setWebViewTitle(webView: WKWebView, subtitle: String?) {
        let pageTitle = webView.title ?? ""
        let pageURL = subtitle ?? webView.URL?.description ?? ""
        if pageTitle != "" {
            self.titleLabel.text = pageTitle
        }
        self.subtitleLabel.text = pageURL
    }
    
    // MARK: UIScrollViewDelegate
    
    func scrollViewShouldScrollToTop(scrollView: UIScrollView) -> Bool {
        if let navcontroller = self.navigationController {
            toolBarsOn(navcontroller)
        }
        return true
    }
    
    func scrollViewWillBeginDecelerating(scrollView: UIScrollView) {
        if let navcontroller = self.navigationController {
            let yVelocity = scrollView.panGestureRecognizer.velocityInView(scrollView).y
            if yVelocity > 0 { // pan up
                toolBarsOn(navcontroller)
            }
        }
    }
    
    func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        if let navcontroller = self.navigationController {
            let yVelocity = scrollView.panGestureRecognizer.velocityInView(scrollView).y
            if yVelocity < 0 { // drag down
                toolBarsOff(navcontroller)
            }
        }
    }
    
    // MARK: WKNavigationDelegate
    
    func webView(webView: WKWebView, didCommitNavigation navigation: WKNavigation!) {
        activityIndicator(true)
        if let pb = progress {
            pb.setProgress(0.0, animated: false)
            pb.hidden = false
        }
        setWebViewTitle(webView, subtitle: nil)
        updateReloadStopButton(stopButton!)
    }
    
    func webView(webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        toolBarsOn(self.navigationController!)
        setWebViewTitle(webView, subtitle: nil)
        setBackFwdEnabled(webView)
    }
    
    func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
        activityIndicator(false)
        updateReloadStopButton(reloadButton!)
        if let pb = progress {
            pb.setProgress(1.0, animated: true)
            pb.hidden = true
        }
        
        setWebViewTitle(webView, subtitle: nil)
        toolBarsOn(self.navigationController!)
        setBackFwdEnabled(webView)
    }
    
    // MARK: WKUIDelegate
    
    // this handles target=_blank links by opening them in the current webView
    func webView(webView: WKWebView, createWebViewWithConfiguration configuration: WKWebViewConfiguration, forNavigationAction navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.loadRequest(navigationAction.request)
            setWebViewTitle(webView, subtitle: nil)
        }
        return nil
    }
    
    // MARK: Observers
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        // update the title
        if let wv = webView {
            setWebViewTitle(wv, subtitle: nil)
        }
        if keyPath == "estimatedProgress" && object === webView {
            if let pb = progress, wv = webView {
                pb.setProgress(Float(wv.estimatedProgress), animated: true)
            }
        } else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
    
}
