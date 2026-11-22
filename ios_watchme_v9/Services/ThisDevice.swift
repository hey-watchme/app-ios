//
//  ThisDevice.swift
//  ios_watchme_v9
//
//  This iPhone as a recording device: an id made once per install (reinstalling counts as
//  another device) and the model. Sent with each upload so the server can note which
//  device recorded it (platform docs/product/accounts-subjects-devices.md).
//

import Foundation

enum ThisDevice {
    private static let idKey = "watchme_install_device_id"

    static var id: String {
        if let saved = UserDefaults.standard.string(forKey: idKey) { return saved }
        let made = UUID().uuidString.lowercased()
        UserDefaults.standard.set(made, forKey: idKey)
        return made
    }

    /// Hardware model, e.g. "iPhone14,5" (the simulator reports its host's identifier).
    static var model: String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
    }
}
