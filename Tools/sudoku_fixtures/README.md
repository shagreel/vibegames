# Sudoku fixtures

Dumps what the **Swift** Sudoku engine generates, so the TypeScript port can be
checked against it rather than assumed to match.

This matters because a shared Vibe Sudoku race sends a seed and a difficulty, and
nothing else — both devices generate the board from those. The generator carves
clues away one at a time, checking uniqueness after each removal and re-grading
as it goes, so a single difference anywhere changes which clue is removed next
and the two players end up racing different boards.

Regenerate after changing anything in `SudokuPuzzle.swift`,
`SudokuGenerator.swift`, `SudokuGrader.swift` or `SeededGenerator.swift`:

    mkdir -p /tmp/sudokufix
    cp Sources/Model/SeededGenerator.swift \
       Sources/Features/VibeSudoku/SudokuPuzzle.swift \
       Sources/Features/VibeSudoku/SudokuGrader.swift \
       Sources/Features/VibeSudoku/SudokuGenerator.swift \
       Tools/sudoku_fixtures/main.swift /tmp/sudokufix/
    swiftc -O /tmp/sudokufix/*.swift -o /tmp/sudokufix/dump
    /tmp/sudokufix/dump > web/src/games/sudoku/generator.fixtures.json

`web/src/test/sudokuGenerator.test.ts` fails if the two ever disagree.

The fixture also carries the grader's verdict and the clue count, so a port that
produced the right grid by luck would still have to grade it the same way.
