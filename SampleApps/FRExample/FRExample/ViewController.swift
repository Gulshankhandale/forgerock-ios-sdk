//
//  ViewController.swift
//  FRExample
//
//  Copyright (c) 2019-2021 ForgeRock. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import UIKit
import FRAuth
import FRCore
import FRUI
import CoreLocation
import QuartzCore

class ViewController: UIViewController {

    // MARK: - Properties
    @IBOutlet weak var loggingView: UITextView?
    @IBOutlet weak var commandField: UIButton?
    @IBOutlet weak var performActionBtn: FRButton?
    @IBOutlet weak var clearLogBtn: FRButton?
    @IBOutlet weak var dropDown: FRDropDownButton?
    @IBOutlet weak var invokeBtn: FRButton?
    @IBOutlet weak var urlField: FRTextField?
    
    var selectedIndex: Int = 0
    var primaryColor: UIColor
    var textColor: UIColor
    var invoke401: Bool = false
    var urlSession: URLSession = URLSession.shared
    var loadingView: FRLoadingView = FRLoadingView(size: CGSize(width: 120, height: 120), showDropShadow: true, showDimmedBackground: true, loadingText: "Loading...")
    
    // MARK: - UIViewController Lifecycle
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        
        // Alter FRAuth configuration file from Info.plist
        if let configFileName = Bundle.main.object(forInfoDictionaryKey: "FRConfigFileName") as? String {
            FRAuth.configPlistFileName = configFileName
        }
        
        // Apply different styles for SSO application
        if let isSSOApp = Bundle.main.object(forInfoDictionaryKey: "FRExampleSSOApp") as? Bool, isSSOApp {
            self.primaryColor = UIColor.hexStringToUIColor(hex: "#495661")
            self.textColor = UIColor.white
        }
        else {
            self.primaryColor = UIColor.hexStringToUIColor(hex: "#519387")
            self.textColor = UIColor.white
        }
        
        let navigationBarAppearace = UINavigationBar.appearance()
        navigationBarAppearace.tintColor = self.primaryColor
        navigationBarAppearace.barTintColor = self.primaryColor
        navigationBarAppearace.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        
        // Alter FRAuth configuration file from Info.plist
        if let configFileName = Bundle.main.object(forInfoDictionaryKey: "FRConfigFileName") as? String {
            FRAuth.configPlistFileName = configFileName
        }
        
        // Apply different styles for SSO application
        if let isSSOApp = Bundle.main.object(forInfoDictionaryKey: "FRExampleSSOApp") as? Bool, isSSOApp {
            self.primaryColor = UIColor.hexStringToUIColor(hex: "#495661")
            self.textColor = UIColor.white
        }
        else {
            self.primaryColor = UIColor.hexStringToUIColor(hex: "#519387")
            self.textColor = UIColor.white
        }
        
        let navigationBarAppearace = UINavigationBar.appearance()
        navigationBarAppearace.tintColor = self.primaryColor
        navigationBarAppearace.barTintColor = self.primaryColor
        navigationBarAppearace.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        
        super.init(coder: aDecoder)
        self.navigationController?.navigationBar.tintColor = self.primaryColor
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String {
            self.title = bundleName
        }
        else {
            self.title = "FRExample"
        }
        
