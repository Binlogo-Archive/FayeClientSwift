//
//  ViewController.swift
//  FayeCilentSwift
//
//  Created by Binlogo on 05/24/2017.
//  Copyright (c) 2017 Binlogo. All rights reserved.
//

import UIKit
import FayeCilentSwift

class ViewController: UIViewController {

    let fayeClient = FayeClient(serverURL: URL(string: "ws://localhost:5222/faye")!)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        fayeClient.delegate = self
        fayeClient.connect()
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func sendMessage(_ sender: Any) {
        fayeClient.sendMessage(["text": "Hello from FayeClientSwift"], to: "/cool")
    }
}

extension ViewController: FayeClientDelegate {
    
    func fayeClient(_ client: FayeClient, didConnectedToServer url: URL) {
        print("连接到服务器：", url.absoluteString)
        
        fayeClient.subscribe(to: "/cool") { (message) in
            print("Cool 频道消息自定义方法正在执行：", message.debugDescription)
        }
        
    }
    func fayeClient(_ client: FayeClient, didDisconnectedWithError error: Error?) {
        print("服务器断开：", error?.localizedDescription ?? "")
    }
    
    func fayeClient(_ client: FayeClient, didSubscribedTo channel: Channel) {
        print("已订阅频道：", channel)
    }
    func fayeClient(_ client: FayeClient, didUnsubscribedFrom channel: Channel) {
        print("已退订频道：", channel)
    }
    
    func fayeClient(_ client: FayeClient, didReceivedMessage message: [String: Any], from channel: Channel) {
        print("收到自定义消息：", message.debugDescription)
    }
    
    func fayeClient(_ client: FayeClient, didFailedWithError error: FayeClientError?) {
        print("FayeClient 错误：", error.debugDescription)
    }
}

