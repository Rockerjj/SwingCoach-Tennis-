import Foundation

struct ProPlayer: Identifiable {
    let id: String
    let name: String
    let icon: String
    let strokes: [StrokeType]
}

final class ProComparisonService {
    private static let pros: [ProPlayer] = [
        ProPlayer(id: "federer", name: "Federer", icon: "sportscourt", strokes: [.forehand]),
        ProPlayer(id: "djokovic", name: "Djokovic", icon: "trophy", strokes: [.backhand]),
        ProPlayer(id: "serena", name: "Serena", icon: "star.fill", strokes: [.serve])
    ]

    func availablePros(for strokeType: StrokeType) -> [ProPlayer] {
        ProComparisonService.pros.filter { $0.strokes.contains(strokeType) }
    }

    func getProPoseData(proName: String, stroke: StrokeType, phase: SwingPhase) -> [JointData]? {
        let baseName = "\(proName.lowercased())_\(stroke.rawValue)_\(phase.rawValue)"
        guard let url = Bundle.main.url(
            forResource: baseName,
            withExtension: "json",
            subdirectory: "ProPoseData"
        ) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([JointData].self, from: data)
    }
}
