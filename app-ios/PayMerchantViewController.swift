//
//  PayMerchantViewController.swift
//  app-ios
//
//  Created by Sinan Ulkuatam on 5/8/16.
//  Copyright © 2016 Sinan Ulkuatam. All rights reserved.
//

import Foundation
import UIKit
import MZFormSheetPresentationController
import XLActionController
import Alamofire
import Stripe
import SwiftyJSON
import CWStatusBarNotification
import Crashlytics

class PayMerchantViewController: UIViewController, STPPaymentCardTextFieldDelegate, PKPaymentAuthorizationViewControllerDelegate, UITextFieldDelegate {
    
    var detailUser: User? {
        didSet {
        }
    }
    
    let currencyFormatter = NSNumberFormatter()

    let chargeInputView = UITextField()

    let merchantLabel = UILabel()

    let selectPaymentOptionButton:UIButton = UIButton()
    
    var paymentMethod: String = "None"
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // This will set to only one instance
        
        self.view.backgroundColor = UIColor.whiteColor()
        self.view.layer.borderWidth = 1
        self.view.layer.masksToBounds = true
        // border radius
        self.view.layer.cornerRadius = 10.0
        // border
        self.view.layer.borderColor = UIColor.darkGrayColor().colorWithAlphaComponent(0.2).CGColor
        self.view.layer.borderWidth = 1
        // drop shadow
        self.view.layer.shadowColor = UIColor.blackColor().CGColor
        self.view.layer.shadowOpacity = 0.8
        self.view.layer.shadowRadius = 3.0
        self.view.layer.shadowOffset = CGSizeMake(2.0, 2.0)

        
        // screen width and height:
        let screen = UIScreen.mainScreen().bounds
        _ = screen.size.width
        _ = screen.size.height
        
        if let bn = detailUser?.business_name {
            merchantLabel.text = "Transfer to " + bn
        } else if let fn = detailUser?.first_name, ln = detailUser?.last_name {
            merchantLabel.text = "Transfer to " + fn + " " + ln
        } else if let un = detailUser?.username {
            merchantLabel.text = "Transer to @" + un
        } else {
            merchantLabel.text = "Send Transfer"
        }
        
        merchantLabel.frame = CGRect(x: 0, y: 35, width: 280, height: 20)
        merchantLabel.textAlignment = .Center
        merchantLabel.font = UIFont(name: "MyriadPro-Regular", size: 17)!
        merchantLabel.textColor = UIColor.oceanBlue()
        self.view.addSubview(merchantLabel)
        
        chargeInputView.delegate = self
        chargeInputView.frame = CGRect(x: 0, y: 85, width: 280, height: 100)
        chargeInputView.textColor = UIColor.seaBlue()
        chargeInputView.backgroundColor = UIColor.clearColor()
        chargeInputView.font = UIFont(name: "MyriadPro-Regular", size: 48)
        chargeInputView.textAlignment = .Center
        chargeInputView.keyboardType = .NumberPad
        chargeInputView.placeholder = "$0.00"
        chargeInputView.addTarget(self, action: #selector(PayMerchantViewController.textField(_:shouldChangeCharactersInRange:replacementString:)), forControlEvents: UIControlEvents.EditingChanged)

        selectPaymentOptionButton.frame = CGRect(x: 0, y: 220, width: 280, height: 60)
        selectPaymentOptionButton.layer.borderColor = UIColor.whiteColor().CGColor
        selectPaymentOptionButton.layer.borderWidth = 0
        selectPaymentOptionButton.layer.cornerRadius = 0
        selectPaymentOptionButton.layer.masksToBounds = true
        var attribs: [String: AnyObject] = [:]
        attribs[NSFontAttributeName] = UIFont(name: "MyriadPro-Regular", size: 14)
        attribs[NSForegroundColorAttributeName] = UIColor.whiteColor()
        let str = NSAttributedString(string: "Select Payment Option", attributes: attribs)
        selectPaymentOptionButton.setBackgroundColor(UIColor.oceanBlue(), forState: .Normal)
        selectPaymentOptionButton.setBackgroundColor(UIColor.oceanBlue().lighterColor(), forState: .Highlighted)
        selectPaymentOptionButton.setAttributedTitle(str, forState: .Normal)
        selectPaymentOptionButton.addTarget(self, action: #selector(PayMerchantViewController.showPayModal(_:)), forControlEvents: .TouchUpInside)
        self.view.addSubview(selectPaymentOptionButton)
        let rectShape = CAShapeLayer()
        rectShape.bounds = selectPaymentOptionButton.frame
        rectShape.position = selectPaymentOptionButton.center
        rectShape.path = UIBezierPath(roundedRect: selectPaymentOptionButton.bounds, byRoundingCorners: [.BottomLeft, .BottomRight], cornerRadii: CGSize(width: 10, height: 10)).CGPath
        
        selectPaymentOptionButton.layer.backgroundColor = UIColor.mediumBlue().CGColor
        //Here I'm masking the textView's layer with rectShape layer
        selectPaymentOptionButton.layer.mask = rectShape
        
        //Looks for single or multiple taps.  Close keyboard on tap
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(PayMerchantViewController.dismissKeyboard))
        view.addGestureRecognizer(tap)
    }

