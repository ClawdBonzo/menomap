import os

/// Debug logging only (os_log). Never log notes, medication names, scores or free text.
enum MenoLog {
    static let store = Logger(subsystem: "app.gwlabs.menomap", category: "store")
    static let health = Logger(subsystem: "app.gwlabs.menomap", category: "health")
    static let surge = Logger(subsystem: "app.gwlabs.menomap", category: "surge")
    static let commerce = Logger(subsystem: "app.gwlabs.menomap", category: "commerce")
    static let watch = Logger(subsystem: "app.gwlabs.menomap", category: "watch")
}
