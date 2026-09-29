import Foundation
import UserNotifications
import MenoCore

/// Local notifications only, all opt-in. No streak shame, no "falling behind".
@MainActor
final class NotificationService {
    private let center = UNUserNotificationCenter.current()

    enum ID {
        static let eveningCheckIn = "checkin.evening"
        static let heatReport = "heatreport.monthly"
        static let thirtyDays = "nudge.thirtydays"
        static func appointment(_ id: UUID, _ slot: String) -> String { "appt.\(id.uuidString).\(slot)" }
        static func experiment(_ id: UUID) -> String { "exp.\(id.uuidString)" }
        static func medication(_ id: UUID) -> String { "med.\(id.uuidString)" }
    }

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func isAuthorized() async -> Bool {
        let s = await center.notificationSettings()
        return s.authorizationStatus == .authorized || s.authorizationStatus == .provisional
    }

    private func add(_ id: String, title: String, body: String, trigger: UNNotificationTrigger, url: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let url { content.userInfo = ["url": url] }
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    // MARK: Check-in

    func scheduleEveningCheckIn(hour: Int, minute: Int) {
        center.removePendingNotificationRequests(withIdentifiers: [ID.eveningCheckIn])
        add(ID.eveningCheckIn,
            title: String(localized: "Evening check-in"),
            body: String(localized: "Four quick taps. Under 30 seconds."),
            trigger: UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: minute), repeats: true),
            url: "menomap://checkin")
    }

    func cancelEveningCheckIn() {
        center.removePendingNotificationRequests(withIdentifiers: [ID.eveningCheckIn])
    }

    // MARK: Appointment

    func scheduleAppointment(_ appt: Appointment) {
        cancelAppointment(appt.id)
        let cal = Calendar.current
        let who = appt.clinicianName.flatMap { $0.isEmpty ? nil : $0 }
        let slots: [(String, Int, Int, String, String)] = [
            ("t7", -7, 10, String(localized: "Appointment in a week"),
             String(localized: "A few more check-ins will make your notes stronger.")),
            ("t1", -1, 18, String(localized: "Appointment tomorrow"),
             String(localized: "Your notes are ready to review.")),
            ("t0", 0, 8, who.map { String(localized: "Seeing \($0) today") } ?? String(localized: "Appointment today"),
             String(localized: "Open MenoMap to share or print your notes.")),
        ]
        for (slot, offset, hour, title, body) in slots {
            guard let day = cal.date(byAdding: .day, value: offset, to: appt.date) else { continue }
            var comps = cal.dateComponents([.year, .month, .day], from: day)
            comps.hour = hour
            guard let fire = cal.date(from: comps), fire > .now else { continue }
            add(ID.appointment(appt.id, slot), title: title, body: body,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false), url: "menomap://visit")
        }
    }

    func cancelAppointment(_ id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: ["t7", "t1", "t0"].map { ID.appointment(id, $0) })
    }

    // MARK: Heat Report / experiments / nudges

    func scheduleHeatReport(enabled: Bool) {
        center.removePendingNotificationRequests(withIdentifiers: [ID.heatReport])
        guard enabled else { return }
        add(ID.heatReport,
            title: String(localized: "Your Heat Report is ready"),
            body: String(localized: "Last month, in one page."),
            trigger: UNCalendarNotificationTrigger(dateMatching: DateComponents(day: 1, hour: 9), repeats: true),
            url: "menomap://week")
    }

    func scheduleExperimentDone(_ e: ExperimentRecord) {
        let d = e.endDay.adding(days: 1)
        let comps = DateComponents(year: d.year, month: d.month, day: d.day, hour: 9)
        add(ID.experiment(e.id),
            title: String(localized: "Your experiment finished"),
            body: String(localized: "See what your entries show."),
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false), url: "menomap://week")
    }

    func cancelExperiment(_ id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [ID.experiment(id)])
    }

    /// "You have 30 days of logs — generate notes?" Max once ever.
    func scheduleThirtyDayNudgeIfNeeded(loggedDays: Int) {
        let key = "meno.nudge.thirty.sent"
        guard loggedDays >= 30, !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        add(ID.thirtyDays,
            title: String(localized: "30 days logged"),
            body: String(localized: "That's enough for clinician notes whenever you want them."),
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 60 * 60 * 3, repeats: false), url: "menomap://visit")
    }

    // MARK: Medications

    func scheduleMedication(_ med: Medication) {
        center.removePendingNotificationRequests(withIdentifiers: [ID.medication(med.id)])
        guard med.reminderOn else { return }
        add(ID.medication(med.id),
            title: String(localized: "Medication reminder"),
            body: String(localized: "Time for \(med.name). Tap to mark it taken or skipped."),
            trigger: UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: med.reminderHour, minute: med.reminderMinute), repeats: true))
    }

    func cancelMedication(_ id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [ID.medication(id)])
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
