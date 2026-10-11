# Blurt fixtures

Dumps what the **Swift** engine does, so the TypeScript port can be checked
against it rather than assumed to match.

This matters because a Vibe Blurt room stores a seed and a turn number and
nothing else about the words — every device derives the same deck from the seed.
If the browser shuffled to a different order than the phone, the describer would
be describing one thing and every other screen would be scoring another, which
would look like a rules bug rather than a determinism bug.

Regenerate after changing `BlurtWords.swift`, `BlurtEngine.swift` or
`SeededGenerator.swift`:

    mkdir -p /tmp/blurtfix
    cp Sources/Model/SeededGenerator.swift \
       Sources/Features/VibeBlurt/BlurtWords.swift \
       Sources/Features/VibeBlurt/BlurtEngine.swift /tmp/blurtfix/
    cp Tools/blurt_fixtures/main.swift /tmp/blurtfix/
    swiftc -O /tmp/blurtfix/*.swift -o /tmp/blurtfix/dump
    /tmp/blurtfix/dump > web/src/games/blurt/engine.fixtures.json

`web/src/test/blurtEngine.test.ts` fails if the two ever disagree.
