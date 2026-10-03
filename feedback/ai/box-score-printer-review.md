# Box score printer: review

**Reviewer:** a fresh builder who did not build this job, reviewing `git diff origin/main...HEAD` (one commit, 51fc553).

**Verdict:** Accept after two quick decisions from Mikey (findings 1 and 2). Every number is right and on the right player and team, the finish line is met, and nothing outside the job’s three folders and its handoff changed.

## What was checked

- `swift test` in `app/Packages/ScorebookCore`: 58 tests, all passing (17 new).
- `xcodebuild -scheme ScorebookUI-Package -destination 'platform=iOS Simulator,name=iPhone 17' build`: succeeded.
- The sample picture (`plan/handoffs/box-score-printer-sample.png`), line by line against `SampleData/SampleBoxScore.swift`: all 22 batting lines, both totals rows, the line score and runs, hits and errors, all eleven notes, all four pitching lines (outs turned into innings), the hit-by-pitch note and all four pitch counts match. The totals also add up from the batters, and the pitchers’ hits, runs, walks and strikeouts match the other team’s batting.
- Finish line: the character-for-character test exists and passes; nine and fourteen hitters are tested; light and dark previews exist; the picture’s paper and ink colors are fixed.

## Findings, worst first

1. `ScorebookCore/Sources/BoxScoreText/BoxScorePrinter.swift:79-84`. Any starter who bats but does not field prints as “dh”. In the sample game Cole bats tenth while the pitcher, Barros, also bats, so Cole is an extra hitter. A designated hitter bats in the pitcher’s place, and here the pitcher bats too. With fourteen hitters, five players print “dh”. Fix: print “eh” for a batting-only starter when the team’s pitcher also has a batting line, and “dh” otherwise. Mikey’s call on the label.
2. `BoxScorePrinter.swift:178-185`. Innings pitched print as “4⅓”. This review was asked to check for the “4.1” style. Old newspapers printed “4 1-3” or “4⅓”; modern box scores print “4.1”. Either is defensible, so Mikey should pick. Changing it is a one-line edit to the list of endings, plus the test at `LayoutTests.swift:143`.
3. `ScorebookUI/Sources/BoxScorePicture/Resources/*.json`. 50 KB of copied sample data ships inside the app, and it duplicates `SampleData`, which ships anyway because every screen uses it. No cleaner fix exists inside this job’s folders: Swift packages cannot leave resource files out of the finished app, and the app shell, the only place allowed to use both, belongs to the wiring job. The right fix is the handoff’s first request: the lead builder adds `SampleData` to `BoxScorePicture` in `ScorebookUI/Package.swift`, then deletes both JSON files, `PreviewFixtureTests.swift` and the line in `Resources/README.md`. If that is refused, saving the copies without the extra spaces cuts them to 24 KB.
4. `BoxScorePrinter.swift:194`. A pitcher whose pitches were not counted is silently left out of “Pitches-strikes”, which reads as if he did not pitch. Fix: drop the whole note unless every pitcher has a count, or leave it as is and note the choice in a comment.
5. `ScorebookCore/Sources/BoxScoreText/ShortNames.swift:112`. A last name of more than one word is cut to its final word: “Elly De La Cruz” prints “Cruz”. Fix: keep lowercase name particles (de, la, del, van, von, da, di) with the last name.
6. `ScorebookUI/Sources/BoxScorePicture/BoxScorePicture.swift:181-184`. The line score’s runs, hits and errors sit in 24-point columns while the batting numbers above use 30-point columns, so they almost line up but not quite (visible in the sample picture). Fix: use `Newsprint.columnWidth` for these three.
7. `ScorebookCore/Sources/BoxScoreText/NewspaperBoxScore.swift:12`. The comment’s example date has a year (“Saturday, May 2, 2026”); the printer prints none. Fix the example.
8. Not a defect in this job: newspapers tag pinch hitters with a letter and a footnote (“a-struck out for Collins in the 4th”). `BoxScore` has nothing to print that from. Worth adding to the handoff’s list of requests for the lead builder.

Comments are plain and readable throughout, and the tests check the baseball itself: totals adding up, notes order, shared last names, a ten-run inning.