        if #available(iOS 13.0, *) {
            self.view.backgroundColor = UIColor(named: "BackgroundColor")
        }
        else {
            self.view.backgroundColor = .white
        }
        
        // Setup loading view
        loadingView.add(inView: self.view)
        
        // Styling
        self.performActionBtn?.backgroundColor = self.primaryColor
        self.performActionBtn?.tintColor = self.textColor
        self.invokeBtn?.backgroundColor = self.primaryColor
        self.invokeBtn?.tintColor = self.textColor
        
        self.urlField?.tintColor = self.primaryColor
        self.urlField?.normalColor = self.primaryColor
        
        self.clearLogBtn?.backgroundColor = UIColor.hexStringToUIColor(hex: "#DC143C")
        self.clearLogBtn?.titleColor = UIColor.white

        self.commandField?.setTitleColor(self.primaryColor, for: .normal)
        self.commandField?.setTitleColor(self.primaryColor, for: .selected)
        self.commandField?.setTitleColor(self.primaryColor, for: .highlighted)
        
        // DropDown set-up
        self.dropDown?.themeColor = self.primaryColor
        self.dropDown?.maxHeight = 500
        self.dropDown?.delegate = self
        self.dropDown?.dataSource = [
            "Login with UI (FRUser)",
            "Login with Browser",
            "Request UserInfo",
            "User Logout",
            "Get FRUser.currentUser",
            "Invoke API (Token Mgmt)",
            "Collect Device Information",
            "JailbreakDetector.analyze()",
            "FRUser.getAccessToken()",
            "Login with UI (Accesstoken)",
            "FRSession.authenticate with UI (Token)",
            "FRSession.logout()",
            "Register User with UI (FRUser)",
            "Register User with UI (Accesstoken)",
            "Login without UI (FRUser)",
            "Login without UI (Accesstoken)",
            "FRSession.authenticate without UI (Token)",
            "Display Configurations",
            "Revoke Access Token",
            "Load Custom Config1",
            "Load Custom Config2",
            "Display current config"
        ]
        self.commandField?.setTitle("Login with UI (FRUser)", for: .normal)
        
        // - MARK: Token Management - Example
        // Register FRURLProtocol
        URLProtocol.registerClass(FRURLProtocol.self)
        let policy = TokenManagementPolicy(validatingURL: [URL(string: "http://openig.example.com:9999/products.php")!, URL(string: "http://localhost:9888/policy/transfer")!, URL(string: "https://httpbin.org/status/401")!, URL(string: "https://httpbin.org/anything")!], delegate: self)
        FRURLProtocol.tokenManagementPolicy = policy
        
        //  - MARK: Authorization Policy - Example
        let authPolicy = AuthorizationPolicy(validatingURL: [URL(string: "http://localhost:9888/policy/transfer")!], delegate: self)
        FRURLProtocol.authorizationPolicy = authPolicy
        
        // Configure FRURLProtocol for HTTP client
        let config = URLSessionConfiguration.default
        config.protocolClasses = [FRURLProtocol.self]
        self.urlSession = URLSession(configuration: config)
        
        //  - MARK: FRUI Customize Cell example
        // Comment out below code to demonstrate FRUI customization
