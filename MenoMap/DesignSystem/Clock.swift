import Foundation

/// Current hour of day. DEBUG builds accept `-MMHour <0-23>` so screenshots have a fixed greeting and day/night mode.
enum Clock {
    static var hour: Int {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-MMHour"), i + 1 < args.count, let h = Int(args[i + 1]) { return h }
        #endif
        return Calendar.current.component(.hour, from: .now)
    }
}
