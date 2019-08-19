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
    
    private let entranceUrl = "https://dler.cloud"
    private lazy var apiUrl:String = entranceUrl

    
    var isLogin:Bool {
        return username != nil && token != nil
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
    
    var token:String? {
        get {
            return UserDefaults.standard.string(forKey: "ktoken")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "ktoken")
        }
    }
    
    func refreshApiUrl(complete:(()->())?=nil) {
        print("getting real api url")
        request(entranceUrl, method: .head).response(queue: DispatchQueue.global()) { res in
            guard let targetUrl = res.response?.url,
            let scheme = targetUrl.scheme,
            let host = targetUrl.host
                else {
                    self.apiUrl = self.entranceUrl
                    complete?()
                    return
            }
            print("get target url:\(targetUrl.absoluteString)")
            self.apiUrl = "\(scheme)://\(host)"
            complete?()
        }
    }
    
    private func req(
        _ url: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding = URLEncoding.default)
        -> DataRequest {
            
//            guard let apiUrl = apiUrl else {
//                let sema = DispatchSemaphore(value: 0)
//                refreshApiUrl(){
//                    sema.signal()
//                }
//                sema.wait()
//                return self.req(url, method: method, parameters: parameters, encoding: encoding)
//            }
            
            return request(apiUrl + url,
                           method: method,
                           parameters: parameters,
                           encoding:encoding,
                           headers: [:])
    }
    
    func login(mail:String,password:String,complete:((String?)->())?=nil) {
        req("/api/v1/login",
            method: .post,
            parameters: ["email":mail,"passwd":password]
            ).responseJSON{
                [weak self]
                resp in
                guard let self = self else {return}
                guard let r = resp.result.value else {
                    if resp.response?.statusCode == 200 {
                        self.username = mail
                        complete?(nil)
                    } else {
                        complete?("请求失败")
                    }
                    return
                }

                let json = JSON(r)
                
                if let token = json["data"]["token"].string{
                    self.username = mail
                    self.token = token
                    complete?(nil)
                } else {
                    complete?("登陆失败" + json["msg"].stringValue)
                }
        }
    }
    
   
    
    lazy var accountItem:NSMenuItem = {
        return NSMenuItem(title: username ?? "", action: nil, keyEquivalent: "")
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
    
    
    lazy var menu:NSMenu = {
        let m = NSMenu(title: "menu")
        m.items = [accountItem,refreshRemoteConfigItem,logoutItem]
        return m
    }()
    
    
    func getRemoteConfig(token:String, complete:((String?,String?)->())?=nil) {
        
        req("/api/v1/managed/clash_ss", method: .post, parameters: ["access_token":token], encoding: JSONEncoding.default).responseJSON { res in
            guard let value = res.result.value else {
                complete?("请求失败", nil)
                return
            }
            
            let json = JSON(value)
            guard let token = json["data"].string else {
                complete?("解析失败",nil)
                return
            }

            complete?(nil, token)
        }
    }
    
    func refreshConfigUrl(complete:((String?, RemoteConfigModel?)->())?=nil){
        
        guard let token = self.token else {
            complete?("登录失效！请重新登录",nil)
            return
        }
        
        getRemoteConfig(token: token) {
            err, url in
            
            if let err = err {
                complete?(err, nil)
                return
            }
            
            let config = RemoteConfigModel(url: url!, name: "DlerCloud")
            RemoteConfigManager.shared.configs = [config]
            RemoteConfigManager.shared.saveConfigs()
            complete?(nil, config)
        }
    }
    
    @objc func actionLogout() {
        self.username = nil
        self.token = nil
    }
    
    @objc func actionRefreshConfigUrl(){
        NSAlert.alert(with: "点击开始更新,更新过程中请稍等")
        refreshConfigUrl { err,config in
            if let err = err {
                NSAlert.alert(with: "失败:\(err)")
                return
            }
            
            guard let config = config else {assertionFailure(); return}
            
            RemoteConfigManager.updateConfig(config: config, complete: { [weak config] error in
                NSAlert.alert(with: err ?? "更新成功")
                guard let config = config else {return}
                config.updateTime = Date()
                RemoteConfigManager.shared.saveConfigs()
            })
        }
    }
    
}
