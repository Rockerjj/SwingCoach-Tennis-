import Foundation

final class FeedbackService {
    static let shared = FeedbackService()
    private init() {}

    func submitFeedback(userID: String?, rating: Int, comment: String) async {
        guard let url = URL(string: "\(AppConstants.API.baseURL)/feedback") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "user_id": userID ?? "anonymous",
            "rating": rating,
            "comment": comment,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            "device_model": UIDevice.current.model,
            "ios_version": UIDevice.current.systemVersion,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                // Success
            }
        } catch {
            UserDefaults.standard.set(
                try? JSONSerialization.data(withJSONObject: payload),
                forKey: "pending_feedback"
            )
        }
    }
}