    override func viewDidDisappear(animated: Bool) {
        
    }
    
    override func viewDidAppear(animated: Bool) {
        addSubviewWithBounce(chargeInputView, parentView: self, duration: 0.3)
        chargeInputView.becomeFirstResponder()
    }
    
    func close() -> Void {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        
        // Construct the text that will be in the field if this change is accepted
        let oldText = chargeInputView.text! as NSString
        var newText = oldText.stringByReplacingCharactersInRange(range, withString: string) as NSString!
        var newTextString = String(newText)
        
        let digits = NSCharacterSet.decimalDigitCharacterSet()
        var digitText = ""
        for c in newTextString.unicodeScalars {
            if digits.longCharacterIsMember(c.value) {
                digitText.append(c)
            }
        }
        
        let formatter = NSNumberFormatter()
        formatter.numberStyle = NSNumberFormatterStyle.CurrencyStyle
        formatter.locale = NSLocale.currentLocale()
        let numberFromField = (NSString(string: digitText).doubleValue)/100
        newText = formatter.stringFromNumber(numberFromField)
        
        textField.text = String(newText)
        
        return false
    }
    
    // MARK: Payment Options Modal
    
    func showPayModal(sender: AnyObject) {
        let actionController = ArgentActionController()
        actionController.headerData = "Select Payment Method"
        actionController.addAction(Action("Apple Pay", style: .Default, handler: { action in
            self.chargeInputView.endEditing(true)
            let _ = Timeout(0.5) {
                self.showApplePayModal(self)
                self.paymentMethod = "Apple Pay"
            }
        }))
//        actionController.addAction(Action("ACH Transfer", style: .Default, handler: { action in
//            let _ = Timeout(0.5) {
//                self.showACHModal(self)
//                self.paymentMethod = "ACH"
//            }
//        }))
        actionController.addAction(Action("Credit or Debit Card", style: .Default, handler: { action in
            let _ = Timeout(0.5) {
                self.showCreditCardModal(self)
                self.paymentMethod = "Card"
            }
        }))
        actionController.addSection(ActionSection())
        actionController.addAction(Action("Cancel", style: .Destructive, handler: { action in
        }))
        self.presentViewController(actionController, animated: true, completion: { _ in
        })
    }
    
    
    // MARK: APPLE PAY
    
    
    func showApplePayModal(sender: AnyObject) {
        guard let request = Stripe.paymentRequestWithMerchantIdentifier(MERCHANT_ID) else {
            // request will be nil if running on < iOS8
            return
        }
        if(chargeInputView.text == "" || chargeInputView.text == "$0.00") {
            showGlobalNotification("Amount invalid", duration: 5.0, inStyle: CWNotificationAnimationStyle.Top, outStyle: CWNotificationAnimationStyle.Top, notificationStyle: CWNotificationStyle.StatusBarNotification, color: UIColor.brandRed())
        } else {
            var str = chargeInputView.text
            str?.removeAtIndex(str!.characters.indices.first!) // remove first letter
            let floatValue = (str! as NSString).floatValue
            if(floatValue<1) {
                showGlobalNotification("Amount cannot be less than 1", duration: 8.0, inStyle: CWNotificationAnimationStyle.Top, outStyle: CWNotificationAnimationStyle.Top, notificationStyle: CWNotificationStyle.StatusBarNotification, color: UIColor.brandRed())
            } else {
                request.paymentSummaryItems = [
                    PKPaymentSummaryItem(label: (detailUser?.first_name)!, amount: NSDecimalNumber(float: floatValue))
                ]
                print(request)
                if (Stripe.canSubmitPaymentRequest(request)) {
                    print("stripe can submit payment request")
                    let paymentController = PKPaymentAuthorizationViewController(paymentRequest: request)
                    paymentController.delegate = self
                    self.presentViewController(paymentController, animated: true, completion: nil)
                } else {
                    print("something went wrong")
                    // let paymentController = PaymentViewController()
                    // Below displays manual credit card entry forms
                    // presentViewController(paymentController, animated: true, completion: nil)
                    // Show the user your own credit card form (see options 2 or 3)
                }
            }
        }
    }
    
