import Foundation
import IOKit.hid

final class LidSensor {
    private var manager: IOHIDManager?
    private var device: IOHIDDevice?

    static func decode(_ bytes: [UInt8]) -> Double? {
        guard bytes.count >= 3, bytes[0] == 1 else { return nil }
        let value = Double(UInt16(bytes[1]) | UInt16(bytes[2]) << 8)
        // The sensor's feature report reports whole degrees, despite some third-party headers claiming centidegrees.
        guard value >= 0, value <= 360 else { return nil }
        return value
    }
    func connect() -> Bool {
        disconnect()
        let m = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        manager = m
        let match: [String: Any] = [kIOHIDVendorIDKey: 0x05AC, kIOHIDProductIDKey: 0x8104,
                                   kIOHIDPrimaryUsagePageKey: 0x20, kIOHIDPrimaryUsageKey: 0x8A]
        IOHIDManagerSetDeviceMatching(m, match as CFDictionary)
        guard IOHIDManagerOpen(m, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess,
              let devices = IOHIDManagerCopyDevices(m) as? Set<IOHIDDevice> else { return false }
        for candidate in devices {
            guard IOHIDDeviceOpen(candidate, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else { continue }
            device = candidate
            if read() != nil { return true }
            IOHIDDeviceClose(candidate, IOOptionBits(kIOHIDOptionsTypeNone))
            device = nil
        }
        return false
    }
    func read() -> Double? {
        guard let device else { return nil }
        var bytes = [UInt8](repeating: 0, count: 8)
        var count = bytes.count
        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &bytes, &count)
        guard result == kIOReturnSuccess else { return nil }
        return Self.decode(Array(bytes.prefix(count)))
    }
    func disconnect() {
        if let device { IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone)) }
        if let manager { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }
        device = nil; manager = nil
    }
    deinit { disconnect() }
}
