//
//  HomeViewController.swift
//  argent-ios
//
//  Created by Sinan Ulkuatam on 2/9/16.
//  Copyright © 2016 Sinan Ulkuatam. All rights reserved.
//

import UIKit
import SnapKit
import SwiftyJSON
import Stripe
import BEMSimpleLineGraph
import DZNEmptyDataSet
import CWStatusBarNotification
import CellAnimator
import Crashlytics
import WatchConnectivity
import EasyTipView
import MZFormSheetPresentationController
import KeychainSwift

var userAccessToken = NSUserDefaults.standardUserDefaults().valueForKey("userAccessToken")

class HomeViewController: UIViewController, BEMSimpleLineGraphDelegate, BEMSimpleLineGraphDataSource, UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate, WCSessionDelegate, EasyTipViewDelegate  {
    
    private var window: UIWindow?
    
    private var backgroundImageView = UIImageView()
    
    private var screen = UIScreen.mainScreen().bounds
    
    private var screenWidth = UIScreen.mainScreen().bounds.size.height
    
    private var screenHeight = UIScreen.mainScreen().bounds.size.width
    
    private var balanceSwitch = UISegmentedControl(items: ["A", "P"])
    
    private let dateRangeSegment: UISegmentedControl = UISegmentedControl(items: ["2W", "1M", "3M", "6M", "1Y"])

    private var logoView = UIImageView()
    
    private var tutorialButton:UIButton = UIButton()
    
    private var dateFormatter = NSDateFormatter()
    
    private var accountHistoryArray:Array<History>?
    
    private var balance:Balance = Balance(pending: 0, available: 0)
    
    private var tableView:UITableView = UITableView()
    
    private var arrayOfValues: Array<AnyObject> = []
    
    private var arrayOfDates: Array<AnyObject> = []
    
    private var user = User(id: "", username: "", email: "", first_name: "", last_name: "", business_name: "", picture: "", phone: "", country: "", plaid_access_token: "")
    
    private let lblAccountPending:UILabel = UILabel()
    
    private let lblAccountAvailable:UILabel = UILabel()
    
    private let lblSubtext:UILabel = UILabel()
    
    private let headerView: UIView = UIView()

