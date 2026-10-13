# Trio fixtures

Dumps what the **Swift** engine does, so the TypeScript port can be checked
against it rather than assumed to match.

This matters because a shared Vibe Pairings game sends a seed and a list of taken
cards, and nothing else — every device rebuilds the board from those. If the
browser shuffled to a different order than the phone for the same seed, two
players in the same game would be looking at different tables, and it would look
like a rendering bug rather than a determinism bug.

Regenerate after changing anything in `TrioCard.swift`, `TrioEngine.swift` or
`SeededGenerator.swift`:

    mkdir -p /tmp/triofix
    cp Sources/Model/SeededGenerator.swift \
       Sources/Features/VibeTrio/TrioCard.swift \
       Sources/Features/VibeTrio/TrioEngine.swift /tmp/triofix/
    cp Tools/trio_fixtures/main.swift /tmp/triofix/
    swiftc -O /tmp/triofix/*.swift -o /tmp/triofix/dump
    /tmp/triofix/dump > web/src/games/trio/engine.fixtures.json

`web/src/test/trioEngine.test.ts` fails if the two ever disagree.
