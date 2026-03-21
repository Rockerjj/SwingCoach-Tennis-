import Foundation

enum AppConstants {
    static let appName = "Tennique"
    static let minimumIOSVersion = "17.0"
    static let minimumDeviceModel = "iPhone 12"

    static let privacyPolicyURL = URL(string: "https://tennique.app/privacy")!
    static let termsOfServiceURL = URL(string: "https://tennique.app/terms")!
    static let supportEmail = "support@tennique.app"
    static let appStoreID = "" // Set after App Store Connect setup

    enum Camera {
        static let defaultFPS: Int = 60
        static let processingFPS: Int = 15
        static let maxRecordingDuration: TimeInterval = 1800
        static let recommendedDistance = "10-15 feet away"
        static let recommendedHeight = "Waist height"
    }

    enum Analysis {
        static let maxKeyFrames: Int = 20
        static let poseConfidenceThreshold: Float = 0.3
        static let freeSessionsAllowed: Int = 3
    }

    enum API {
        static let baseURL = "https://tennique-api-production.up.railway.app/api/v1"
        #if DEBUG
        static let debugBaseURL = "http://10.0.0.101:8000/api/v1"
        #endif
    }

    enum Supabase {
        static var projectURL: String {
            ProcessInfo.processInfo.environment["SUPABASE_URL"]
                ?? "https://ksfntpplbgtingcdizey.supabase.co"
        }
        static var anonKey: String {
            ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"]
                ?? "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtzZm50cHBsYmd0aW5nY2RpemV5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE0MTU3MDUsImV4cCI6MjA4Njk5MTcwNX0.J5dXectt7PaB5cc5EEdwHOSbnr6G89tbY3_W1ywBgHE"
        }
        static let storageBucket = "session-frames"
    }

    enum Subscription {
        static let monthlyProductID = "tennique_pro_monthly"
        static let annualProductID = "tennique_pro_annual"
    }

    enum Feedback {
        static let minSessionsBeforePrompt = 2
        static let minSessionsBeforeRatingPrompt = 3
    }
}
