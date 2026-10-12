import XCTest
import UIKit
@testable import VibeGames

/// Covers the rules of the word game and the shape of the shared payload.
final class WordGameEngineTests: XCTestCase {

    // MARK: - Basic scoring

    func testExactMatchIsAllCorrect() {
        let result = WordGameEngine.score(guess: "CRANE", answer: "CRANE")
        XCTAssertEqual(result, Array(repeating: .correct, count: 5))
    }

    func testAnagramIsAllPresent() {
        let result = WordGameEngine.score(guess: "NACRE", answer: "CRANE")
        XCTAssertEqual(result, [.present, .present, .present, .present, .correct])
    }

    func testUnrelatedWordIsAllAbsent() {
        let result = WordGameEngine.score(guess: "BOOBY", answer: "CRANE")
        XCTAssertEqual(result, Array(repeating: .absent, count: 5))
    }

    func testMixedPositions() {
        // C R A N E
        // C R A T E  -> first three and last are correct, N/T swapped
        let result = WordGameEngine.score(guess: "CRATE", answer: "CRANE")
        XCTAssertEqual(result, [.correct, .correct, .correct, .absent, .correct])
    }

    // MARK: - Repeated letters
    //
    // These are the cases a naive implementation gets wrong, and they are the
    // reason the scoring uses two passes rather than a simple containment check.

    func testRepeatedLetterInGuessIsCreditedOnlyOnce() {
        // Answer has one E (at the end) and the guess has three.
        let result = WordGameEngine.score(guess: "EERIE", answer: "CRANE")
        XCTAssertEqual(result, [.absent, .absent, .present, .absent, .correct],
                       "Only the exactly-placed E should be credited, plus the R")
    }

    func testRepeatedLetterInAnswerIsCreditedOncePerOccurrence() {
        // S P E E D has two Es; the guess has three.
        let result = WordGameEngine.score(guess: "EERIE", answer: "SPEED")
        XCTAssertEqual(result, [.present, .present, .absent, .absent, .absent],
                       "Two Es are available, so the third must be absent")
    }

    func testExactMatchConsumesBeforePresentMatch() {
        // The E in position 4 is exact, so it must not be double-counted.
        let result = WordGameEngine.score(guess: "EERIE", answer: "SPEED")
        XCTAssertEqual(result.filter { $0 == .correct }.count, 0)
        XCTAssertEqual(result.filter { $0 == .present }.count, 2)
    }

    func testRepeatedLettersAbsentWhenNoneAreInTheAnswer() {
        // F, L and U do not appear in CRANE at all, so every tile is absent.
        let result = WordGameEngine.score(guess: "FLUFF", answer: "CRANE")
        XCTAssertEqual(result, Array(repeating: .absent, count: 5))
    }

    func testRepeatedLetterAbsentWhileADifferentLetterIsPresent() {
        // SASSY: the doubled S is absent, but the single A is in CRANE.
        let result = WordGameEngine.score(guess: "SASSY", answer: "CRANE")
        XCTAssertEqual(result, [.absent, .present, .absent, .absent, .absent])
    }

    func testGuessWithMoreCopiesThanAnswer() {
        // A B B E Y has two Bs; the guess has three.
        let result = WordGameEngine.score(guess: "BOBBY", answer: "ABBEY")
        // B(0) present, O absent, B(2) correct, B(3) absent (pool exhausted), Y correct
        XCTAssertEqual(result, [.present, .absent, .correct, .absent, .correct])
    }

    func testMismatchedLengthsReturnNothing() {
        XCTAssertTrue(WordGameEngine.score(guess: "TOOLONG", answer: "CRANE").isEmpty)
        XCTAssertTrue(WordGameEngine.score(guess: "", answer: "").isEmpty)
    }

    // MARK: - Keyboard feedback

    func testKeyboardPrefersCorrectOverPresent() {
        // E is present in ZEBRA but correct in CRANE.
        let state = WordGameEngine.keyboardFeedback(for: "E",
                                                    guesses: ["ZEBRA", "CRANE"],
                                                    answer: "CRANE")
        XCTAssertEqual(state, .correct)
    }

    func testKeyboardPrefersPresentOverAbsent() {
        let state = WordGameEngine.keyboardFeedback(for: "A",
                                                    guesses: ["BOOBY", "ZEBRA"],
                                                    answer: "CRANE")
        XCTAssertEqual(state, .present)
    }

    func testKeyboardIsNilForUnguessedLetters() {
        XCTAssertNil(WordGameEngine.keyboardFeedback(for: "Q", guesses: ["CRANE"], answer: "CRANE"))
    }

    func testKeyboardMarksAbsentLetters() {
        let state = WordGameEngine.keyboardFeedback(for: "Z",
                                                    guesses: ["ZEBRA"],
                                                    answer: "CRANE")
        XCTAssertEqual(state, .absent)
    }

    func testTheSymbolKeysResolveToRealSymbols() {
        // The return and delete keys are drawn as SF Symbols. A symbol name that
        // does not exist draws *nothing at all* — no error, no placeholder — so
        // a typo would ship a blank key and the game would look broken rather
        // than fail. The names are checked against the system instead.
        for name in ["return", "delete.left.fill"] {
            XCTAssertNotNil(UIImage(systemName: name), "\(name) is not a symbol on this iOS")
        }
    }

    // MARK: - Validation

    func testTooShortGuessIsRejected() {
        XCTAssertEqual(WordGameEngine.validate("CAT", against: ["CAT"]), .tooShort)
    }

    func testUnknownWordIsRejected() {
        XCTAssertEqual(WordGameEngine.validate("ZZZZZ", against: ["CRANE"]), .notAWord)
    }

