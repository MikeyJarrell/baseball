# BoxScorePicture resources

Files bundled with the BoxScorePicture module, such as an asset catalog or a sound. Read them in code through `Bundle.module`.

- `sample-game-box-score.json` and `sample-game-through-three-box-score.json`: copies of the sample game’s box scores, for the previews in `Previews.swift`, since this module may not use `SampleData`. The test `PreviewFixtureTests` in `ScorebookCore/Tests/BoxScoreTextTests` checks they still match and explains how to rewrite them.
