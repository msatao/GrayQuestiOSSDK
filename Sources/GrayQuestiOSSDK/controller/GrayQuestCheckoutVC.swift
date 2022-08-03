//
//  GrayQuestCheckoutVC.swift
//  
//
//  Created by admin on 02/08/22.
//

import UIKit
import WebKit

public class GrayQuestCheckoutVC: UIViewController, WKUIDelegate, WKScriptMessageHandler, WKNavigationDelegate, CheckoutControllerDelegate{
    var webView: WKWebView!
    var student: Student?
    var checkout_details: CheckoutDetails?
    
    var delegate: GQPaymentDelegate?
    
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
        guard let urlAsString = navigationAction.request.url?.absoluteString.lowercased() else {
            return
        }
        if (!urlAsString.contains("cashfree.com")) {return}
        print("URL as string \(urlAsString)")
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let newViewController = storyBoard.instantiateViewController(withIdentifier: "vcpayment") as! GrayQuestPaymentVC
        newViewController.paymentURL = urlAsString
        self.present(newViewController, animated: true, completion: nil)
     }

    func convertStringToDictionary(text: String) -> [String:AnyObject]? {
       if let data = text.data(using: .utf8) {
           do {
               let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String:AnyObject]
               return json
           } catch {
               print("Something went wrong")
           }
       }
       return nil
   }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if (message.name == "sdkSuccess") {
            print("sdkSuccess - \(message.body) \(type(of: message.body))")
            
        } else if (message.name == "sdkError") {
            print("sdkError - \(message.body)")
        } else if (message.name == "sdkCancel") {
            print("sdkCancel - \(message.body)")
            self.dismiss(animated: true, completion: nil)
        } else if (message.name == "sendADOptions") {
            print("sendADOptions - \(message.body)")
            let xyz = convertStringToDictionary(text: message.body as! String)
            let razorpay_key = xyz!["key"]
            let order_id = xyz!["order_id"]
            let callback_url = xyz!["callback_url"]
            let recurring = xyz!["recurring"]
            let notes = xyz!["notes"]
            let customer_id = xyz!["customer_id"]
            let recurring_flag: Bool?
            
            if (recurring as! String == "1") { recurring_flag = true }
            else { recurring_flag = false }
            
            checkout_details = CheckoutDetails(order_id: order_id as? String, razorpay_key: (razorpay_key as! String), recurring: recurring_flag, notes: (notes as? [String : Any]), customer_id: (customer_id as! String), callback_url: (callback_url as! String))
            
            let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
            let newViewController = storyBoard.instantiateViewController(withIdentifier: "vcrazorpay") as! CheckoutViewController
            newViewController.checkout_details = checkout_details
            newViewController.delegate = self
            self.present(newViewController, animated: true, completion: nil)
        }
        print("Received message from web -> \(message.body)")
    }
    
    public override func loadView() {
        let webConfiguration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.configuration.userContentController.add(self, name: "Gqsdk")
        webView.configuration.userContentController.add(self, name: "sdkSuccess")
        webView.configuration.userContentController.add(self, name: "sdkError")
        webView.configuration.userContentController.add(self, name: "sdkCancel")
        webView.configuration.userContentController.add(self, name: "sendADOptions")
        
        webView.uiDelegate = self
        webView.navigationDelegate = self
        view = webView
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        
        initialSetup()
        let response1 = validation1()
        if (response1["error"] == "false") {
            customer()
        } else {
            print("Error Validation 1 -> \(response1["message"] ?? "Hello Error")")
        }
    }
    
    func checkoutControllerSuccessResponse(data: [AnyHashable : Any]?) {
        var userInfo = data as NSDictionary? as? [String: String]
        userInfo?["callback_url"] = checkout_details?.callback_url
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: userInfo ?? [], options: [])
            let jsonString = String(data: jsonData, encoding: .utf8)
            webView.evaluateJavaScript("javascript:sendADPaymentResponse(\(jsonString!));")
        } catch {
            print("Error in checkoutControllerSuccessResponse => \(error)")
        }
    }
    
    func checkoutControllerFailureResponse(data: [AnyHashable : Any]?) {
        var userInfo = data as NSDictionary? as? [String: String]
        userInfo?["callback_url"] = checkout_details?.callback_url
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: userInfo ?? [], options: [])
            let jsonString = String(data: jsonData, encoding: .utf8)
            webView.evaluateJavaScript("javascript:sendADPaymentResponse(\(jsonString!));")
        } catch {
            print("Error in checkoutControllerFailureResponse => \(error)")
        }
    }
    
    public override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "vcrazorpay"{
            print("Hello World3")
        }
    }
    
    public func initialSetup() {
        student = Student()
        student?.studentId = "std_1212"
        student?.customerMobile = "8425960199"
        student?.feeAmount = "80000"
        student?.payableAmount = "5000"
        student?.env = "test"
        student?.feeEditable = "false"
        student?.customerId = "25417"
        student?.userType = "existing"
    }
    
    public func validation1() -> [String: String] {
        var errorMessage = ""
        
        if (student?.studentId == nil) {
            errorMessage += "Student ID cannot be null\n"
        }
        
        if (student?.feeEditable == nil) {
            errorMessage += "Fee Editable value not set\n"
        }
        
        if (student?.env == nil) {
            errorMessage += ""
        }
        
        if (errorMessage != "") {
            return ["error": "true", "message": errorMessage]
        }
        
        return ["error": "false", "message": "Validation Successful"]
    }
    
    public func customer() {
        Customer().makeCustomerRequest(mobile: "9988779988") { responseObject, error in
            guard let responseObject = responseObject, error == nil else {
                print(error ?? "Unknown error")
                return
            }
            
            DispatchQueue.main.async {
                let message = responseObject["message"] as! String
                if (message == "Customer Exists") {
                    self.student?.userType = "existing"
                } else {
                    self.student?.userType = "new"
                }
                
                let data = responseObject["data"] as! [String:AnyObject]
                self.student?.customerCode = (data["customer_code"] as! String)
                self.student?.customerMobile = (data["customer_mobile"] as! String)
                self.student?.customerId = "\(data["customer_id"] as! Int)"
                
                self.elegibity()
            }

        }
    }
    
    public func elegibity() {
        let urlStr = "\(StaticConfig.checkElegibility)?gapik=\(StaticConfig.gqAPIKey)&abase=\(StaticConfig.aBase)&sid=\(student?.studentId! ?? "")&m=\(student?.customerMobile! ?? "")&famt=\(student?.feeAmount! ?? "")&pamt=\(student?.payableAmount! ?? "")&env=\(student?.env! ?? "")&fedit=\(student?.feeEditable! ?? "")&cid=\(student?.customerId! ?? "")&ccode=\(student?.customerCode! ?? "")&pc=&s=asdk&user=\(student?.userType! ?? "")"
        print("urlStr -> \(urlStr)")
        let url = URL(string: urlStr)
        let request = URLRequest(url: url!)
        webView.load(request)
    }
}

extension WKWebView {
    func evaluate(script: String, completion: @escaping (Any?, Error?) -> Void) {
        var finished = false

        print("Hello world")
        evaluateJavaScript(script, completionHandler: { (result, error) in
            if error == nil {
                if result != nil {
                    completion(result, nil)
                }
            } else {
                completion(nil, error)
            }
            finished = true
        })

        while !finished {
            RunLoop.current.run(mode: RunLoop.Mode(rawValue: "NSDefaultRunLoopMode"), before: NSDate.distantFuture)
        }
    }
}