    private let activityIndicator:UIActivityIndicatorView = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.White)
    
    private let graph: BEMSimpleLineGraphView = BEMSimpleLineGraphView(frame: CGRectMake(0, 90, UIScreen.mainScreen().bounds.size.width, 200))
    
    private let notification = CWStatusBarNotification()
    
    private var gradient: CGGradient?

    private var gradientBottom: CGGradient?

    private var refreshControlView = UIRefreshControl()
    
    func indexChanged(sender: AnyObject) {
        if(sender.selectedSegmentIndex == 0) {
            lblAccountPending.removeFromSuperview()
            let subtext = NSAttributedString(string: "Available Balance", attributes:[
                NSFontAttributeName: UIFont(name: "MyriadPro-Regular", size: 12)!,
                NSForegroundColorAttributeName:UIColor.whiteColor().colorWithAlphaComponent(0.7)
                ])
            lblSubtext.attributedText = subtext
            self.view.addSubview(lblAccountAvailable)
//            addSubviewWithFade(lblAccountAvailable, parentView: self, duration: 0.8)
        }
        if(sender.selectedSegmentIndex == 1) {
            lblAccountAvailable.removeFromSuperview()
            let subtext = NSAttributedString(string: "Pending Balance", attributes:[
                NSFontAttributeName: UIFont(name: "MyriadPro-Regular", size: 12)!,
                NSForegroundColorAttributeName:UIColor.whiteColor().colorWithAlphaComponent(0.7)
                ])
            lblSubtext.attributedText = subtext
            self.view.addSubview(lblAccountPending)
//            addSubviewWithFade(lblAccountPending, parentView: self, duration: 0.8)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // VIEW DID LOAD
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureView()
        
        loadData()
        
        setupAppleWatch()
        
        addInfiniteScroll()
    }
    
    private func addInfiniteScroll() {
        // Add infinite scroll handler
        // change indicator view style to white
        self.tableView.infiniteScrollIndicatorStyle = .White
        
        // Add infinite scroll handler
        self.tableView.addInfiniteScrollWithHandler { (scrollView) -> Void in
            let tableView = scrollView as! UITableView
            
            //
            // fetch your data here, can be async operation,
            // just make sure to call finishInfiniteScroll in the end
            //
            if let history_array = self.accountHistoryArray {
                if history_array.count > 98 {
                    let lastIndex = NSIndexPath(forRow: self.accountHistoryArray!.count - 1, inSection: 0)
                    let id = self.accountHistoryArray![lastIndex.row].id
                    // fetch more data with the id
                    self.loadAccountHistory("100", starting_after: id, completionHandler: { (transactions, error) in
                        self.activityIndicator.stopAnimating()
                        if transactions?.count < 1 {
                            self.loadAccountHistory("100", starting_after: "", completionHandler: { _ in
                                self.tableView.reloadData()
                            })
                        }
                    })
                }
            }
            
            // make sure you reload tableView before calling -finishInfiniteScroll
            tableView.reloadData()
            
            // finish infinite scroll animation
            tableView.finishInfiniteScroll()
        }
    }
    
    // VIEW DID APPEAR
    override func viewDidAppear(animated: Bool) {
        self.view.addSubview(balanceSwitch)
        self.view.bringSubviewToFront(balanceSwitch)
        self.view.addSubview(tutorialButton)
        self.view.bringSubviewToFront(tutorialButton)
        UITextField.appearance().keyboardAppearance = .Light        
    }
    
    func setupAppleWatch() {
        print("setting up apple watch")
        // Send access token and Stripe key to Apple Watch
        if userAccessToken != nil && WCSession.isSupported(){ //makes sure it's not an iPad or iPod
            let watchSession = WCSession.defaultSession()
            watchSession.delegate = self
            watchSession.activateSession()
            if watchSession.paired && watchSession.watchAppInstalled {
                do {
                    print(watchSession.paired)
                    print(watchSession.watchAppInstalled)
                    try watchSession.updateApplicationContext(
                        [
                            "token": userAccessToken!
                        ]
                    )
                    print("setting watch data from home")
                } catch let error as NSError {
                    print(error.description)
                }
            }
        }
    }
    
    // Tooltip
    let tipView = EasyTipView(text: "Welcome to your Argent dashboard, in order to start accepting payments we will require account verification information.  Head to your profile page to learn more, tap to dismiss.", preferences: EasyTipView.globalPreferences)
    
    func presentTutorial(sender: AnyObject) {
        
        showMerchantModeModal(self)
        
        //tipView.show(forView: self.tutorialButton, withinSuperview: self.view)
        Answers.logCustomEventWithName("Dashboard Configuration Presented",
                                       customAttributes: [:])
        
    }
    
    override func viewDidDisappear(animated: Bool) {
    }
    
    func showGraphActivityIndicator() {
        activityIndicator.startAnimating()
        activityIndicator.hidesWhenStopped = true
        activityIndicator.center = CGPointMake(self.view.layer.frame.width*0.5, self.view.layer.frame.height*0.3)
        headerView.addSubview(activityIndicator)
    }
    
    func dateRangeSegmentControl(segment: UISegmentedControl) {
        showGraphActivityIndicator()
        if segment.selectedSegmentIndex == 0 {
            showGraphActivityIndicator()
            History.getHistoryArrays({ (_1d, _2w, _1m, _3m, _6m, _1y, _5y, err) in
                self.arrayOfValues = _2w!
                for index in 0..<self.arrayOfValues.count {
                    self.arrayOfValues[index] = self.arrayOfValues[index].floatValue/100
                }
                self.activityIndicator.stopAnimating()
                self.graph.reloadGraph()
            })
        }
        else if segment.selectedSegmentIndex == 1 {
            showGraphActivityIndicator()
            History.getHistoryArrays({ (_1d, _2w, _1m, _3m, _6m, _1y, _5y, err) in
                self.arrayOfValues = _1m!
                for index in 0..<self.arrayOfValues.count {
                    self.arrayOfValues[index] = self.arrayOfValues[index].floatValue/100
                }
                self.activityIndicator.stopAnimating()
                self.graph.reloadGraph()
            })
        }
        else if segment.selectedSegmentIndex == 2 {
            showGraphActivityIndicator()
            History.getHistoryArrays({ (_1d, _2w, _1m, _3m, _6m, _1y, _5y, err) in
                self.arrayOfValues = _3m!
                for index in 0..<self.arrayOfValues.count {
                    self.arrayOfValues[index] = self.arrayOfValues[index].floatValue/100
                }
                self.activityIndicator.stopAnimating()
                self.graph.reloadGraph()
            })
        }
        else if segment.selectedSegmentIndex == 3 {
            showGraphActivityIndicator()
            History.getHistoryArrays({ (_1d, _2w, _1m, _3m, _6m, _1y, _5y, err) in
                self.arrayOfValues = _6m!
                for index in 0..<self.arrayOfValues.count {
                    self.arrayOfValues[index] = self.arrayOfValues[index].floatValue/100
                }
                self.activityIndicator.stopAnimating()
                self.graph.reloadGraph()
            })
        }
        else if segment.selectedSegmentIndex == 4 {
            showGraphActivityIndicator()
            History.getHistoryArrays({ (_1d, _2w, _1m, _3m, _6m, _1y, _5y, err) in
                self.arrayOfValues = _1y!
                for index in 0..<self.arrayOfValues.count {
                    self.arrayOfValues[index] = self.arrayOfValues[index].floatValue/100
                }
                self.activityIndicator.stopAnimating()
                self.graph.reloadGraph()
            })
        }
    }
    
    //Changing Status Bar
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }
    
    func loadData() {
        
        // IMPORTANT: load new access token on home load, otherwise the old token will be requested to the server
        userAccessToken = NSUserDefaults.standardUserDefaults().valueForKey("userAccessToken")
        
        if String(userAccessToken) == "" || userAccessToken == nil || String(userAccessToken) == "(null)" {
            self.logout()
        }
        
        activityIndicator.center = tableView.center
        activityIndicator.startAnimating()
        activityIndicator.hidesWhenStopped = true
        headerView.addSubview(activityIndicator)
        
        if((userAccessToken) != nil) {
            // Get stripe data
            loadStripe({ (balance, err) in
                let pendingBalance = balance.pending
                let availableBalance = balance.available
                
                NSNotificationCenter.defaultCenter().postNotificationName("balance", object: nil, userInfo: ["available_bal":availableBalance,"pending_bal":pendingBalance])
                
                let formatter = NSNumberFormatter()
                formatter.numberStyle = .CurrencyStyle
                formatter.locale = NSLocale.currentLocale() // This is the default
                
                self.lblAccountPending.attributedText = formatCurrency(String(pendingBalance), fontName: "MyriadPro-Regular", superSize: 16, fontSize: 32, offsetSymbol: 10, offsetCents: 10)
                addSubviewWithFade(self.lblAccountPending, parentView: self, duration: 1)
                
                self.lblAccountAvailable.attributedText = formatCurrency(String(availableBalance), fontName: "MyriadPro-Regular", superSize: 16, fontSize: 32, offsetSymbol: 10, offsetCents: 10)
                addSubviewWithFade(self.lblSubtext, parentView: self, duration: 0.5)
            })
            
            // Get user account history
            loadAccountHistory("100", starting_after: "", completionHandler: { (historyArr, error) in
                if error != nil {
                    print(error)
                }
                // sets up the empty data set view after load if no data is present
                self.tableView.emptyDataSetSource = self
                self.tableView.emptyDataSetDelegate = self
                self.tableView.tableFooterView = UIView()
                self.activityIndicator.stopAnimating()
            })
            
            History.getHistoryArrays({ (_1d, _2w, _1m, _3m, _6m, _1y, _5y, err) in
                self.arrayOfValues = _3m!
                for index in 0..<self.arrayOfValues.count {
                    self.arrayOfValues[index] = self.arrayOfValues[index].floatValue/100
                }
                self.graph.reloadGraph()
            })
            
            // Get user profile
            User.getProfile({ (user, error) in
                
                if user?.first_name != "" {
                    
                    // Track user action
                    Answers.logCustomEventWithName("User logged in", customAttributes: nil)
                    
                    // showGlobalNotification("Welcome " + (user?.first_name)! + "!", duration: 2.5, inStyle: CWNotificationAnimationStyle.Top, outStyle: CWNotificationAnimationStyle.Top, notificationStyle: CWNotificationStyle.StatusBarNotification, color: UIColor.darkestBlue())
                }
                
                if(error != nil) {
                    print(error)
                    // check if user logged in, if not send to login
                    self.logout()
                }
            })
            
        } else {
            // check if user logged in, if not send to login
            self.logout()
        }
    }
    
    func loadAccountHistory(limit: String, starting_after: String, completionHandler: ([History]?, NSError?) -> ()) {
        History.getAccountHistory(limit, starting_after: starting_after, completionHandler: { (transactions, error) in
            if error != nil {
                let alert = UIAlertController(title: "Error", message: "Could not load history \(error?.localizedDescription)", preferredStyle: UIAlertControllerStyle.Alert)
                alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: nil))
                self.presentViewController(alert, animated: true, completion: nil)
            }
            self.accountHistoryArray = transactions
            completionHandler(transactions!, error)
            self.tableView.reloadData()
        })
    }
    
    func loadStripe(completionHandler: (Balance, NSError?) -> ()) {
        // Set account balance label
        
        Balance.getStripeBalance({ (balance, error) in
            if error != nil {
                let alert = UIAlertController(title: "Error", message: "Could not load history \(error?.localizedDescription)", preferredStyle: UIAlertControllerStyle.Alert)
                alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: nil))
                self.presentViewController(alert, animated: true, completion: nil)
            }
            self.balance = balance!
            completionHandler(balance!, error)
        })
    }
    
    // LOGOUT
    func logout() {
        // put in api request to log user out
        NSUserDefaults.standardUserDefaults().setValue("", forKey: "userAccessToken")
        NSUserDefaults.standardUserDefaults().synchronize();
        
        // go to login view
        let sb = UIStoryboard(name: "Auth", bundle: nil)
        let loginVC = sb.instantiateViewControllerWithIdentifier("authViewController")
        loginVC.modalTransitionStyle = .CrossDissolve
        let root = UIApplication.sharedApplication().keyWindow?.rootViewController
        root!.presentViewController(loginVC, animated: true, completion: { () -> Void in })
        
        Answers.logCustomEventWithName("Logged User Out from Home",
                                       customAttributes: [:])
    }
    
    // MARK: TableView Delegate
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.accountHistoryArray?.count > 0 {
            self.view.addSubview(dateRangeSegment)
        }
        return self.accountHistoryArray?.count ?? 0
    }
    
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        self.tableView.registerNib(UINib(nibName: "HistoryCustomCell", bundle: nil), forCellReuseIdentifier: "idCellCustomHistory")
        
        let cell = self.tableView.dequeueReusableCellWithIdentifier("idCellCustomHistory") as! HistoryCustomCell
        
        // CellAnimator.animateCell(cell, withTransform: CellAnimator.TransformTilt, andDuration: 0.3)
        
        let item = self.accountHistoryArray?[indexPath.row]
        cell.selectionStyle = UITableViewCellSelectionStyle.None
        cell.backgroundColor = UIColor.whiteColor()
        cell.lblAmount?.text = ""
        cell.lblDate?.text = ""

        if let amount = item?.amount {
            let currencyText = formatCurrency(amount, fontName: "MyriadPro-Regular", superSize: 17, fontSize: 17, offsetSymbol: 0, offsetCents: 0)
            
            if let type = item?.type {
                if type == "charge" {
                    let chargeType = adjustAttributedString("  Charged", spacing: 1.2, fontName: "MyriadPro-Regular", fontSize: 11, fontColor: UIColor.lightBlue(), lineSpacing: 0.0)
                    cell.lblAmount.attributedText = currencyText + chargeType
                    cell.img.image = UIImage(named: "IconCheckFilled")
                } else if type == "refund" || type == "application_fee_refund" {
                    let chargeType = adjustAttributedString("  Refunded", spacing: 1.2, fontName: "MyriadPro-Regular", fontSize: 11, fontColor: UIColor.lightBlue(), lineSpacing: 0.0)
                    cell.lblAmount.attributedText = currencyText + chargeType
                    cell.img.image = UIImage(named: "ic_refund")
                } else if type == "payment" {
                    let chargeType = adjustAttributedString("  Payment", spacing: 1.2, fontName: "MyriadPro-Regular", fontSize: 11, fontColor: UIColor.lightBlue(), lineSpacing: 0.0)
                    cell.lblAmount.attributedText = currencyText + chargeType
                    cell.img.image = UIImage(named: "IconCheckFilled")
                } else if type == "adjustment" {
                    let chargeType = adjustAttributedString(" Adjustment", spacing: 1.2, fontName: "MyriadPro-Regular", fontSize: 11, fontColor: UIColor.lightBlue(), lineSpacing: 0.0)
                    cell.lblAmount.attributedText = currencyText + chargeType
                    cell.img.image = UIImage(named: "ic_adjust")
                } else if type == "transfer" {
                    let chargeType = adjustAttributedString("  Bank Transfer", spacing: 1.2, fontName: "MyriadPro-Regular", fontSize: 11, fontColor: UIColor.lightBlue(), lineSpacing: 0.0)
                    cell.lblAmount.attributedText = currencyText + chargeType
                    cell.img.image = UIImage(named: "ic_transfer")
                } else if type == "transfer_failure" {
                    let chargeType = adjustAttributedString("  Transfer failure", spacing: 1.2, fontName: "MyriadPro-Regular", fontSize: 11, fontColor: UIColor.lightBlue(), lineSpacing: 0.0)
                    cell.lblAmount.attributedText = currencyText + chargeType
                    cell.img.image = UIImage(named: "ic_alert")
                } else {
                    cell.lblAmount.attributedText = currencyText
                    cell.img.image = UIImage(named: "IconCheckFilled")
                }
            }
            
            if Double(amount)!/100 < 0 {
                // cell.lblCreditDebit?.text = "Debit"
                cell.lblAmount?.textColor = UIColor.darkBlue()
            } else {
                // cell.lblCreditDebit?.text = "Credit"
                cell.lblAmount?.textColor = UIColor.darkBlue()
            }
            
            // Identify System Fonts
            for familyName in UIFont.familyNames() {
                for fontName in UIFont.fontNamesForFamilyName(familyName as! String) {
                    //print("\(familyName) : \(fontName)")
                }
            }
            
        }
        if let date = item?.created
        {
            if(!date.isEmpty || date != "") {
                let converted_date = NSDate(timeIntervalSince1970: Double(date)!)
                dateFormatter.dateStyle = .ShortStyle
                dateFormatter.dateFormat = "MMM dd"
                let formatted_date = dateFormatter.stringFromDate(converted_date)
                cell.lblDate?.layer.cornerRadius = 10
                cell.lblDate?.layer.borderColor = UIColor.lightBlue().colorWithAlphaComponent(0.3).CGColor
                cell.lblDate?.textColor = UIColor.lightBlue().colorWithAlphaComponent(0.6)
                cell.lblDate?.layer.borderWidth = 0
                cell.lblDate?.font = UIFont(name: "MyriadPro-Regular", size: 11)
                cell.lblDate?.text = String(formatted_date) //+ " / uid " + uid
            } else {
                
            }
        }
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        // self.performSegueWithIdentifier("historyDetailView", sender: self)
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 80.0
    }
}