//        CallbackTableViewCellFactory.shared.registerCallbackTableViewCell(callbackType: "NameCallback", cellClass: CustomNameCallbackCell.self, nibName: "CustomNameCallbackCell")
        
        
        //  - MARK: RequestInterceptor example
        
        //  By commenting out below code, it registers 'ForceAuthIntercetpr' class into FRCore and FRAuth's RequestInterceptor which then allows developers to customize requests being made by ForgeRock SDK, and modify as needed
        // FRRequestInterceptorRegistry.shared.registerInterceptors(interceptors: [ForceAuthInterceptor()])
        
        /*
        //  - MARK: URLSessionConfiguration && SSL Pinning example
         // Create URLSessionConfiguration & Subclass the FRURLSessionHandler class
         // override func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
         // override func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
         // And provide your custom pinning implementation
         // set the Configuration and the Handler using the
         // RestClient.shared.setURLSessionConfiguration(config: URLSessionConfiguration?, handler: FRURLSessionHandlerProtocol?) method.
        let customConfig = URLSessionConfiguration()
        customConfig.timeoutIntervalForRequest = 90
        let customPinner = CustomPin(frSecurityConfiguration: FRSecurityConfiguration(hashes: [Public Key Hashes]))
        RestClient.shared.setURLSessionConfiguration(config: customConfig, handler: customPinner)
         
        */
        
        // Start SDK
        do {
            try FRAuth.start()
            self.displayLog("FRAuth SDK started using \(FRAuth.configPlistFileName).plist.")
        }
        catch {
            self.displayLog(String(describing: error))
        }
    }
    
    
    // MARK: - Helper: Loading
    func startLoading() {
        self.loadingView.startLoading()
    }
    
    func stopLoading() {
        self.loadingView.stopLoading()
    }
    
    
    // MARK: - Helper: Handle Node object and result
    
    func handleNode<T>(_ result: T?, _ node: Node?, _ error: Error?) {
        
        if let token = result as? Token {
            self.displayLog("Token(s) received: \n\(token.debugDescription)")
        }
        else if let token = result as? AccessToken {
            self.displayLog("AccessToken(s) received: \n\(token.debugDescription)")
        }
        else if let user = result as? FRUser {
            self.displayLog("FRUser received: \n\(user.debugDescription)")
        }
        else if let node = node {
            // TODO: Currently only supports NameCallback / PasswordCallback / ChoiceCallback; any additional callback type can be added in the future
            DispatchQueue.main.async {
                
                let title = "FRAuth"
                
                let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
                
                for callback:Callback in node.callbacks {
                    
                    if callback.type == "NameCallback", let nameCallback = callback as? NameCallback {
                        
                        alert.addTextField(configurationHandler: { (textField) in
                            textField.placeholder = nameCallback.prompt
                            textField.autocorrectionType = .no
                            textField.autocapitalizationType = .none
                        })
                    }
                    else if callback.type == "PasswordCallback", let passwordCallback = callback as? PasswordCallback {
                        alert.addTextField(configurationHandler: { (textField) in
                            textField.placeholder = passwordCallback.prompt
                            textField.isSecureTextEntry = true
                            textField.autocorrectionType = .no
                            textField.autocapitalizationType = .none
                        })
                    }
                    else if callback.type == "ChoiceCallback", let choiceCallback = callback as? ChoiceCallback {
                        
                        var descriptionText = "Enter the int value: "
                        
                        for (index, choice) in choiceCallback.choices.enumerated() {
                            var leadingStr = ""
                            if index > 0 {
                                leadingStr = " ,"
                            }
                            
                            descriptionText = descriptionText + leadingStr + choice + "=" + String(index)
                        }
                        
                        alert.title = descriptionText
                        
                        alert.addTextField(configurationHandler: { (textField) in
                            textField.placeholder = choiceCallback.prompt
                            textField.autocorrectionType = .no
                            textField.autocapitalizationType = .none
                        })
                    }
                    else {
                        let errorAlert = UIAlertController(title: "Invalid Callback", message: "\(callback.type) is not supported.", preferredStyle: .alert)
                        let cancelAction = UIAlertAction(title: "Ok", style: .cancel, handler:nil)
                        errorAlert.addAction(cancelAction)
                        self.present(errorAlert, animated: true, completion: nil)
                        break
                    }
                }
                
                let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
                })
                
                let submitAction = UIAlertAction(title: "Submit", style: .default, handler: { (_) in
                    
                    var counter = 0
                    for textField in alert.textFields! {
                        
                        let thisCallback:SingleValueCallback = node.callbacks[counter] as! SingleValueCallback
                        thisCallback.setValue(textField.text)
                        counter += 1
                    }
                    
                    if T.self as AnyObject? === AccessToken.self {
                        node.next(completion: { (token: AccessToken?, node, error) in
                            self.handleNode(token, node, error)
                        })
                    }
                    else if T.self as AnyObject? === Token.self {
                        node.next(completion: { (token: Token?, node, error) in
                            self.handleNode(token, node, error)
                        })
                    }
                    else if T.self as AnyObject? === FRUser.self {
                        node.next(completion: { (user: FRUser?, node, error) in
                            self.handleNode(user, node, error)
                        })
                    }
                })
                
                alert.addAction(cancelAction)
                alert.addAction(submitAction)
                
                self.present(alert, animated: true, completion: nil)
            }
        }
        else if let error = error {
            self.displayLog("\(String(describing: error))")
        }
        else {
            self.displayLog("Authentication Tree flow was successful; no result returned")
        }
    }
    
    
    // MARK: - Helper: User Login/Registration
    
    func performActionHelperWithUI<T>(auth: FRAuth, flowType: FRAuthFlowType, expectedType: T) {
        
        if expectedType as AnyObject? === AccessToken.self {
            if flowType == .authentication {
                FRUser.authenticateWithUI(self, completion: { (token: AccessToken?, error) in
                    if let error = error {
                        self.displayLog(error.localizedDescription)
                    }
                    else if let token = token {
                        self.displayLog(token.debugDescription)
                    }
                    else {
                        self.displayLog("Authentication Tree flow was successful; no result returned")
                    }
                })
            }
            else {
                FRUser.registerWithUI(self, completion: { (token: AccessToken?, error) in
                    if let error = error {
                        self.displayLog(error.localizedDescription)
                    }
                    else if let token = token {
                        self.displayLog(token.debugDescription)
                    }
                    else {
                        self.displayLog("Authentication Tree flow was successful; no result returned")
                    }
                })
            }
        }
        else if expectedType as AnyObject? === Token.self {
            if flowType == .authentication {
                FRUser.authenticateWithUI(self, completion: { (token: Token?, error) in
                    if let error = error {
                        self.displayLog(error.localizedDescription)
                    }
                    else if let token = token {
                        self.displayLog(token.debugDescription)
                    }
                    else {
                        self.displayLog("Authentication Tree flow was successful; no result returned")
                    }
                })
            }
            else {
                FRUser.registerWithUI(self, completion: { (token: Token?, error) in
                    if let error = error {
                        self.displayLog(error.localizedDescription)
                    }
                    else if let token = token {
                        self.displayLog(token.debugDescription)
                    }
                    else {
                        self.displayLog("Authentication Tree flow was successful; no result returned")
                    }
                })
            }
        }
        else if expectedType as AnyObject? === FRUser.self {
            if flowType == .authentication {
                FRUser.authenticateWithUI(self, completion: { (user: FRUser?, error) in
                    if let error = error {
                        self.displayLog(error.localizedDescription)
                    }
                    else if let user = user {
                        self.displayLog(user.debugDescription)
                    }
                    else {
                        self.displayLog("Authentication Tree flow was successful; no result returned")
                    }
                })
            }
            else {
                FRUser.registerWithUI(self, completion: { (user: FRUser?, error) in
                    if let error = error {
                        self.displayLog(error.localizedDescription)
                    }
                    else if let user = user {
                        self.displayLog(user.debugDescription)
                    }
                    else {
                        self.displayLog("Authentication Tree flow was successful; no result returned")
                    }
                })
            }
        }
    }
    
    func performActionHelper<T>(auth: FRAuth, flowType: FRAuthFlowType, expectedType: T) {
        
        if expectedType as AnyObject? === FRUser.self {
            let completionBlock: NodeCompletion = {(user: FRUser?, node, error) in
               
               DispatchQueue.main.async {
                   self.stopLoading()
                   self.handleNode(user, node, error)
               }
           }
            
            if flowType == .registration {
                FRUser.register(completion: completionBlock)
            }
            else {
                FRUser.login(completion: completionBlock)
            }
        }
        else if expectedType as AnyObject? === AccessToken.self {
            let completionBlock: NodeCompletion = {(user: FRUser?, node, error) in
                DispatchQueue.main.async {
                    self.stopLoading()
                    self.handleNode(user?.token, node, error)
                }
            }
            
            if flowType == .registration {
                FRUser.register(completion: completionBlock)
            }
            else {
                FRUser.login(completion: completionBlock)
            }
        }
    }
    
    func performSessionAuthenticate(handleWithUI: Bool) {

        let alert = UIAlertController(title: "FRSession Authenticate", message: nil, preferredStyle: .alert)
        alert.addTextField(configurationHandler: { (textField) in
            textField.placeholder = "Enter authIndex (tree name) value"
            textField.autocorrectionType = .no
            textField.autocapitalizationType = .none
        })
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let submitAction = UIAlertAction(title: "Continue", style: .default, handler: { (_) in
             
            if let authIndexValue = alert.textFields?.first?.text {
                
                if handleWithUI {
                    FRSession.authenticateWithUI(authIndexValue, "service", self) { (token: Token?, error) in
                        
                        if let error = error {
                            self.displayLog(error.localizedDescription)
                        }
                        else if let token = token {
                            self.displayLog(token.debugDescription)
                        }
                        else {
                            self.displayLog("Authentication Tree flow was successful; no result returned")
                        }
                    }
                }
                else {
                    FRSession.authenticate(authIndexValue: authIndexValue) { (token: Token?, node, error) in
                        DispatchQueue.main.async {
                            self.handleNode(token, node, error)
                        }
                    }
                }
            }
            else {
                self.displayLog("Invalid authIndexValue.")
            }
        });
        
        alert.addAction(cancelAction)
        alert.addAction(submitAction)
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func getAccessTokenFromUser() {
        guard let user = FRUser.currentUser else {
            // If no currently authenticated user is found, log error
            self.displayLog("FRUser.currentUser does not exist")
            return
        }
        
        user.getAccessToken { (user, error) in
            if let error = error {
                self.displayLog("Error while getting AccessToken: \(String(describing: error))")
            }
            else {
                self.displayLog("\(String(describing: FRUser.currentUser))")
            }
        }
    }
    
    
    // MARK: - Helper: Logout / UserInfo / JailbreakDetector / Device Collector / Invoke API
    
    func getDeviceInformation() {
        guard let _ = FRDevice.currentDevice else {
            // If SDK is not initialized, then don't perform
            self.displayLog("FRDevice.currentDevice does not exist")
            return
        }
        
        FRDeviceCollector.shared.collect { (result) in
            self.displayLog("\(result)")
        }
    }
    

    func performCentralizedLogin() {
        FRUser.browser()?
            .set(presentingViewController: self)
            .set(browserType: .authSession)
            .setCustomParam(key: "custom", value: "value")
            .build().login { (user, error) in
                self.displayLog("User: \(String(describing: user)) || Error: \(String(describing: error))")
        }
        return
        
    }
    
    func getUserInfo() {
        
        guard let user = FRUser.currentUser else {
            // If no currently authenticated user is found, log error
            self.displayLog("FRUser.currentUser does not exist")
            return
        }

        // If FRUser.currentUser exists, perform getUserInfo
        user.getUserInfo { (userInfo, error) in
            if let error = error {
                self.displayLog(String(describing: error))
            }
            else if let _ = userInfo {
                self.displayLog(userInfo.debugDescription)
            }
            else {
                self.displayLog("Invalid state: UserInfo returns no result")
            }
        }
    }
    
    
    func logout() {
        guard let user = FRUser.currentUser else {
            // If no currently authenticated user is found, log error
            self.displayLog("FRUser.currentUser does not exist")
            return
        }
        
        // If FRUser.currentUser exists, perform logout
        user.logout()
        self.displayLog("Logout completed")
    }
    
    func revokeAccessToken() {
        FRUser.currentUser?.revokeAccessToken(completion: { (user, error) in
            if let tokenError = error {
                self.displayLog(tokenError.localizedDescription)
            } else {
                self.displayLog("Access token revoked")
                self.displayLog("\(String(describing: user))")
            }
        })
    }
    
    
    func performJailbreakDetector() {
        let result = FRJailbreakDetector.shared.analyze()
        self.displayLog("JailbreakDetector: \(String(describing: result))")
    }
    
    
    func invokeAPI() {
        
        if self.invoke401 {
            self.invoke401 = false
            
            // Invoke API
            self.urlSession.dataTask(with: URL(string: "https://httpbin.org/status/401")!) { (data, response, error) in
                guard let responseData = data, let httpresponse = response as? HTTPURLResponse, error == nil else {
                    self.displayLog("Invoking API failed as expected")
                    return
                }
                
                let responseStr = String(decoding: responseData, as: UTF8.self)
                self.displayLog("Response Data: \(responseStr)")
                self.displayLog("Response Header: \n\(httpresponse.allHeaderFields)")
            }.resume()
        }
        else {
            self.invoke401 = true
            
            // Invoke API
            self.urlSession.dataTask(with: URL(string: "https://httpbin.org/anything")!) { (data, response, error) in
                guard let responseData = data, let httpresponse = response as? HTTPURLResponse, error == nil else {
                    self.displayLog("Invoking API failed with unexpected result")
                    return
                }
                
                let responseStr = String(decoding: responseData, as: UTF8.self)
                self.displayLog("Response Data: \(responseStr)")
                self.displayLog("Response Header: \n\(httpresponse.allHeaderFields)")
            }.resume()
        }
    }
    
    
    // MARK: - Helper: Log
    
    func displayLog(_ text: String) {
        DispatchQueue.main.async {
            guard let textView = self.loggingView else {
                return
            }
            self.loggingView?.text = textView.text + "\(text)\n"
        }
    }
    
    
    func displayCurrentConfig() {
        guard let path = Bundle.main.path(forResource: FRAuth.configPlistFileName, ofType: "plist"),
            let config = NSDictionary(contentsOfFile: path) as? [String: Any]  else {
                self.displayLog("No configuration found (config plist file name: \(FRAuth.configPlistFileName)")
                return
        }
        
        self.displayLog("Current Configuration (\(FRAuth.configPlistFileName).plist): \(config)")
    }
    
    
    // MARK: - IBAction
    
    @IBAction func invokeAPIButton(sender: UIButton) {
        
        guard let urlStr = urlField?.text, let url = URL(string: urlStr) else {
            return
        }
        
        //  Default Cookie Name for SSO Token in AM
        var cookieName = "iPlanetDirectoryPro"
        
        //  If custom cookie name is defined in configuration file, update the cookie name
        if let path = Bundle.main.path(forResource: FRAuth.configPlistFileName, ofType: "plist"), let config = NSDictionary(contentsOfFile: path) as? [String: Any], let configCookieName = config["forgerock_cookie_name"] as? String {
            cookieName = configCookieName
        }
        
        var request = URLRequest(url: url)
        
        //  TODO: - Change following code as needed for authorization policy, and PEP
        //  Setting SSO Token in the request cookie is expected for Identity Gateway set-up, and where IG is acting as Policy Enforcement Points (PEP)
        request.setValue("\(cookieName)="+(FRSession.currentSession?.sessionToken?.value ?? ""), forHTTPHeaderField: "Cookie")
        //  If custom web application is acting as PEP, and expecting user's authenticated session in other form (such as in URL query param, or request body), set the given SSO Token accordingly
        //  Below line of code is for an agent expecting SSO Token in the header of request with header name being "SSOToken"
        request.setValue((FRSession.currentSession?.sessionToken?.value ?? ""), forHTTPHeaderField: "SSOToken")
        self.urlSession.dataTask(with: request) { (data, response, error) in
            guard let responseData = data, let httpresponse = response as? HTTPURLResponse, error == nil else {
                self.displayLog("Invoking API failed\n\nError: \(String(describing: error))")
                return
            }

            let responseStr = String(decoding: responseData, as: UTF8.self)
            self.displayLog("Response Data: \(responseStr)")
            self.displayLog("Response Header: \n\(httpresponse.allHeaderFields)")
            FRLog.i("Response Data: \(responseStr)")
            FRLog.i("Response Header: \n\(httpresponse.allHeaderFields)")
        }.resume()
    }
    
    
    @IBAction func clearLogBtnClicked(sender: UIButton) {
        DispatchQueue.main.async {
            self.loggingView?.text = ""
        }
    }
    
    
    @IBAction func performAction(sender: UIButton) {
        guard let frAuth = FRAuth.shared else {
            self.displayLog("Invalid SDK State")
            return
        }
        
        switch self.selectedIndex {
        case 0:
            // Login for FRUser
            self.performActionHelperWithUI(auth: frAuth, flowType: .authentication, expectedType: FRUser.self)
            break
        case 1:
            self.performCentralizedLogin()
            break
        case 2:
            // Request user info
            self.getUserInfo()
            break
        case 3:
            // User Logout
            self.logout()
            break
        case 4:
            // Display FRUser.currentUser
            self.displayLog(String(describing: FRUser.currentUser))
            break
        case 5:
            // Invoke API
            self.invokeAPI()
            break
        case 6:
            // Device Information collector
            self.getDeviceInformation()
            break
        case 7:
            // Jailbreak detector
            self.performJailbreakDetector()
            break
        case 8:
            // Get AccessToken from FRUser.currentUser
            self.getAccessTokenFromUser()
            break
        case 9:
            // Login for AccessToken
            self.performActionHelperWithUI(auth: frAuth, flowType: .authentication, expectedType: AccessToken.self)
            break
        case 10:
            // FRSession.authenticate with UI (Token)
            self.performSessionAuthenticate(handleWithUI: true)
            break
        case 11:
            // FRSession.logout
            FRSession.currentSession?.logout()
            break
        case 12:
            // Register a user for FRUser
            self.performActionHelperWithUI(auth: frAuth, flowType: .registration, expectedType: FRUser.self)
            break
        case 13:
            // Register a user for AccessToken
            self.performActionHelperWithUI(auth: frAuth, flowType: .registration, expectedType: AccessToken.self)
            break
        case 14:
            // Login for FRUser without UI
            self.performActionHelper(auth: frAuth, flowType: .authentication, expectedType: FRUser.self)
            break
        case 15:
            // Login for AccessToken without UI
            self.performActionHelper(auth: frAuth, flowType: .authentication, expectedType: AccessToken.self)
            break
        case 16:
            // FRSession.authenticate without UI (Token)
            self.performSessionAuthenticate(handleWithUI: false)
            break
        case 17:
            // Display current Configuration
            self.displayCurrentConfig()
            break
        case 18:
            // Revoke Access Token
            self.revokeAccessToken()
            break
        case 19:
            // Load Custom Config1
            self.loadCustomConfig1()
            break
        case 20:
            // Load Custom Config2
            self.loadCustomConfig2()
            break
        case 21:
            // Display current config
            self.displayConfig()
            break
        default:
            break
        }
    }
}


