import XCTest
@testable import MenoMap
import MenoCore

final class EntitlementTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_790_000_000)

    func testLifetimeIsPro() {
        XCTAssertTrue(Entitlement.isPro([EntitlementInput(productID: ProductID.lifetime, expirationDate: nil, revocationDate: nil)], now: now))
    }

    func testActiveSubscriptionIsPro() {
        let t = EntitlementInput(productID: ProductID.yearly, expirationDate: now.addingTimeInterval(86400), revocationDate: nil)
        XCTAssertTrue(Entitlement.isPro([t], now: now))
    }

    func testExpiredSubscriptionIsFree() {
        let t = EntitlementInput(productID: ProductID.monthly, expirationDate: now.addingTimeInterval(-1), revocationDate: nil)
        XCTAssertFalse(Entitlement.isPro([t], now: now))
    }

    func testRevokedIsFree() {
        let t = EntitlementInput(productID: ProductID.lifetime, expirationDate: nil, revocationDate: now)
        XCTAssertFalse(Entitlement.isPro([t], now: now))
    }

    func testVisitReportAloneIsNotPro() {
        XCTAssertFalse(Entitlement.isPro([EntitlementInput(productID: ProductID.visitReport, expirationDate: nil, revocationDate: nil)], now: now))
    }
}

final class AskMenoMapTests: XCTestCase {
    let ask = AskMenoMapService()

    func testUnknownQueryFallsBackSafely() {
        guard case .fallback(let text) = ask.answer("xylophone quantum banana") else { return XCTFail("expected fallback") }
        XCTAssertTrue(text.contains("clinician"))
        XCTAssertTrue(text.contains("emergency"))
    }

    func testEmptyQueryFallsBack() {
        guard case .fallback = ask.answer("   ") else { return XCTFail("expected fallback") }
    }

    func testKnownQuestionMatchesArticle() {
        guard case .matched(let faq, let article) = ask.answer("Why do I keep waking at 3am?") else { return XCTFail("expected match") }
        XCTAssertEqual(faq.articleID, "sleep")
        XCTAssertNotNil(article)
    }

    func testMedicationQuestionGetsSafetyAnswer() {
        guard case .matched(let faq, _) = ask.answer("should I stop my HRT dose") else { return XCTFail("expected match") }
        XCTAssertTrue(faq.answer.contains("cannot tell you") || faq.articleID == "hormone-therapy")
    }

    func testEveryFAQPointsAtARealArticle() {
        for f in FAQLibrary.all { XCTAssertNotNil(ArticleLibrary.article(id: f.articleID), f.question) }
        XCTAssertEqual(ArticleLibrary.all.count, 8)
        for a in ArticleLibrary.all where a.sourceName != nil {
            XCTAssertTrue(a.needsSourceReview || (a.sourceURL != nil && a.reviewedAt != nil),
                          "\(a.id): an article only ships as checked with a real source link and date")
        }
    }
}

@MainActor
final class SafetyAndPDFTests: XCTestCase {
    func testPostMenopauseProfileTripsBleedingBanner() throws {
        let container = try MenoSchema.makeContainer(inMemory: true)
        let p = UserProfile()
        container.mainContext.insert(p)
        XCTAssertFalse(p.bleedingNeedsCheck)
        p.stage = .postmenopause
        XCTAssertTrue(p.bleedingNeedsCheck)
        p.stage = .perimenopause
        p.noLongerHasPeriods = true
        XCTAssertTrue(p.bleedingNeedsCheck)
    }

    func testBleedingCopyIsNonDiagnostic() {
        XCTAssertTrue(BleedingCopy.message.contains("should be checked by a clinician"))
        XCTAssertTrue(BleedingCopy.message.contains("cannot tell you why"))
    }

    func testPDFContainsDisclaimerAndFooter() throws {
        let store = MenoStore(container: try MenoSchema.makeContainer(inMemory: true))
        store.insertSurge(SurgeRecord(kind: .hotFlash, startedAt: .now.addingTimeInterval(-3600), durationSec: 120, intensity: 3, source: .app))
        let input = VisitPDFInput.build(store: store, appointment: nil, windowDays: 30, languageCode: "en", paper: .letter, preview: false)
        let data = VisitPDFRenderer().makePDF(input)
        XCTAssertGreaterThan(data.count, 1000)
        let doc = try XCTUnwrap(PDFDocumentText.text(from: data))
        XCTAssertTrue(doc.contains("does not diagnose"), "disclaimer box")
        XCTAssertTrue(doc.contains("Not a diagnosis"), "footer")
        XCTAssertTrue(doc.contains("Entered by the user"), "footer")
    }

    func testFreePreviewIsWatermarked() throws {
        let store = MenoStore(container: try MenoSchema.makeContainer(inMemory: true))
        let input = VisitPDFInput.build(store: store, appointment: nil, windowDays: 7, languageCode: "en", paper: .a4, preview: true)
        let text = try XCTUnwrap(PDFDocumentText.text(from: VisitPDFRenderer().makePDF(input)))
        XCTAssertTrue(text.contains("PREVIEW"))
    }

    func testCheckInMergeKeepsDisabledMetricHistory() throws {
        let store = MenoStore(container: try MenoSchema.makeContainer(inMemory: true))
        let day = DayKey.today()
        store.upsertCheckIn(CheckInRecord(day: day, scores: [.brainFog: 6, .sleep: 4]))
        store.upsertCheckIn(CheckInRecord(day: day, scores: [.sleep: 7]))
        let r = try XCTUnwrap(store.checkIn(for: day)?.record)
        XCTAssertEqual(r.scores[.brainFog], 6)
        XCTAssertEqual(r.scores[.sleep], 7)
    }

    func testDeleteAllEmptiesStore() throws {
        let store = MenoStore(container: try MenoSchema.makeContainer(inMemory: true))
        store.insertSurge(SurgeRecord(kind: .nightSweat, startedAt: .now, durationSec: 60, intensity: 2, source: .app))
        _ = store.profile()
        store.deleteAll()
        XCTAssertTrue(store.surgeRecords().isEmpty)
    }
}

import PDFKit
enum PDFDocumentText {
    static func text(from data: Data) -> String? { PDFDocument(data: data)?.string }
}