extension HomeViewController {
    // Delegate: DZNEmptyDataSet
    
    func titleForEmptyDataSet(scrollView: UIScrollView!) -> NSAttributedString! {
        let str = "Transactions"
        return NSAttributedString(string: str, attributes: inverseHeaderAttrs)
    }
    
    func descriptionForEmptyDataSet(scrollView: UIScrollView!) -> NSAttributedString! {
        let str = "No transactions have occurred yet."
        // let attrs = [NSFontAttributeName: UIFont.preferredFontForTextStyle(UIFontTextStyleBody)]
        return NSAttributedString(string: str, attributes: inverseBodyAttrs)
    }
    
    func imageForEmptyDataSet(scrollView: UIScrollView!) -> UIImage! {
        return UIImage(named: "IconEmptyCashCircle")
    }
    
    func buttonTitleForEmptyDataSet(scrollView: UIScrollView!, forState state: UIControlState) -> NSAttributedString! {
        let str = "Verify account and create a billing plan"
        // let attrs = [NSFontAttributeName: UIFont.preferredFontForTextStyle(UIFontTextStyleCallout)]
        return NSAttributedString(string: str, attributes: inverseCalloutAttrs)
    }
    
    func emptyDataSetDidTapButton(scrollView: UIScrollView!) {
        let viewController:UIViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("RecurringBillingViewController") as! RecurringBillingViewController
        self.presentViewController(viewController, animated: true, completion: nil)
    }
}