extension ViewController: FRDropDownViewProtocol {
    func selectedItem(index: Int, item: String) {
        self.selectedIndex = index
    }
}

extension UIColor {
    static func hexStringToUIColor (hex:String) -> UIColor {
        var cString:String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if (cString.hasPrefix("#")) {
            cString.remove(at: cString.startIndex)
        }
        
        if ((cString.count) != 6) {
            return UIColor.gray
        }
        
        var rgbValue:UInt32 = 0
        Scanner(string: cString).scanHexInt32(&rgbValue)
        
        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
}


//  - MARK: TokenManagementPolicy example
extension ViewController: TokenManagementPolicyDelegate {
    func evaluateTokenRefresh(responseData: Data?, response: URLResponse?, error: Error?) -> Bool {
        var shouldHandle = false
        // refresh token policy will only be enforced when HTTP status code is equal to 401 in this case
        // Developers can define their own policy based on response data, URLResponse, and/or error from the request
        if let thisResponse = response as? HTTPURLResponse, thisResponse.statusCode == 401 {
         
            shouldHandle = true
        }
        return shouldHandle
    }
}

//  - MARK: AuthorizationPolicy example
extension ViewController: AuthorizationPolicyDelegate {
    func onPolicyAdviseReceived(policyAdvice: PolicyAdvice, completion: @escaping FRCompletionResultCallback) {
        DispatchQueue.main.async {
            FRSession.authenticateWithUI(policyAdvice, self) { (token: Token?, error) in
                if let _ = token, error == nil {
                    completion(true)
                }
                else {
                    completion(false)
                }
            }
        }
    }
    
//    func evaluateAuthorizationPolicy(responseData: Data?, response: URLResponse?, error: Error?) -> PolicyAdvice? {
//        // Example to evaluate given response data, and constructs PolicyAdvice object
//        // Following code expects JSON response payload with 'advice' attribute in JSON which contains an array of 'advice' response from AM
//        if let data = responseData, let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
//            if let advice = json["advice"], let adviceData = advice.data(using: .utf8), let adviceJSON = try? JSONSerialization.jsonObject(with: adviceData, options: []) as? [[String: Any]], let evalResult = adviceJSON.first, let policyAdvice = PolicyAdvice(json: evalResult) {
//                return policyAdvice
//            }
//        }
//        return nil
//    }
    
//    func updateRequest(originalRequest: URLRequest, txId: String?) -> URLRequest {
//        let mutableRequest = ((originalRequest as NSURLRequest).mutableCopy() as? NSMutableURLRequest)!
//        // Appends given transactionId into header
//        mutableRequest.setValue(txId, forHTTPHeaderField: "transactionId")
//        return mutableRequest as URLRequest
//    }
    
