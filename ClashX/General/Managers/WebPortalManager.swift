//
//  WebPortalManager.swift
//  ClashX
//
//  Created by CYC on 2019/1/11.
//  Copyright © 2019 west2online. All rights reserved.
//

import Cocoa
import Alamofire
import SwiftyJSON

class WebPortalManager {
    static let shared = WebPortalManager()
    
    init() {
        loadCookies()
    }
    
    func saveCookies(response: DataResponse<Any>) {
        let headerFields = response.response?.allHeaderFields as! [String: String]
        let url = response.response?.url
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url!)
        var cookieArray = [[HTTPCookiePropertyKey: Any]]()
        for cookie in cookies {
            cookieArray.append(cookie.properties!)
        }
        UserDefaults.standard.set(cookieArray, forKey: "savedCookies")
        UserDefaults.standard.synchronize()
    }
    
    func loadCookies() {
        guard let cookieArray = UserDefaults.standard.array(forKey: "savedCookies") as? [[HTTPCookiePropertyKey: Any]] else { return }
        for cookieProperties in cookieArray {
            if let cookie = HTTPCookie(properties: cookieProperties) {
                HTTPCookieStorage.shared.setCookie(cookie)
            }
        }
    }
    
    private let apiUrl = "https://dlercloud.net"
    
    var isLogin:Bool {
        return username != nil && password != nil
    }
    
    var username:String? {
        get {
            return UserDefaults.standard.string(forKey: "kwebusername")
        }
        set {
            if let name = newValue {
                accountItem.title = name
                UserDefaults.standard.set(name, forKey: "kwebusername")
            } else {
                UserDefaults.standard.removeObject(forKey: "kwebusername")
            }
        }
        
    }
    
    var password:String? {
        get {
            return UserDefaults.standard.string(forKey: "kwebpwd")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "kwebpwd")
        }
    }
    
    private func req(
        _ url: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding = URLEncoding.default)
        -> DataRequest {
            
            return request(apiUrl + url,
                           method: method,
                           parameters: parameters,
                           encoding:encoding,
                           headers: [:])
    }
    
    func login(mail:String,password:String,authCode:String="",complete:((String?)->())?=nil) {
        req("/auth/login",
            method: .post,
            parameters: ["email":mail,"passwd":password,"code":authCode,"remember_me":"on"]
            ).responseJSON{ [weak self]
                resp in
                guard let self = self else {return}
                guard let r = resp.result.value else {
                    if resp.response?.statusCode == 200 {
                        self.username = mail
                        self.password = password
                        self.saveCookies(response: resp)
                        complete?(nil)
                    } else {
                        complete?("请求失败")
                    }
                    return
                }

                let json = JSON(r)
                
                if json["ret"].intValue == 1 {
                    self.username = mail
                    self.password = password
                    self.saveCookies(response: resp)
                    complete?(nil)
                } else {
                    complete?(json["msg"].string ?? "未知错误")
                }
        }
    }
    
    func getClashUrl(html:String) -> String? {
        let pattern = "http.*?clash=1"
        do {
            let regex:NSRegularExpression = try NSRegularExpression(pattern: pattern, options: NSRegularExpression.Options.caseInsensitive)
            let all = NSRange(location: 0, length: html.count)
            let r = regex.matches(in: html, options: .withTransparentBounds, range: all)
            guard let nsrange = r.first?.range(at: 0),
                let range = Range(nsrange, in: html) else {return nil}
            let res = html[range]
            return String(res)
        } catch {
            return nil
        }
    }
    
    lazy var accountItem:NSMenuItem = {
        return NSMenuItem(title: username ?? "", action: nil, keyEquivalent: "")
    }()

    
    lazy var refreshRemoteConfigUrlItem:NSMenuItem = {
        let item = NSMenuItem(title: "更新托管配置网址", action:#selector(actionRefreshConfigUrl) , keyEquivalent: "")
        item.target = self
        return item
    }()
    
    lazy var refreshRemoteConfigItem:NSMenuItem = {
        let item = NSMenuItem(title: "更新托管配置", action:#selector(actionRefreshConfigUrl) , keyEquivalent: "")
        item.target = self
        return item
    }()

    lazy var logoutItem:NSMenuItem = {
        let item = NSMenuItem(title: "注销", action:#selector(actionLogout) , keyEquivalent: "")
        item.target = self
        return item
    }()
    
    lazy var checkInItem:NSMenuItem = {
        let item = NSMenuItem(title: "签到", action:#selector(actionCheckIn) , keyEquivalent: "")
        item.target = self
        return item
    }()
    
    lazy var menu:NSMenu = {
        let m = NSMenu(title: "menu")
        m.items = [accountItem,checkInItem,refreshRemoteConfigUrlItem,refreshRemoteConfigItem,logoutItem]
        return m
    }()
    
    
    func getUserHtml(sureLogin:Bool = false, complete:((String?,String?)->())?=nil) {
        req("/user").responseString { (resp) in
            guard let html = resp.result.value else {
                complete?("请求失败",nil)
                return
            }
            
            if html.contains("使用邮箱/密码登陆") {
                if sureLogin {
                    complete?("登录失败",nil)
                    self.actionLogout()
                    return
                }
                print("重新登录")
                self.login(mail: self.username ?? "", password: self.password ?? "") {
                    error in
                    if let error = error {
                        complete?(error,nil)
                    } else {
                        self.getUserHtml(sureLogin:true,complete: complete)
                    }
                }
            } else {
                complete?(nil,html)
            }
        }
    }
    
    func refreshConfigUrl(complete:((String?)->())?=nil){
        getUserHtml{
            err,html in
            if let err = err {
                complete?(err)
                return
            }
            guard let html = html else {return}
            guard let url = self.getClashUrl(html: html) else {
                complete?("解析失败")
                return
            }
            RemoteConfigManager.configUrl = url
            complete?(nil)
        }
    }
    
    @objc func actionLogout() {
        self.username = nil
        self.password = nil
        UserDefaults.standard.removeObject(forKey: "savedCookies")
    }
    
    @objc func actionRefreshConfigUrl(){
        NSAlert.alert(with: "点击开始更新,更新过程中请稍等")
        refreshConfigUrl { (err) in
            NSAlert.alert(with: "获取url成功,点击开始刷新配置文件")
            RemoteConfigManager.updateConfigIfNeed() { err in
                NSAlert.alert(with: err ?? "更新成功")
            }
        }
    }
    
    @objc func actionCheckIn(){
        
        getUserHtml {
            _,_ in
            self.req("/user/checkin",method: .post).responseJSON{
                resp in
                guard let res = resp.result.value else {
                    NSUserNotificationCenter.default.post(title: "签到", info: "请求失败")
                    return
                }
                let json = JSON(res)
                let msg = json["msg"].string ?? "未知错误"
                NSUserNotificationCenter.default.post(title: "签到", info: msg)
                
            }
        }
    }
    
    @objc func actionRefreshConfig() {
        RemoteConfigManager.updateConfigIfNeed()
    }
}
