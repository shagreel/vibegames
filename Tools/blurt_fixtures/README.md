# Blurt fixtures

Dumps what the **Swift** engine does, so the TypeScript port can be checked
against it rather than assumed to match.

This matters because a Vibe Blurt room stores a seed and a turn number and
nothing else about the words — every device derives the same deck from the seed.
If the browser shuffled to a different order than the phone, the describer would
be describing one thing and every other screen would be scoring another, which
would look like a rules bug rather than a determinism bug.

It also pins the **timing model**, which is not about words at all. A round is a
random 50–70 seconds and the last 15% is signalled by a tick that hurries and a
bar that pulses; both are driven from `BlurtTiming`. If the two platforms
disagreed about when the hurry starts, it would look like a bug in whichever one
the player was not holding.

And it pins **who is holding the word** (`holders`), which is derived rather than
written down: the named describer while they are in the room, and the rotation's
choice among the people still there once they have gone. If the two disagreed, one
platform would be showing the word to somebody the other platform is not watching.

Regenerate after changing `BlurtWords.swift`, `BlurtPack.swift`, a file in
`Packs/`, `BlurtEngine.swift` or `SeededGenerator.swift`:

    rm -rf /tmp/blurtfix && mkdir -p /tmp/blurtfix
    cp Sources/Model/SeededGenerator.swift \
       Sources/Features/VibeBlurt/BlurtWords.swift \
       Sources/Features/VibeBlurt/BlurtPack.swift \
       Sources/Features/VibeBlurt/BlurtEngine.swift \
       Sources/Features/VibeBlurt/Packs/*.swift /tmp/blurtfix/
    cp Tools/blurt_fixtures/main.swift /tmp/blurtfix/
    swiftc -O /tmp/blurtfix/*.swift -o /tmp/blurtfix/dump
    /tmp/blurtfix/dump > web/src/games/blurt/engine.fixtures.json

`web/src/test/blurtEngine.test.ts` fails if the two ever disagree.

The timing values are deliberately kept in `Double` on both sides, and converted
to `Float` only where a sound is played, so that the fixtures can be compared
exactly rather than within a tolerance.