    // STRIPE FUNCTIONS
    func paymentAuthorizationViewController(controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, completion: (PKPaymentAuthorizationStatus) -> Void) {
        /*
         We'll implement this method below in 'Creating a single-use token'.
         Note that we've also been given a block that takes a
         PKPaymentAuthorizationStatus. We'll call this function with either
         PKPaymentAuthorizationStatusSuccess or PKPaymentAuthorizationStatusFailure
         after all of our asynchronous code is finished executing. This is how the
         PKPaymentAuthorizationViewController knows when and how to update its UI.
         */
        // print("in payment auth")
        handlePaymentAuthorizationWithPayment(payment) { (PKPaymentAuthorizationStatus) -> () in
            // close pay modal
            showGlobalNotification("Paid " + (self.detailUser?.username)! + " successfully!", duration: 3.0, inStyle: CWNotificationAnimationStyle.Top, outStyle: CWNotificationAnimationStyle.Top, notificationStyle: CWNotificationStyle.NavigationBarNotification, color: UIColor.brandGreen())
            // print("success")
            controller.dismissViewControllerAnimated(true, completion: nil)
            self.chargeInputView.text = ""
            self.dismissViewControllerAnimated(true, completion: {
                //
            })
        }
    }
    
    func handlePaymentAuthorizationWithPayment(payment: PKPayment, completion: PKPaymentAuthorizationStatus -> ()) {
        STPAPIClient.sharedClient().createTokenWithPayment(payment) { (token, error) -> Void in
            if error != nil {
                completion(PKPaymentAuthorizationStatus.Failure)
                return
            }
            /*
             We'll implement this below in "Sending the token to your server".
             Notice that we're passing the completion block through.
             See the above comment in didAuthorizePayment to learn why.
             */
            print("creating backend charge with token")
            self.createBackendChargeWithToken(token, completion: completion)
        }
    }
    