    func loadCustomConfig1() {
        do {
            let options = FROptions(url: "https://openam-forgerrock-sdksteanant.forgeblocks.com/am",
                                    realm: "alpha",
                                    enableCookie: true,
                                    cookieName: "43d72fc37bdde8c",
                                    timeout: "180",
                                    authenticateEndpoint: "/json/authenticate",
                                    authorizeEndpoint: "/oauth2/authorize",
                                    tokenEndpoint: "/oauth2/access_token",
                                    revokeEndpoint: "/oauth2/token/revoke",
                                    userinfoEndpoint: "/oauth2/userinfo",
                                    endSessionEndpoint: "/oauth2/connect/endSession",
                                    authServiceName: "Login",
                                    oauthThreshold: "60",
                                    oauthClientId: "iosclient",
                                    oauthRedirectUri: "frauth://oauth2redirect",
                                    oauthScope: "openid profile email address",
                                    keychainAccessGroup: "com.forgerock.sso"
                                    )

        try FRAuth.start(options: options)
            self.displayLog("FRAuth SDK started using config1.")

        }
        catch {
            print(error)
        }
    }
    
    func loadCustomConfig2() {
        do {
            let options = FROptions(url: "https://openam-forgerrock-sdksteanant.forgeblocks.com/am",
                                    realm: "alpha",
                                    enableCookie: true,
                                    cookieName: "43d72fc37bdde8c",
                                    timeout: "180",
                                    authenticateEndpoint: "/json/authenticate",
                                    authorizeEndpoint: "/oauth2/authorize",
                                    tokenEndpoint: "/oauth2/access_token",
                                    revokeEndpoint: "/oauth2/token/revoke",
                                    userinfoEndpoint: "/oauth2/userinfo",
                                    endSessionEndpoint: "/oauth2/connect/endSession",
                                    authServiceName: "Login",
                                    oauthThreshold: "60",
                                    oauthClientId: "iosclient",
                                    oauthRedirectUri: "frauth://oauth2redirect",
                                    oauthScope: "openid profile email",
                                    keychainAccessGroup: "com.forgerock.sso"
                                    )

        try FRAuth.start(options: options)
        self.displayLog("FRAuth SDK started using config2.")

        }
        catch {
            print(error)
        }
    }