    func testKnownWordPasses() {
        XCTAssertNil(WordGameEngine.validate("crane", against: ["CRANE"]))
    }

    // MARK: - Dictionary

    func testWordListsLoadFromTheBundle() {
        XCTAssertTrue(WordLists.isLoaded, "Bundled word lists should load")
        XCTAssertEqual(WordLists.valid.count, 14_855)
        XCTAssertEqual(WordLists.answers.count, 489)
    }

    func testEveryEntryIsFiveUppercaseLetters() {
        let malformed = WordLists.valid.filter { $0.count != 5 || $0 != $0.uppercased() }
        XCTAssertTrue(malformed.isEmpty, "Unexpected entries: \(malformed.prefix(5))")
    }

    func testAnswersAreGuessable() {
        let unplayable = WordLists.answers.filter { !WordLists.valid.contains($0) }
        XCTAssertTrue(unplayable.isEmpty, "Answers missing from valid list: \(unplayable.prefix(5))")
    }

    func testRandomAnswerIsAlwaysPlayable() {
        for _ in 0..<200 {
            let word = WordLists.randomAnswer()
            XCTAssertEqual(word.count, 5)
            XCTAssertTrue(WordLists.isPlayable(word))
        }
    }
}

/// Locks the shared Realtime Database shape so the iOS and web clients keep
/// agreeing about what a game looks like.
final class GameSnapshotTests: XCTestCase {

    private let payload: [String: Any] = [
        "word": "CRANE",
        "creator": "Alex",
        "createdAt": 1_737_052_800_000,
        "started": true,
        "winner": ["name": "Sam", "timestamp": 1_737_052_810_000],
        "restartTime": 1_737_052_820_000,
        "players": [
            "p2": ["name": "Sam", "joinedAt": 1_737_052_805_000],
            "p1": ["name": "Alex", "joinedAt": 1_737_052_800_000]
        ]
    ]

    func testParsesTheWebClientPayload() {
        let snapshot = GameSnapshot(rawValue: payload)

        XCTAssertTrue(snapshot.exists)
        XCTAssertEqual(snapshot.word, "CRANE")
        XCTAssertEqual(snapshot.creator, "Alex")
        XCTAssertTrue(snapshot.started)
        XCTAssertEqual(snapshot.winner?.name, "Sam")
        XCTAssertEqual(snapshot.players.count, 2)
    }

    func testPlayersAreOrderedByJoinTime() {
        let snapshot = GameSnapshot(rawValue: payload)
        XCTAssertEqual(snapshot.players.map(\.name), ["Alex", "Sam"])
    }

    func testMillisecondsAreConvertedToDates() {
        let snapshot = GameSnapshot(rawValue: payload)
        XCTAssertEqual(snapshot.winner?.timestamp.timeIntervalSince1970 ?? 0,
                       1_737_052_810, accuracy: 0.001)
        XCTAssertEqual(snapshot.restartTime?.timeIntervalSince1970 ?? 0,
                       1_737_052_820, accuracy: 0.001)
    }

    func testMissingWordIsTolerated() {
        let snapshot = GameSnapshot(rawValue: ["creator": "Alex", "started": false])
        XCTAssertTrue(snapshot.exists)
        XCTAssertNil(snapshot.word)
        XCTAssertFalse(snapshot.started)
    }

    func testMalformedWordIsIgnored() {
        let snapshot = GameSnapshot(rawValue: ["word": "TOOLONG"])
        XCTAssertNil(snapshot.word)
    }

    func testEmptyValueMeansTheGameDoesNotExist() {
        XCTAssertFalse(GameSnapshot(rawValue: nil).exists)
        XCTAssertFalse(GameSnapshot(rawValue: "nonsense").exists)
    }
}

/// Game codes and the optional-backend behaviour.
final class VibeWordsModelTests: XCTestCase {

    /// Configuration is optional: solo play must work either way. This asserts
    /// the app's state matches whether a config file is actually bundled, so it
    /// stays meaningful both before and after Firebase is set up.
    func testBackendConfigurationMatchesTheBundledConfigFile() {
        let hasConfigFile = Bundle.main
            .path(forResource: "GoogleService-Info", ofType: "plist") != nil

        XCTAssertEqual(FirebaseBootstrapper.isConfigured, hasConfigFile)

        if hasConfigFile {
            XCTAssertNotNil(FirebaseBootstrapper.database,
                            "A configured app should expose a database handle")
            XCTAssertNil(FirebaseBootstrapper.unavailableReason)
        } else {
            XCTAssertNil(FirebaseBootstrapper.database)
            XCTAssertNotNil(FirebaseBootstrapper.unavailableReason,
                            "The lobby needs a reason to explain why multiplayer is off")
        }
    }

    /// The database URL has to reach the app, or every shared-game call fails
    /// with an unresolvable host.
    func testConfiguredDatabaseHasARealtimeURL() throws {
        try XCTSkipUnless(FirebaseBootstrapper.isConfigured, "No Firebase config bundled")

        let url = try XCTUnwrap(Bundle.main
            .path(forResource: "GoogleService-Info", ofType: "plist"))
        let plist = try XCTUnwrap(NSDictionary(contentsOfFile: url))
        let databaseURL = try XCTUnwrap(plist["DATABASE_URL"] as? String,
                                        "GoogleService-Info.plist has no DATABASE_URL")

        XCTAssertTrue(databaseURL.hasPrefix("https://"), "Unexpected URL: \(databaseURL)")
        XCTAssertTrue(databaseURL.contains("firebasedatabase.app")
                      || databaseURL.contains("firebaseio.com"),
                      "Unexpected URL: \(databaseURL)")
    }
}