    func createBackendChargeWithToken(token: STPToken!, completion: PKPaymentAuthorizationStatus -> ()) {
        // SEND REQUEST TO Argent API ENDPOINT TO EXCHANGE STRIPE TOKEN
        
        print("creating backend token")
        var str = chargeInputView.text
        str?.removeAtIndex(str!.characters.indices.first!) // remove first letter
        let floatValue = (str! as NSString).floatValue
        let amountInCents = Int(floatValue*100)
        User.getProfile { (user, NSError) in
            let url = API_URL + "/stripe/" + (user?.id)! + "/charge/" + (self.detailUser?.username)!
            
            let parameters : [String : AnyObject] = [
                "token": String(token) ?? "",
                "amount": amountInCents
            ]
            
            let uat = userAccessToken
            let _ = uat.map { (unwrapped_access_token) -> Void in
                let headers = [
                    "Authorization": "Bearer " + String(unwrapped_access_token),
                    "Content-Type": "application/json"
                ]
                // for invalid character 0 be sure the content type is application/json and enconding is .JSON
                Alamofire.request(.POST, url,
                    parameters: parameters,
                    encoding:.JSON,
                    headers: headers)
                    .validate(contentType: ["application/json"])
                    .responseJSON { response in
                        switch response.result {
                        case .Success:
                            if let value = response.result.value {
                                //let json = JSON(value)
                                print(PKPaymentAuthorizationStatus.Success)
                                completion(PKPaymentAuthorizationStatus.Success)
                                Answers.logPurchaseWithPrice(decimalWithString(self.currencyFormatter, string: String(floatValue)),
                                    currency: "USD",
                                    success: true,
                                    itemName: "Payment",
                                    itemType: "Merchant One-Time Sale",
                                    itemId: "sku-###",
                                    customAttributes: [
                                        "method": self.paymentMethod
                                    ])
                                self.dismissViewControllerAnimated(true, completion: {
                                    //
                                })
                            }
                        case .Failure(let error):
                            print(PKPaymentAuthorizationStatus.Failure)
                            completion(PKPaymentAuthorizationStatus.Failure)
                            print(error)
                        }
                }
            }
        }
    }
    
    func paymentAuthorizationViewControllerDidFinish(controller: PKPaymentAuthorizationViewController) {
        dismissViewControllerAnimated(true, completion: nil)
        controller.dismissViewControllerAnimated(true, completion: nil)
        print("dismissing")
    }

    //Calls this function when the tap is recognized.
    func dismissKeyboard() {
        //Causes the view (or one of its embedded text fields) to resign the first responder status.
        view.endEditing(true)
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        self.view.endEditing(true)
    }
}

extension PayMerchantViewController {
    // MARK: Credit card modal
    
    func showCreditCardModal(sender: AnyObject) {
        let navigationController = self.storyboard!.instantiateViewControllerWithIdentifier("creditCardEntryModalNavigationController") as! UINavigationController
        let formSheetController = MZFormSheetPresentationViewController(contentViewController: navigationController)
        
        print("showing credit card modal")
        // Initialize and style the terms and conditions modal
        formSheetController.presentationController?.shouldApplyBackgroundBlurEffect = true
        formSheetController.presentationController?.contentViewSize = CGSizeMake(280, 280)
        formSheetController.presentationController?.shouldUseMotionEffect = true
        formSheetController.presentationController?.containerView?.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.5)
        formSheetController.presentationController?.containerView?.sizeToFit()
        formSheetController.presentationController?.blurEffectStyle = UIBlurEffectStyle.Dark
        formSheetController.presentationController?.shouldDismissOnBackgroundViewTap = true
        formSheetController.presentationController?.movementActionWhenKeyboardAppears = MZFormSheetActionWhenKeyboardAppears.AlwaysAboveKeyboard
        formSheetController.contentViewControllerTransitionStyle = MZFormSheetPresentationTransitionStyle.SlideFromBottom
        formSheetController.contentViewCornerRadius = 10
        formSheetController.allowDismissByPanningPresentedView = true
        formSheetController.interactivePanGestureDismissalDirection = .All;
        
        // Blur will be applied to all MZFormSheetPresentationControllers by default
        MZFormSheetPresentationController.appearance().shouldApplyBackgroundBlurEffect = true
        
        let presentedViewController = navigationController.viewControllers.first as! CreditCardEntryModalViewController
        
