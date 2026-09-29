import Foundation

// V1 ships empty implementations: no UI unless an implementation returns items. No affiliate URLs.

struct CommerceContext: Hashable { var screen: String }
struct CommerceItem: Hashable, Identifiable { var id: String; var title: String; var url: URL }
struct CareReferral: Hashable, Identifiable { var id: String; var name: String; var url: URL }

protocol CommerceRecommending { func items(for context: CommerceContext) -> [CommerceItem] }
protocol CareReferralRouting { func options() -> [CareReferral] }

struct NoCommerce: CommerceRecommending { func items(for context: CommerceContext) -> [CommerceItem] { [] } }
struct NoCareReferrals: CareReferralRouting { func options() -> [CareReferral] { [] } }
