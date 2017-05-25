//
//  FayeClient+Bayuex.swift
//  Pods
//
//  Created by Binboy_王兴彬 on 24/05/2017.
//
//

import Foundation

/**
 Bayeux Protocol Reference
 ref: https://docs.cometd.org/current/reference/#_bayeux
 */

let BayeuxConnectionTypeLongPolling = "long-polling"
let BayeuxConnectionTypeCallbackPolling = "callback-polling"
let BayeuxConnectionTypeIFrame = "iframe";
let BayeuxConnectionTypeWebSocket = "websocket"

let BayeuxChannelHandshake = "/meta/handshake"
let BayeuxChannelConnect = "/meta/connect"
let BayeuxChannelDisconnect = "/meta/disconnect"
let BayeuxChannelSubscribe = "/meta/subscribe"
let BayeuxChannelUnsubscribe = "/meta/unsubscribe"

let BayeuxVersion = "1.0"
let BayeuxMinimumVersion = "1.0beta"

let BayeuxMessageChannelKey = "channel"
let BayeuxMessageClientIdKey = "clientId"
let BayeuxMessageIdKey = "id"
let BayeuxMessageDataKey = "data"
let BayeuxMessageSubscriptionKey = "subscription"
let BayeuxMessageExtensionKey = "ext"
let BayeuxMessageVersionKey = "version"
let BayeuxMessageMinimuVersionKey = "minimumVersion"
let BayeuxMessageSupportedConnectionTypesKey = "supportedConnectionTypes"
let BayeuxMessageConnectionTypeKey = "connectionType"

// MARK: Bayuex Protocol Methods

extension FayeClient {
    
    /**
     Handshake meta message
     {
     "channel": "/meta/handshake",
     "version": "1.0",
     "minimumVersion": "1.0beta",
     "supportedConnectionTypes": ["long-polling", "callback-polling", "iframe"]
     }
     */
    func bayuexHandshake() {
        
        let supportedConnectionTypes: [String] = [
            BayeuxConnectionTypeLongPolling,
            BayeuxConnectionTypeCallbackPolling,
            BayeuxConnectionTypeIFrame,
            BayeuxConnectionTypeWebSocket,
            ]
        
        var message: [String: Any] = [
            BayeuxMessageChannelKey: BayeuxChannelHandshake,
            BayeuxMessageVersionKey: BayeuxVersion,
            BayeuxMessageMinimuVersionKey: BayeuxMinimumVersion,
            BayeuxMessageSupportedConnectionTypesKey: supportedConnectionTypes,
            ]
        
        if let ext = channelExtensions["handshake"] {
            message[BayeuxMessageExtensionKey] = ext
        }
        
        write(message: message)
    }
    
    /**
    Connect meta message
    {
    "channel": "/meta/connect",
    "clientId": "Un1q31d3nt1f13r",
    "connectionType": "long-polling"
    }
     */
    func bayuexConnect() {
        
        guard let clientID = clientID else {
            failedWithError(.clientIDNotFound)
            return
        }
        
        var message: [String: Any] = [
            BayeuxMessageChannelKey: BayeuxChannelConnect,
            BayeuxMessageClientIdKey: clientID,
            BayeuxMessageConnectionTypeKey: BayeuxConnectionTypeWebSocket,
            ]
        
        if let ext = channelExtensions["connect"] {
            message[BayeuxMessageExtensionKey] = ext
        }
        
        write(message: message)
    }
    
    /**
     Disconnect meta message
     {
     "channel": "/meta/disconnect",
     "clientId": "Un1q31d3nt1f13r"
     }
     */
    func bayuexDisconnect() {
        
        guard let clientID = clientID else {
            failedWithError(.clientIDNotFound)
            return
        }
        
        let message: [String: Any] = [
            BayeuxMessageChannelKey: BayeuxChannelDisconnect,
            BayeuxMessageClientIdKey: clientID,
            ]
        
        write(message: message)
    }
    
    /**
     Subscribe meta message
     {
     "channel": "/meta/subscribe",
     "clientId": "Un1q31d3nt1f13r",
     "subscription": "/foo/xx"
     }
     */
    func bayuexSubscribe(to channel: Channel) {
        
        guard let clientID = clientID else {
            failedWithError(.clientIDNotFound)
            return
        }
        
        var message: [String: Any] = [
            BayeuxMessageChannelKey: BayeuxChannelSubscribe,
            BayeuxMessageClientIdKey: clientID,
            BayeuxMessageSubscriptionKey: channel,
            ]
        
        if let ext = channelExtensions[channel] {
            message[BayeuxMessageExtensionKey] = ext
        }
        
        write(message: message) { [weak self] finish in
            if finish {
                self?.pendingChannelSubscriptionSet.insert(channel)
            }
        }
    }
    
    /**
     Unsubscribe meta message
     {
     "channel": "/meta/unsubscribe",
     "clientId": "Un1q31d3nt1f13r",
     "subscription": "/foo/xx"
     }
     */
    func bayuexUnsubscribe(from channel: Channel) {
        
        guard let clientID = clientID else {
            failedWithError(.clientIDNotFound)
            return
        }
        
        let message: [String: Any] = [
            BayeuxMessageChannelKey: BayeuxChannelUnsubscribe,
            BayeuxMessageClientIdKey: clientID,
            BayeuxMessageSubscriptionKey: channel,
            ]
        
        write(message: message)
    }
    
    /**
     Publish meta message
     {
     "channel": "/some/channel",
     "clientId": "Un1q31d3nt1f13r",
     "data": "some application string or JSON encoded object",
     "id": "some unique message id"
     }
     */
    func bayuexPublish(message messageData: [String: Any], withMessageUniqueID messageID: String? = nil, to channel: Channel, withExtention ext: [String: Any]? = nil) {
        
        guard isConnected && isWebSocketOpen else {
            failedWithError(.lostConnection(url: serverURL, error: "FayeClient not connected to server."))
            return
        }
        
        guard let clientID = clientID else {
            failedWithError(.clientIDNotFound)
            return
        }
        
        let messageID = messageID ?? self.generateUniqueMessageID()
        
        var message: [String: Any] = [
            BayeuxMessageChannelKey: channel,
            BayeuxMessageClientIdKey: clientID,
            BayeuxMessageDataKey: messageData,
            BayeuxMessageIdKey: messageID,
            ]
        
        if let ext = ext {
            message[BayeuxMessageExtensionKey] = ext
            
        } else {
            if let ext = channelExtensions[channel] {
                message[BayeuxMessageExtensionKey] = ext
            }
        }
        
        write(message: message)
    }
}

