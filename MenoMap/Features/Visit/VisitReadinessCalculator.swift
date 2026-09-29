import Foundation
import MenoCore

enum VisitReadinessCalculator {
    @MainActor
    static func readiness(store: MenoStore, appointment: Appointment?) -> VisitReadiness {
        let window = DayWindow(lastDays: 30, endingOn: .today())
        let profile = store.profile()
        return VisitReadiness.compute(
            loggedDaysLast30: store.loggedDays(in: window).count,
            surgesLast30: store.surgeRecords(in: window).count,
            checkInsLast30: store.checkInRecords(in: window).count,
            medicationsDone: !store.medications().isEmpty || profile.medicationsConfirmedNone,
            questionsPicked: appointment?.questions.count ?? 0)
    }
}