    func displayConfig() {
        // Server
        self.displayLog("forgerock_url: " + (FRAuth.shared?.options?.url ?? "nil"))
        self.displayLog("forgerock_realm: " + (FRAuth.shared?.options?.realm ?? "nil"))
        self.displayLog("forgerock_timeout: " + (FRAuth.shared?.options?.timeout ?? "nil"))
        self.displayLog("forgerock_cookie_name: " + (FRAuth.shared?.options?.cookieName ?? "nil"))
        self.displayLog("forgerock_enable_cookie: " + (FRAuth.shared?.options?.enableCookie.description ?? "nil"))
        self.displayLog("forgerock_ssl_pinning_public_key_hashes: " + (FRAuth.shared?.options?.sslPinningPublicKeyHashes?.description ?? "nil"))

        // OAuth
        self.displayLog("forgerock_oauth_client_id: " + (FRAuth.shared?.options?.oauthClientId ?? "nil"))
        self.displayLog("forgerock_oauth_redirect_uri: " + (FRAuth.shared?.options?.oauthRedirectUri ?? "nil"))
        self.displayLog("forgerock_oauth_scope: " + (FRAuth.shared?.options?.oauthScope ?? "nil"))
        self.displayLog("forgerock_oauth_threshold: " + (FRAuth.shared?.options?.oauthThreshold ?? "nil"))

        // Service
        self.displayLog("forgerock_auth_service: " + (FRAuth.shared?.options?.authServiceName ?? "nil"))
        self.displayLog("forgerock_registration_service: " + (FRAuth.shared?.options?.registrationServiceName ?? "nil"))

        // Path
        self.displayLog("forgerock_authenticate_endpoint: " + (FRAuth.shared?.options?.getAuthenticateEndpoint() ?? "nil"))
        self.displayLog("forgerock_authorize_endpoint: " + (FRAuth.shared?.options?.getAuthorizeEndpoint() ?? "nil"))
        self.displayLog("forgerock_token_endpoint: " + (FRAuth.shared?.options?.getTokenEndpoint() ?? "nil"))
        self.displayLog("forgerock_revoke_endpoint: " + (FRAuth.shared?.options?.getRevokeEndpoint() ?? "nil"))
        self.displayLog("forgerock_userinfo_endpoint: " + (FRAuth.shared?.options?.getUserinfoEndpoint() ?? "nil"))
        self.displayLog("forgerock_logout_endpoint: " + (FRAuth.shared?.options?.getSessionEndpoint() ?? "nil"))
        self.displayLog("forgerock_endsession_endpoint: " + (FRAuth.shared?.options?.getEndSessionEndpoint() ?? "nil"))

        // Other
        self.displayLog("keychainAccessGroup: " + (FRAuth.shared?.options?.keychainAccessGroup ?? "nil"))
    }
}


