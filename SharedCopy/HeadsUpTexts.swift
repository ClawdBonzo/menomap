import Foundation

/// Copy shared by the app ("Tell my person") and the iMessage extension (stickers + heads-up cards).
enum HeadsUpTexts {
    static var headsUps: [String] {
        [
            String(localized: "Night sweat. Cracking the window."),
            String(localized: "Hot flash, give me 3 minutes."),
            String(localized: "Rough night. I'll be slow this morning."),
            String(localized: "Could you turn the fan on?"),
            String(localized: "Heads up: running hot today. Not you, it's me."),
        ]
    }

    /// Sticker lines, wry voice. Rendered on device so they follow the phone's language.
    static var stickers: [String] {
        [
            String(localized: "Personal summer in progress"),
            String(localized: "Not now, I'm molten"),
            String(localized: "Crack a window"),
            String(localized: "3am club"),
            String(localized: "Running hot. Not you, it's me."),
            String(localized: "Internal sauna: on"),
            String(localized: "Hot flash. Back in 3."),
            String(localized: "Thermostat: mine"),
            String(localized: "Sweater on. Sweater off."),
            String(localized: "Night shift survivor"),
            String(localized: "Recalibrating…"),
            String(localized: "Fan me"),
        ]
    }
}