extension HomeViewController {
    
    // MARK: BEM Graph Delegate Methods
    func numberOfPointsInLineGraph(graph: BEMSimpleLineGraphView) -> Int {
        return Int(self.arrayOfValues.count)
        
    }
    
    func lineGraph(graph: BEMSimpleLineGraphView, valueForPointAtIndex index: Int) -> CGFloat {
        return CGFloat(self.arrayOfValues[index] as! NSNumber)
    }
    
    func numberOfGapsBetweenLabelsOnLineGraph(graph: BEMSimpleLineGraphView) -> Int {
        return 2
    }
}

// Used only in HomeViewController
extension UISegmentedControl {
    func removeBorders() {
        setTitleTextAttributes([
            NSForegroundColorAttributeName : UIColor.whiteColor().colorWithAlphaComponent(0.5),
            NSFontAttributeName : UIFont(name: "MyriadPro-Regular", size: 11)!
            ],
                               forState: .Normal)
        setTitleTextAttributes([
            NSForegroundColorAttributeName : UIColor.whiteColor(),
            NSFontAttributeName : UIFont(name: "MyriadPro-Regular", size: 14)!
            ],
                               forState: .Selected)
        setBackgroundImage(imageWithColor(UIColor.clearColor(), source: "IconEmpty"), forState: .Normal, barMetrics: .Default)
        setBackgroundImage(imageWithColor(UIColor.clearColor(), source: "IconEmpty"), forState: .Selected, barMetrics: .Default)
        setDividerImage(imageWithColor(UIColor.clearColor(), source: "IconEmpty"), forLeftSegmentState: .Normal, rightSegmentState: .Normal, barMetrics: .Default)
    }
    
