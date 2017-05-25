//
//  FayeClient.swift
//  Pods
//
//  Created by Binboy_王兴彬 on 24/05/2017.
//
//

import Foundation
import Starscream

public enum FayeClientError: Error {
    
    case subscriptionError(channel: Channel, error: String)
    case lostConnection(url: URL, error: String)
    
    case deserializeMessageFailed(message: [String: Any], error: Error?)
    case serializeMessageFailed(jsonString: String, error: Error?)
    
    case clientIDNotFound
    
    case bayuexTransportError(message: String)
}

public typealias Channel = String

public typealias FayeClientSubscriptionHandler = (_ message: [String: Any]) -> Void
public typealias FayeClientPrivateHandler = (_ message: FayeMessage) -> Void

// MARK: - FayeClient Delegate Protocol
public protocol FayeClientDelegate: class {
    
    func fayeClient(_ client: FayeClient, didConnectedToServer url: URL)
    func fayeClient(_ client: FayeClient, didDisconnectedWithError error: Error?)
    
    func fayeClient(_ client: FayeClient, didSubscribedTo channel: Channel)
    func fayeClient(_ client: FayeClient, didUnsubscribedFrom channel: Channel)
    
    func fayeClient(_ client: FayeClient, didReceivedMessage message: [String: Any], from channel: Channel)
    
    func fayeClient(_ client: FayeClient, didFailedWithError error: FayeClientError?)
}

open class FayeClient {
    
    open weak var delegate:FayeClientDelegate?
    
    open internal(set) var webSocket: WebSocket?
    open internal(set) var serverURL: URL
    open internal(set) var clientID: String?
    
    open internal(set) var isConnected: Bool = false
    
    var isWebSocketOpen: Bool {
        
        if let webSocket = webSocket {
            return webSocket.isConnected
        }
        return false
    }
    
    var sentMessageCount: UInt = 0
    
    var pendingChannelSubscriptionSet: Set<Channel> = []
    var openChannelSubscriptionSet: Set<Channel> = []
    
    var subscribedChannels: [Channel: FayeClientSubscriptionHandler] = [:]
    var privateChannels: [Channel: FayeClientPrivateHandler] = [:]
    var channelExtensions: [Channel: Any] = [:]
    
    open var shouldRetryConnection: Bool = true
    open var retryInterval: TimeInterval = 1
    open var retryAttempt: Int = 0
    open var maximumRetryAttempts: Int = 5
    fileprivate var reconnectTimer: Timer?
    
    deinit {
        
        clearSubscriptions()
        invalidateReconnectTimer()
        closeConnection()
    }
    
    public init(serverURL: URL) {
        self.serverURL = serverURL
    }
}

// MARK: - Public Methods
extension FayeClient {
    
    public func connect() {
        
        if isConnected || isWebSocketOpen {
            return
        }
        
        openConnection()
    }
    
    public func disconnect() {
        
        bayuexDisconnect()
    }
    
    public func subscribe(to channel: Channel, usingBlock subscriptionHandler: FayeClientSubscriptionHandler? = nil) {
        
        if let subscriptionHandler = subscriptionHandler {
            subscribedChannels[channel] = subscriptionHandler
        } else {
            subscribedChannels.removeValue(forKey: channel)
        }
        
        if isConnected {
            bayuexSubscribe(to: channel)
        }
    }
    
    public func unsubscribe(from channel: Channel) {
        
        subscribedChannels.removeValue(forKey: channel)
        pendingChannelSubscriptionSet.remove(channel)
        
        if isConnected {
            bayuexUnsubscribe(from: channel)
        }
    }
    
    public func setExtension(_ ext: [String: Any], for channel: Channel) {
        
        channelExtensions[channel] = ext
    }
    
    public func removeExtension(for channel: Channel) {
        
        channelExtensions.removeValue(forKey: channel)
    }
    
    public func sendMessage(_ message: [String: Any], to channel: Channel, withExtension ext: [String: Any]? = nil, usingBlock subscriptionHandler: FayeClientPrivateHandler? = nil) {
        
        if let subscriptionHandler = subscriptionHandler {
            let messageID = generateUniqueMessageID()
            
            privateChannels[messageID] = subscriptionHandler
            
            bayuexPublish(message: message, withMessageUniqueID: messageID, to: channel, withExtention: ext)
        } else {
            bayuexPublish(message: message, to: channel, withExtention: ext)
        }
        
    }

}

// MARK: - Private Methods
extension FayeClient {
    
