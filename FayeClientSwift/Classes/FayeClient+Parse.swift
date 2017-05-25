//
//  FayeClient+Parse.swift
//  Pods
//
//  Created by Binboy_王兴彬 on 25/05/2017.
//
//

import Foundation

// MARK: - Parse Faye Messages
extension FayeClient {
    
    func parseFayeMessages(_ messages: [[String: Any]]) {
        
        #if DEBUG
        print("parsingFayeMessages: \(messages)")
        #endif
        
        let fayeMessages = messages.map({ FayeMessage.fromDictionary($0) }).flatMap({ $0 })
        
        fayeMessages.forEach({ fayeMessage in
            
            switch fayeMessage.channel {
                
            case BayeuxChannelHandshake:
                
                if fayeMessage.successful {
                    retryAttempt = 0
                    clientID = fayeMessage.clientID
                    isConnected = true
                    
                    delegate?.fayeClient(self, didConnectedToServer: serverURL)
                    
                    bayuexConnect()
                    subscribeToPendingSubscriptions()
                    
                } else {
                    let message = String(format: "Faye client couldn't handshake with server. %@", fayeMessage.error ?? "")
                    failedWithError(.bayuexTransportError(message: message))
                }
                
            case BayeuxChannelConnect:
                
                if fayeMessage.successful {
                    isConnected = true
                    bayuexConnect()
                } else {
                    let message = String(format: "Faye client couldn't connect to server. %@", fayeMessage.error ?? "")
                    failedWithError(.bayuexTransportError(message: message))
                }
                
            case BayeuxChannelDisconnect:
                
                if fayeMessage.successful {
                    closeConnection()
                    isConnected = false
                    clearSubscriptions()
                    
                    delegate?.fayeClient(self, didDisconnectedWithError: nil)
                    
                } else {
                    let message = String(format: "Faye client couldn't disconnect from server. %@", fayeMessage.error ?? "")
                    failedWithError(.bayuexTransportError(message: message))
                }
                
            case BayeuxChannelSubscribe:
                
                guard let subscription = fayeMessage.subscription else {
                    break
                }
                
                pendingChannelSubscriptionSet.remove(subscription)
                
                if fayeMessage.successful {
                    openChannelSubscriptionSet.insert(subscription)
                    
                    delegate?.fayeClient(self, didSubscribedTo: subscription)
                    
                } else {
                    let message = String(format: "Faye client couldn't subscribe channel %@ with server. %@", subscription, fayeMessage.error ?? "")
                    failedWithError(.bayuexTransportError(message: message))
                }
                
            case BayeuxChannelUnsubscribe:
                
                guard let subscription = fayeMessage.subscription else {
                    break
                }
                
                if fayeMessage.successful {
                    subscribedChannels.removeValue(forKey: subscription)
                    pendingChannelSubscriptionSet.remove(subscription)
                    openChannelSubscriptionSet.remove(subscription)
                    
                    delegate?.fayeClient(self, didUnsubscribedFrom: subscription)
                    
                } else {
                    let message = String(format: "Faye client couldn't unsubscribe channel %@ with server. %@", subscription, fayeMessage.error ?? "")
                    failedWithError(.bayuexTransportError(message: message))
                }
                
            default:
                
                if openChannelSubscriptionSet.contains(fayeMessage.channel) {
                    
                    if let handler = subscribedChannels[fayeMessage.channel] {
                        handler(fayeMessage.data)
                        
                    }
                    delegate?.fayeClient(self, didReceivedMessage: fayeMessage.data, from: fayeMessage.channel)
                    
                } else {
                    // No match for channel
                    #if DEBUG
                        print("fayeMessage: \(fayeMessage)")
                    #endif
                    
                    if let messageID = fayeMessage.ID, let handler = privateChannels[messageID] {
                        handler(fayeMessage)
                    }
                }
            }
        })
    }
}
