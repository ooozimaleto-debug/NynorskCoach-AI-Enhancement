//
//  DeviceIdentity.swift
//  NynorskCoach
//
//  Device ID для per-device rate-limit на Cloudflare Worker proxy.
//  Не криптографическая идентификация — только ключ партиционирования
//  лимитов (X-Device-ID), см. CLOUDFLARE_WORKER_SETUP.md.
//

import UIKit

enum DeviceIdentity {
    static var id: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
    }
}
