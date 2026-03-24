import Foundation

struct TrainLogEntry: Codable, Identifiable {
    var id = UUID()
    let timestamp: Date
    let speed: Double
    let voltage: Double
    let current: Double
    let pressure: Double
}

class TrainDataService {
    static let shared = TrainDataService()
    
    private var activeSessions: [UUID: [TrainLogEntry]] = [:]
    
    // In a real app, we'd save to disk. For this simulator, in-memory is fine for the session,
    // but the request asked for "archive". Let's simulate saving to Documents.
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func getArchiveURL(for trainId: UUID) -> URL {
        getDocumentsDirectory().appendingPathComponent("train_history_\(trainId.uuidString).json")
    }
    
    func logData(train: Train) {
        let entry = TrainLogEntry(
            timestamp: Date(),
            speed: Double(train.speed),
            voltage: train.mainVoltage,
            current: train.tractionCurrent,
            pressure: train.compressorPressure
        )
        
        if activeSessions[train.id] == nil {
            // Try load existing
            activeSessions[train.id] = loadHistory(for: train.id)
        }
        
        activeSessions[train.id]?.append(entry)
        
        // Save every N entries or just save periodically? 
        // For simplicity, save on stop or just let it be in memory until requested?
        // Let's save every 10 entries to avoid IO thrashing but ensure persistence.
        if (activeSessions[train.id]?.count ?? 0) % 10 == 0 {
            saveHistory(for: train.id)
        }
    }
    
    func startRecording(trainId: UUID) {
        if activeSessions[trainId] == nil {
            activeSessions[trainId] = loadHistory(for: trainId)
        }
    }
    
    func stopRecording(trainId: UUID) {
        saveHistory(for: trainId)
    }
    
    func getHistory(trainId: UUID) -> [TrainLogEntry] {
        if let session = activeSessions[trainId] {
            return session
        }
        return loadHistory(for: trainId)
    }
    
    private func saveHistory(for trainId: UUID) {
        guard let data = activeSessions[trainId] else { return }
        let url = getArchiveURL(for: trainId)
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: url)
        } catch {
            print("Failed to save history for \(trainId): \(error)")
        }
    }
    
    private func loadHistory(for trainId: UUID) -> [TrainLogEntry] {
        let url = getArchiveURL(for: trainId)
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([TrainLogEntry].self, from: data)
        } catch {
            return []
        }
    }
    
    // Clear history
    func clearHistory(for trainId: UUID) {
        activeSessions[trainId] = []
        let url = getArchiveURL(for: trainId)
        try? FileManager.default.removeItem(at: url)
    }
}