    // create a 1x1 image with this color
    private func imageWithColor(color: UIColor, source: String) -> UIImage {
        let rect = CGRectMake(10.0, 0.0, 100.0, 1.0)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        CGContextSetFillColorWithColor(context, color.CGColor);
        CGContextFillRect(context, rect);
        let image = UIImage(named: source)
        UIGraphicsEndImageContext();
        return image!
    }
}

extension HomeViewController {
    func configureView() {
        
        let screenWidth = screen.size.width
        let screenHeight = screen.size.height

        let app: UIApplication = UIApplication.sharedApplication()
        let statusBarHeight: CGFloat = app.statusBarFrame.size.height
        let statusBarView: UIView = UIView(frame: CGRectMake(0, -statusBarHeight, UIScreen.mainScreen().bounds.size.width, statusBarHeight))
        statusBarView.backgroundColor = UIColor.whiteColor()
        self.navigationController?.navigationBar.addSubview(statusBarView)
        self.navigationController?.navigationBar.bringSubviewToFront(statusBarView)
        
        self.view.backgroundColor = UIColor.darkestBlue()
        
        refreshControlView.tintColor = UIColor.whiteColor()
        refreshControlView.frame = CGRect(x: screenWidth/2-15, y: 30, width: 30, height: 30)
        refreshControlView.addTarget(self, action: #selector(self.refresh(_:)), forControlEvents: UIControlEvents.ValueChanged)
        self.tableView.addSubview(refreshControlView) // not required when using UITableViewController

        // put all content in headerview
        headerView.backgroundColor = UIColor.clearColor()
        headerView.frame = CGRectMake(0, 0, UIScreen.mainScreen().bounds.size.width, 280)
        
        let footerView = UIView()
        footerView.frame = CGRect(x: 0, y: screenHeight-100, width: screenWidth, height: 100)
        footerView.backgroundColor = tableView.backgroundColor
//        backgroundImageView.addSubview(footerView)
        
        // add background image view to take up entire screen, make header color transparent to give parallax effect
        backgroundImageView.frame = CGRect(x: 0, y: -2, width: screenWidth, height: screenHeight+4)
        backgroundImageView.image = UIImage(named: "BackgroundGradientBlueDark")
        addSubviewWithFade(backgroundImageView, parentView: self, duration: 0.5)
        
        tableView.frame = CGRect(x: 0, y: 0, width: screenWidth, height: screenHeight-45)
        tableView.tableHeaderView = headerView
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorColor = UIColor.lightBlue().colorWithAlphaComponent(0.3)
        tableView.showsVerticalScrollIndicator = false
        tableView.backgroundColor = UIColor.clearColor()
        addSubviewWithFade(tableView, parentView: self, duration: 1)
        
        if let tabBarController = window?.rootViewController as? UITabBarController {
            for item in tabBarController.tabBar.items! {
                if let image = item.image {
                    item.image = image.imageWithRenderingMode(.AlwaysOriginal)
                }
            }
        }
        
        // Balance Switch
        balanceSwitch.selectedSegmentIndex = 1
        balanceSwitch.tintColor = UIColor.whiteColor()
        balanceSwitch.backgroundColor = UIColor.clearColor()
        balanceSwitch.frame = CGRect(x: 20, y: 42, width: 40, height: 25)
        balanceSwitch.alpha = 0.75
        //autoresizing so it stays at top right (flexible left and flexible bottom margin)
        balanceSwitch.autoresizingMask = [.FlexibleLeftMargin, .FlexibleRightMargin]
        balanceSwitch.bringSubviewToFront(balanceSwitch)
        balanceSwitch.addTarget(self, action: #selector(HomeViewController.indexChanged(_:)), forControlEvents: .ValueChanged)
        
        graph.dataSource = self
        graph.frame = CGRect(x: 0, y: 100, width: screenWidth, height: 120)
        graph.colorTop = UIColor.clearColor()
        graph.colorBottom = UIColor.clearColor()
        graph.colorPoint = UIColor.clearColor()
        graph.colorBackgroundPopUplabel = UIColor.whiteColor()
        graph.delegate = self
        let gradientColors : [CGColor] = [UIColor.whiteColor().CGColor, UIColor(rgba: "#b5ebff").CGColor, UIColor.pastelSkyBlue().CGColor]
        let gradientColorsBottom : [CGColor] = [UIColor.whiteColor().colorWithAlphaComponent(0.3).CGColor, UIColor.whiteColor().colorWithAlphaComponent(0.1).CGColor, UIColor.whiteColor().colorWithAlphaComponent(0).CGColor]
        let colorspace = CGColorSpaceCreateDeviceRGB()
        let locations: [CGFloat] = [0.0, 0.3, 1.0]
        self.gradient = CGGradientCreateWithColors(colorspace, gradientColors, locations)
        self.gradientBottom = CGGradientCreateWithColors(colorspace, gradientColorsBottom, locations)
        graph.gradientLine = self.gradient!
        graph.gradientBottom = self.gradientBottom!
        graph.colorLine = UIColor.whiteColor()
        graph.gradientLineDirection = .Vertical
        graph.widthLine = 2
        graph.displayDotsWhileAnimating = true
        graph.enablePopUpReport = true
        graph.enableTouchReport = true
        graph.widthTouchInputLine = 4
        graph.alphaTouchInputLine = 0.5
        graph.colorTouchInputLine = UIColor.skyBlue()
        graph.enableBezierCurve = true
        graph.alwaysDisplayDots = true
        graph.animationGraphStyle = BEMLineAnimation.Draw
        graph.noDataLabelColor = UIColor.whiteColor()
        graph.sizePoint = 5.0
        graph.layer.masksToBounds = true
        addSubviewWithFade(graph, parentView: self, duration: 0.5)
        self.view.bringSubviewToFront(graph)
        self.headerView.bringSubviewToFront(graph)
        //        graph.layer.shadowColor = UIColor.darkBlue().colorWithAlphaComponent(0.5).CGColor
        //        graph.layer.shadowColor = UIColor.clearColor().colorWithAlphaComponent(0.5).CGColor
        //        graph.layer.shadowOffset = CGSize(width: 2, height: 10)
        //        graph.layer.shadowRadius = 5
        //        graph.layer.shadowOpacity = 1
        
        let graphOutlineView = UIImageView()
        graphOutlineView.image = UIImage(named: "GraphOutlineLong")
        graphOutlineView.frame = CGRect(x: 0, y: 20, width: screenWidth, height: 300)
        graphOutlineView.contentMode = .Center
//        addSubviewWithFade(graphOutlineView, parentView: self, duration: 1)
        
        // split the date segments
        let horizontalSplitter = UIView()
        horizontalSplitter.backgroundColor = UIColor.clearColor()
        horizontalSplitter.frame = CGRect(x: 15.0, y: 260.0, width: screenWidth - 15.0, height: 1)
        headerView.addSubview(horizontalSplitter)
        
        dateRangeSegment.frame = CGRect(x: 45.0, y: 230.0, width: view.bounds.width - 90.0, height: 30.0)
        dateRangeSegment.selectedSegmentIndex = 2
        dateRangeSegment.removeBorders()
        dateRangeSegment.addTarget(self, action: #selector(HomeViewController.dateRangeSegmentControl(_:)), forControlEvents: .ValueChanged)
        
        tutorialButton.frame = CGRect(x: screenWidth-43, y: 38, width: 35, height: 35)
        tutorialButton.setImage(UIImage(named: "ic_adjust_light"), forState: .Normal)
        tutorialButton.setTitle("Tuts", forState: .Normal)
        tutorialButton.setTitleColor(UIColor.redColor(), forState: .Normal)
        tutorialButton.addTarget(self, action: #selector(HomeViewController.presentTutorial(_:)), forControlEvents: .TouchUpInside)
        tutorialButton.addTarget(self, action: #selector(HomeViewController.presentTutorial(_:)), forControlEvents: .TouchUpOutside)
        
        lblAccountAvailable.textColor = UIColor.whiteColor()
        lblAccountAvailable.frame = CGRect(x: 0, y: 31, width: screenWidth, height: 60)
        lblAccountAvailable.textAlignment = .Center
        let str0 = NSAttributedString(string: "N/A", attributes:[
            NSFontAttributeName: UIFont(name: "MyriadPro-Regular", size: 18)!,
            NSForegroundColorAttributeName:UIColor.whiteColor().colorWithAlphaComponent(0.7)
            ])
        lblAccountAvailable.attributedText = str0

        lblAccountPending.textColor = UIColor.whiteColor()
        lblAccountPending.frame = CGRect(x: 0, y: 31, width: screenWidth, height: 60)
        lblAccountPending.textAlignment = .Center
        let str1 = NSAttributedString(string: "N/A", attributes:[
            NSFontAttributeName: UIFont(name: "MyriadPro-Regular", size: 18)!,
            NSForegroundColorAttributeName:UIColor.whiteColor().colorWithAlphaComponent(0.7)
            ])
        lblAccountPending.attributedText = str1

        lblSubtext.textColor = UIColor.whiteColor()
        lblSubtext.frame = CGRect(x: 0, y: 55, width: screenWidth, height: 60)
        lblSubtext.alpha = 0.5
        lblSubtext.textAlignment = .Center
        let subtext = NSAttributedString(string: "Pending Balance", attributes:[
            NSFontAttributeName: UIFont(name: "MyriadPro-Regular", size: 12)!,
            NSForegroundColorAttributeName:UIColor.whiteColor().colorWithAlphaComponent(0.7)
            ])
        lblSubtext.attributedText = subtext
    }
}

extension HomeViewController {
    func scrollViewDidScroll(scrollView: UIScrollView) {
        // print(tableView.contentOffset.y)
        
        if tableView.contentOffset.y > 0 {
            self.view.bringSubviewToFront(tableView)
            
            UIView.animateWithDuration(0.3, delay: 0.0, options: UIViewAnimationOptions.CurveEaseOut, animations: {
                self.dateRangeSegment.alpha = 0.5
            }, completion: nil)
        } else {
            self.view.bringSubviewToFront(dateRangeSegment)
            self.view.bringSubviewToFront(graph)
            self.view.bringSubviewToFront(tutorialButton)
            self.view.bringSubviewToFront(balanceSwitch)
            self.view.bringSubviewToFront(lblAccountPending)
            self.view.bringSubviewToFront(lblAccountAvailable)
            self.view.bringSubviewToFront(lblSubtext)
            
            UIView.animateWithDuration(0.3, delay: 0.0, options: UIViewAnimationOptions.CurveEaseOut, animations: {
                self.dateRangeSegment.alpha = 1.0
            }, completion: nil)
        }
        if tableView.contentOffset.y > 50 {
            UIView.animateWithDuration(0.3, delay: 0.0, options: UIViewAnimationOptions.CurveEaseOut, animations: {
                self.graph.alpha = 0.5
                }, completion: nil)
        } else {
            UIView.animateWithDuration(0.3, delay: 0.0, options: UIViewAnimationOptions.CurveEaseOut, animations: {
                self.graph.alpha = 1.0
                }, completion: nil)
        }
        
        if tableView.contentOffset.y > 150 {
            UIView.animateWithDuration(0.3, delay: 0.0, options: UIViewAnimationOptions.CurveEaseOut, animations: {
                self.tutorialButton.alpha = 0.5
                self.balanceSwitch.alpha = 0.5
                self.lblAccountPending.alpha = 0.5
                self.lblAccountAvailable.alpha = 0.5
                self.lblSubtext.alpha = 0.5
            }, completion: nil)
        } else {
            UIView.animateWithDuration(0.3, delay: 0.0, options: UIViewAnimationOptions.CurveEaseOut, animations: {
                self.tutorialButton.alpha = 1.0
                self.balanceSwitch.alpha = 1.0
                self.lblAccountPending.alpha = 1.0
                self.lblAccountAvailable.alpha = 1.0
                self.lblSubtext.alpha = 1.0
            }, completion: nil)
        }
    }
}

extension HomeViewController {
    // EasyTipView Delegate
    func easyTipViewDidDismiss(tipView: EasyTipView) {
        print("dismissed")
    }
}


extension HomeViewController {
    func refresh(sender: UIRefreshControl) {
        refreshControlView.endRefreshing()
        self.loadAccountHistory("100", starting_after: "", completionHandler: { (_: [History]?, NSError) in })
    }
}


extension HomeViewController {
    // MARK: showMerchantModeModal modal
    
    func showMerchantModeModal(sender: AnyObject) {
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let navigationController = storyboard.instantiateViewControllerWithIdentifier("merchantModalNavigationController") as! UINavigationController
        let formSheetController = MZFormSheetPresentationViewController(contentViewController: navigationController)
        
        print("showing merchant mode modal")
        // Initialize and style the terms and conditions modal
        formSheetController.presentationController?.contentViewSize = CGSizeMake(280, 280)
        formSheetController.presentationController?.shouldUseMotionEffect = true
        formSheetController.presentationController?.containerView?.backgroundColor = UIColor.pastelDarkBlue().colorWithAlphaComponent(0.5)
        formSheetController.presentationController?.containerView?.sizeToFit()
        formSheetController.presentationController?.shouldApplyBackgroundBlurEffect = false
        formSheetController.presentationController?.blurEffectStyle = UIBlurEffectStyle.Dark
        formSheetController.presentationController?.shouldDismissOnBackgroundViewTap = true
        formSheetController.contentViewControllerTransitionStyle = MZFormSheetPresentationTransitionStyle.SlideFromBottom
        formSheetController.presentationController?.movementActionWhenKeyboardAppears = MZFormSheetActionWhenKeyboardAppears.CenterVertically
        formSheetController.presentationController?.shouldCenterHorizontally = true
        formSheetController.presentationController?.portraitTopInset = 100
        formSheetController.contentViewCornerRadius = 5
        formSheetController.allowDismissByPanningPresentedView = true
        formSheetController.interactivePanGestureDismissalDirection = .All;
        
        let presentedViewController = navigationController.viewControllers.first as! MerchantModeModalViewController
        
        // keep passing along user data to modal
        presentedViewController.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem()
        presentedViewController.navigationItem.leftItemsSupplementBackButton = true
        
        // Be sure to update current module on storyboard
        self.presentViewController(formSheetController, animated: true, completion: nil)
    }
}
