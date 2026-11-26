import Foundation

/// Notes that have not reached the feedback inbox yet.
///
/// The send used to be one `setValue` from the sheet. If it did not reach the
/// server, the note lived only in the view's state: dismissing the sheet, losing
/// the connection for good, or the app being killed lost it. A note is now
/// written to disk before the first attempt, and every attempt uses the note's
/// own id as the database key, so a retry after an acknowledgement that never
/// arrived cannot create a second copy.
///
/// The file is deliberately in Application Support rather than `UserDefaults`:
/// it is data, not a preference, and it should not be reset by anything that
/// clears preferences.
actor FeedbackOutbox {

    struct Note: Codable, Equatable, Identifiable, Sendable {
        let id: String
        let text: String
        let source: String
        let game: String?
        let createdAt: Int
    }

    static let shared = FeedbackOutbox()

    private let fileURL: URL
    private var notes: [Note]

    init(fileURL: URL? = nil) {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory,
                                                 in: .userDomainMask)[0]
            .appendingPathComponent("Feedback", isDirectory: true)
        let url = fileURL ?? directory.appendingPathComponent("outbox.json")
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        self.fileURL = url
        self.notes = (try? Data(contentsOf: url))
            .flatMap { try? JSONDecoder().decode([Note].self, from: $0) } ?? []
    }

    var pending: [Note] { notes }

    /// Saves the note before anybody tries to send it.
    @discardableResult
    func enqueue(text: String, source: String, game: String?) throws -> Note {
        let note = Note(id: UUID().uuidString,
                        text: text,
                        source: source,
                        game: game,
                        createdAt: Int(Date().timeIntervalSince1970 * 1000))
        notes.append(note)
        try save()
        return note
    }

    /// Sends in order, stopping at the first failure so a newer note cannot
    /// overtake an older one. Returns the ids that reached the server.
    func flush(send: (Note) async throws -> Void) async -> Set<String> {
        var delivered: Set<String> = []
        for note in notes {
            do {
                try await send(note)
                delivered.insert(note.id)
                notes.removeAll { $0.id == note.id }
                try? save()
            } catch {
                break
            }
        }
        return delivered
    }

    /// For a note the sender knows is already on the server.
    func remove(_ id: String) {
        notes.removeAll { $0.id == id }
        try? save()
    }

    private func save() throws {
        try JSONEncoder().encode(notes).write(to: fileURL, options: .atomic)
    }
}
