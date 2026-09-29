import Foundation

/// Launch-argument values for screenshots and QA. Always nil in Release builds.
enum DebugArgs {
    static func value(_ flag: String) -> String? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: flag), i + 1 < args.count { return args[i + 1] }
        #endif
        return nil
    }
}