        // keep passing along user data to modal
        presentedViewController.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem()
        presentedViewController.navigationItem.leftItemsSupplementBackButton = true
        
        // send detail user information for delegated charge
        presentedViewController.detailUser = detailUser
        
        // send charge amount
        if(chargeInputView.text == "" || chargeInputView.text == "$0.00") {
            showGlobalNotification("Amount invalid", duration: 5.0, inStyle: CWNotificationAnimationStyle.Top, outStyle: CWNotificationAnimationStyle.Top, notificationStyle: CWNotificationStyle.StatusBarNotification, color: UIColor.brandRed())
        } else {
            var str = chargeInputView.text
            str?.removeAtIndex(str!.characters.indices.first!) // remove first letter
            let amount = (str! as NSString).floatValue
            presentedViewController.detailAmount = amount
            presentedViewController.paymentType = "once"
            presentedViewController.planId = ""
            
            // Be sure to update current module on storyboard
            self.presentViewController(formSheetController, animated: true, completion: nil)
        }
    }
}


extension PayMerchantViewController {
    // MARK: ACH modal
    
    func showACHModal(sender: AnyObject) {
        let navigationController = self.storyboard!.instantiateViewControllerWithIdentifier("bankListModalNavigationController") as! UINavigationController
        let formSheetController = MZFormSheetPresentationViewController(contentViewController: navigationController)
        
        print("showing ach modal")
        // Initialize and style the terms and conditions modal
        formSheetController.presentationController?.shouldApplyBackgroundBlurEffect = true
        formSheetController.presentationController?.contentViewSize = CGSizeMake(280, 400)
        formSheetController.presentationController?.shouldUseMotionEffect = true
        formSheetController.presentationController?.containerView?.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.5)
        formSheetController.presentationController?.containerView?.sizeToFit()
        formSheetController.presentationController?.blurEffectStyle = UIBlurEffectStyle.Dark
        formSheetController.presentationController?.shouldDismissOnBackgroundViewTap = true
        formSheetController.presentationController?.shouldCenterVertically = true
        formSheetController.presentationController?.shouldCenterHorizontally = true
        formSheetController.presentationController?.movementActionWhenKeyboardAppears = MZFormSheetActionWhenKeyboardAppears.CenterVertically
        formSheetController.contentViewControllerTransitionStyle = MZFormSheetPresentationTransitionStyle.SlideFromBottom
        formSheetController.contentViewCornerRadius = 10
        formSheetController.allowDismissByPanningPresentedView = true
        formSheetController.interactivePanGestureDismissalDirection = .All;
        
        // Blur will be applied to all MZFormSheetPresentationControllers by default
        MZFormSheetPresentationController.appearance().shouldApplyBackgroundBlurEffect = true
        
        let presentedViewController = navigationController.viewControllers.first as! BankListModalViewController
        
        // keep passing along user data to modal
        presentedViewController.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem()
        presentedViewController.navigationItem.leftItemsSupplementBackButton = true
        
        // send detail user information for delegated charge
        presentedViewController.detailUser = detailUser
        
        // send charge amount
        if(chargeInputView.text == "" || chargeInputView.text == "$0.00") {
            showGlobalNotification("Amount invalid", duration: 5.0, inStyle: CWNotificationAnimationStyle.Top, outStyle: CWNotificationAnimationStyle.Top, notificationStyle: CWNotificationStyle.StatusBarNotification, color: UIColor.brandRed())
        } else {
            var str = chargeInputView.text
            str?.removeAtIndex(str!.characters.indices.first!) // remove first letter
            let amount = (str! as NSString).floatValue
            presentedViewController.detailAmount = amount
            presentedViewController.paymentType = "once"
            presentedViewController.planId = ""
            // send an empty plan id as this is a onetime payment
            
            // Be sure to update current module on storyboard
            self.presentViewController(formSheetController, animated: true, completion: nil)
        }
    }
}