    func subscribeToPendingSubscriptions() {
        
        func canPending(_ channel: Channel) -> Bool {
            return !pendingChannelSubscriptionSet.contains(channel)
            && !openChannelSubscriptionSet.contains(channel)
        }
        
        subscribedChannels.keys.filter({ canPending($0) }).forEach { (channel) in
            subscribe(to: channel)
        }
    }
    
    @objc func tryReconnect(_ timer: Timer) {
        
        if isConnected || isWebSocketOpen {
            invalidateReconnectTimer()
        } else {
            if shouldRetryConnection && retryAttempt < maximumRetryAttempts {
                
                retryAttempt += 1
                
                openConnection()
            } else {
                invalidateReconnectTimer()
            }
        }
    }
    
    func invalidateReconnectTimer() {
        
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
    
    func reconnect() {
        
        guard shouldRetryConnection && retryAttempt < maximumRetryAttempts else {
            return
        }
        
        reconnectTimer = Timer.scheduledTimer(timeInterval: retryInterval, target: self, selector: #selector(tryReconnect(_:)), userInfo: nil, repeats: false)
    }
    
    func failedWithError(_ error: FayeClientError) {
        
        delegate?.fayeClient(self, didFailedWithError: error)
    }
    
    func clearSubscriptions() {
        
        subscribedChannels.removeAll()
        pendingChannelSubscriptionSet.removeAll()
        openChannelSubscriptionSet.removeAll()
    }
}

// MARK: - WebSocket Transport
extension FayeClient {
    
    func write(message: [String: Any], completion: ((_ finish: Bool) -> Void)? = nil) {
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: message)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                delegate?.fayeClient(self, didFailedWithError: .deserializeMessageFailed(message: message, error: nil))
                completion?(false)
                return
            }
            webSocket?.write(string: jsonString)
            
            completion?(true)
            
        } catch let error as NSError {
            delegate?.fayeClient(self, didFailedWithError: .deserializeMessageFailed(message: message, error: error))
            
            completion?(false)
        }
    }
    
    func openConnection() {
        
        closeConnection()
        
        self.webSocket = WebSocket(url: serverURL)
        
        if let webSocket = self.webSocket {
            webSocket.delegate = self
            webSocket.connect()
            
            print("Faye: Opening WebSocket connection with \(serverURL.absoluteString)")
        }
    }
    
    func closeConnection() {
        
        if let webSocket = self.webSocket {
            print("Faye: Closing WebSocket connection")
            
            webSocket.delegate = nil
            webSocket.disconnect(forceTimeout: 0)
            
            self.webSocket = nil
        }
    }
    
    
}

// MARK: - WebSocket Delegate
extension FayeClient: WebSocketDelegate {
    
    public func websocketDidConnect(socket: WebSocket) {
        
        bayuexHandshake()
    }
    
    public func websocketDidReceiveMessage(socket: WebSocket, text: String) {
        
        let jsonString = text
        
        guard let messageData = jsonString.data(using: .utf8) else {
            return
        }
        
        do {
            if let messages = try JSONSerialization.jsonObject(with: messageData) as? [[String: Any]] {
                parseFayeMessages(messages)
            }
            
        } catch let error as NSError {
            delegate?.fayeClient(self, didFailedWithError: FayeClientError.serializeMessageFailed(jsonString: jsonString, error: error))
        }
    }
    
    public func websocketDidReceiveData(socket: WebSocket, data: Data) {
        
        guard data.count > 0 else {
            return
        }
        
        let messageData = data
        
        do {
            if let messages = try JSONSerialization.jsonObject(with: messageData) as? [[String: Any]] {
                parseFayeMessages(messages)
            }
            
        } catch let error as NSError {
            if let message = String(data: messageData, encoding: .utf8) {
                delegate?.fayeClient(self, didFailedWithError: FayeClientError.serializeMessageFailed(jsonString: message, error: error))
            } else {
                delegate?.fayeClient(self, didFailedWithError: FayeClientError.serializeMessageFailed(jsonString: "Wrong Data", error: error))
            }
        }
    }
    
    public func websocketDidDisconnect(socket: WebSocket, error: NSError?) {
        
        isConnected = false
        
        clearSubscriptions()
        
        if let _ = error {
            reconnect()
        }
    }
}

// MARK: - Helper
extension FayeClient {
    
    func generateUniqueMessageID() -> String {
        
        sentMessageCount += 1
        return "\(sentMessageCount)".data(using: .utf8)!.base64EncodedString()
    }
}
