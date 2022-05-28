//
//  FRDeviceCollector.swift
//  FRAuth
//
//  Copyright (c) 2019-2021 ForgeRock. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// FRDeviceCollector class manages, and collects Device related information with given DeviceCollector objects and returns JSON result of all Device Collectors
@objc
public class FRDeviceCollector: NSObject {
    /// Singleton instance of FRDeviceCollector
    @objc
    public static let shared = FRDeviceCollector()
    /// An array of DeviceCollector to be collected
    @objc
    public var collectors: [DeviceCollector]
    /// Current version of Device Collector structure
    @objc
    static let FRDeviceCollectorVersion: String = "1.0"
    
    /// Private initialization method which initializes default array of DeviceCollector
    @objc
    public override init() {
        collectors = [
            PlatformCollector(),
            HardwareCollector(),
            BrowserCollector(),
            TelephonyCollector(),
            NetworkCollector()
        ]
    }
    
    /// Collects Device Information with all given DeviceCollector
    ///
    /// - Parameter completion: completion block which returns JSON of all Device Collectors' results
    @objc
    public func collect(completion: @escaping DeviceCollectorCallback) {
        
        let dispatchGroup = DispatchGroup()
        let threadSafe = SerialAtomic(dispatchGroup: dispatchGroup)
        for collector in self.collectors {
            dispatchGroup.enter()
                collector.collect { (collectedData) in
                    threadSafe.collectAndDispatch(key: collector.name, value: collectedData)
                    dispatchGroup.leave()
                }
        }
        dispatchGroup.notify(queue: .main) {
            completion(threadSafe.get())
        }
    }
}

class SerialAtomic {
    
    let isolationQueue: DispatchQueue = DispatchQueue(label: "com.forgerock.serial")
    
    var result: [String: Any] = [:]
    
     init(dispatchGroup: DispatchGroup? = nil) {
        result["version"] = FRDeviceCollector.FRDeviceCollectorVersion
        if let device = FRDevice.currentDevice {
            result["identifier"] = device.identifier.getIdentifier()
        }
    }
    
    func collectAndDispatch(key: String, value: [String: Any]) {
        isolationQueue.sync { [weak self] in
            if value.keys.count > 0 {
                self?.result[key] = value
            }
        }
    }

    func get() -> [String: Any] {
        isolationQueue.sync { [weak self] in
            return self?.result ?? [:]
        }
    }
}
