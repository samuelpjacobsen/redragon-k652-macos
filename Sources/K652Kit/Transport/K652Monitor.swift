import Foundation
import IOKit.hid

/// Avisa quando o K652 aparece ou some, pelo cabo USB ou pelo Bluetooth.
/// Os callbacks chegam no run loop principal.
public final class K652Monitor {
    private let manager: IOHIDManager
    private var debounce: DispatchWorkItem?
    /// O teclado aparece como várias interfaces HID; espera todas chegarem antes de avisar.
    static let settleDelay: TimeInterval = 0.6

    /// Chamado depois de qualquer conexão ou desconexão, já com `usbPresent` e `bluetoothPresent` atualizados.
    public var onChange: (() -> Void)?

    public init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [[String: Any]] = [
            [kIOHIDVendorIDKey: HIDTransport.vendorID, kIOHIDProductIDKey: HIDTransport.productID],
            [kIOHIDVendorIDKey: BluetoothKeyboard.vendorID, kIOHIDProductIDKey: BluetoothKeyboard.productID],
        ]
        IOHIDManagerSetDeviceMatchingMultiple(manager, matching as CFArray)
    }

    public func start() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, _ in
            guard let context else { return }
            Unmanaged<K652Monitor>.fromOpaque(context).takeUnretainedValue().scheduleChange()
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, _ in
            guard let context else { return }
            Unmanaged<K652Monitor>.fromOpaque(context).takeUnretainedValue().scheduleChange()
        }, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    }

    public var usbPresent: Bool { hasDevice(vendorID: HIDTransport.vendorID, productID: HIDTransport.productID) }

    public var bluetoothPresent: Bool {
        hasDevice(vendorID: BluetoothKeyboard.vendorID, productID: BluetoothKeyboard.productID)
    }

    private func hasDevice(vendorID: Int, productID: Int) -> Bool {
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return false }
        return devices.contains { device in
            IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int == vendorID
                && IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int == productID
        }
    }

    private func scheduleChange() {
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onChange?() }
        debounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.settleDelay, execute: work)
    }
}
