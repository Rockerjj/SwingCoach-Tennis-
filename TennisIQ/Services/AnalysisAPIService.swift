import Foundation
import UIKit

/// Handles communication with the cloud analysis API
final class AnalysisAPIService {
    private let session: URLSession
    private let baseURL: String

    init(session: URLSession = .shared) {
        self.session = session
        #if DEBUG
        self.baseURL = AppConstants.API.debugBaseURL
        #else
        self.baseURL = AppConstants.API.baseURL
        #endif
    }

    enum APIError: LocalizedError {
        case invalidURL
        case uploadFailed(String)
        case analysisFailed(String)
        case decodingFailed
        case unauthorized

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid API URL."
            case .uploadFailed(let msg): return "Upload failed: \(msg)"
            case .analysisFailed(let msg): return "Analysis failed: \(msg)"
            case .decodingFailed: return "Failed to decode analysis response."
            case .unauthorized: return "Please sign in to continue."
            }
        }
    }

    // MARK: - Submit Session for Analysis

    func analyzeSession(
        posePayload: SessionPosePayload,
        keyFrameImages: [(timestamp: Double, image: UIImage)],
        strokeClips: [(timestamp: Double, url: URL)] = [],
        authToken: String
    ) async throws -> AnalysisResponse {
        guard let url = URL(string: "\(baseURL)/sessions/analyze") else {
            throw APIError.invalidURL
        }

        // Build multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        // Long sessions can take a while between upload + LLM analysis.
        request.timeoutInterval = 300

        var body = Data()

        // Pose data JSON
        let poseJSON = try JSONEncoder().encode(posePayload)
        body.appendMultipart(boundary: boundary, name: "pose_data", filename: "pose.json", mimeType: "application/json", data: poseJSON)

        // Key frame images
        for (index, keyFrame) in keyFrameImages.enumerated() {
            guard let jpegData = keyFrame.image.jpegData(compressionQuality: 0.7) else { continue }
            body.appendMultipart(
                boundary: boundary,
                name: "key_frame_\(index)",
                filename: "frame_\(index)_\(String(format: "%.2f", keyFrame.timestamp)).jpg",
                mimeType: "image/jpeg",
                data: jpegData
            )
        }

        // Video clips for Gemini analysis
        for (index, clip) in strokeClips.enumerated() {
            if let clipData = try? Data(contentsOf: clip.url) {
                let filename = clip.url.lastPathComponent
                body.appendMultipart(
                    boundary: boundary,
                    name: "stroke_clip_\(index)",
                    filename: filename,
                    mimeType: "video/mp4",
                    data: clipData
                )
            }
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.analysisFailed("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try JSONDecoder().decode(AnalysisResponse.self, from: data)
            } catch {
                throw APIError.decodingFailed
            }
        case 401:
            throw APIError.unauthorized
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.analysisFailed(message)
        }
    }

    // MARK: - Fetch Session History

    func fetchSessions(authToken: String) async throws -> [SessionSummary] {
        guard let url = URL(string: "\(baseURL)/sessions") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode([SessionSummary].self, from: data)
    }

    // MARK: - Fetch Progress

    func fetchProgress(authToken: String) async throws -> ProgressData {
        guard let url = URL(string: "\(baseURL)/progress") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.analysisFailed("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200...299:
            return try JSONDecoder().decode(ProgressData.self, from: data)
        case 401:
            throw APIError.unauthorized
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.analysisFailed(message)
        }
    }
}

// MARK: - API Response Types

struct SessionSummary: Codable, Identifiable {
    let id: String
    let recordedAt: String
    let durationSeconds: Int
    let overallGrade: String?
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case recordedAt = "recorded_at"
        case durationSeconds = "duration_seconds"
        case overallGrade = "overall_grade"
        case status
    }
}

struct ProgressData: Codable {
    let overallScore: Double
    let forehandScore: Double
    let backhandScore: Double
    let serveScore: Double
    let volleyScore: Double
    let trend: String
    let weeklyFocus: String
    let sessionsThisWeek: Int
    let sessionsThisMonth: Int
    let history: [ProgressPoint]

    enum CodingKeys: String, CodingKey {
        case overallScore = "overall_score"
        case forehandScore = "forehand_score"
        case backhandScore = "backhand_score"
        case serveScore = "serve_score"
        case volleyScore = "volley_score"
        case trend
        case weeklyFocus = "weekly_focus"
        case sessionsThisWeek = "sessions_this_week"
        case sessionsThisMonth = "sessions_this_month"
        case history
    }
}

struct ProgressPoint: Codable, Identifiable {
    var id: String { date }
    let date: String
    let score: Double
}

// MARK: - Multipart Helper

extension Data {
    mutating func appendMultipart(boundary: String, name: String, filename: String, mimeType: String, data: Data) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }
}
