import Foundation
import IOKit.hid

final class PointerDeviceSeizer {
    private var manager: IOHIDManager?
    private(set) var lastOpenResult: IOReturn = kIOReturnSuccess

    @discardableResult
    func start() -> IOReturn {
        stop()

        let manager = IOHIDManagerCreate(
            kCFAllocatorDefault,
            IOOptionBits(kIOHIDOptionsTypeNone)
        )

        let matches: [[String: Any]] = [
            Self.match(
                usagePage: Int(kHIDPage_GenericDesktop),
                usage: Int(kHIDUsage_GD_Mouse)
            ),
            Self.match(
                usagePage: Int(kHIDPage_GenericDesktop),
                usage: Int(kHIDUsage_GD_Pointer)
            ),
            Self.match(
                usagePage: Int(kHIDPage_Digitizer),
                usage: Int(kHIDUsage_Dig_TouchPad)
            )
        ]

        IOHIDManagerSetDeviceMatchingMultiple(manager, matches as CFArray)

        IOHIDManagerScheduleWithRunLoop(
            manager,
            CFRunLoopGetMain(),
            CFRunLoopMode.commonModes.rawValue
        )

        self.manager = manager

        let result = IOHIDManagerOpen(
            manager,
            IOOptionBits(kIOHIDOptionsTypeSeizeDevice)
        )

        lastOpenResult = result
        return result
    }

    func stop() {
        guard let manager else { return }

        IOHIDManagerClose(
            manager,
            IOOptionBits(kIOHIDOptionsTypeNone)
        )

        IOHIDManagerUnscheduleFromRunLoop(
            manager,
            CFRunLoopGetMain(),
            CFRunLoopMode.commonModes.rawValue
        )

        self.manager = nil
    }

    private static func match(usagePage: Int, usage: Int) -> [String: Any] {
        [
            kIOHIDDeviceUsagePageKey as String: usagePage,
            kIOHIDDeviceUsageKey as String: usage
        ]
    }

    deinit {
        stop()
    }
}
