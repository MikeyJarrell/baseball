# Teams and songs screens

**Role:** screen builder.

**Waits on:** foundation; mockup approval. Needs Xcode.

**Owns:** `ScorebookUI/Sources/TeamScreens/`.

**Reads:** `Model/`, `SampleData/`, `DesignSystem/`, the approved mockups.

## Deliver

1. **Teams list:** our team at the top, opponents below, add and rename.
2. **Roster:** add, edit and remove players with name, number, batting side and throwing hand. Quick entry for a whole roster in a row.
3. **Song library:** every imported song, an import button, rename, a volume level per song, and a way to set the start point by listening. The import button opens the iPhone’s file picker and hands back the chosen files; the audio builder’s code copies them in. The screen is handed the song list and hands back requests (import these files, play preview, set start point); the audio itself is the audio builder’s.
4. **Song assignment:** from a player, pick a song; from a song, see who has it.
5. **Announcer introduction:** on each player’s page, a record button (record, listen, keep or redo), plus import a recording or use the phone’s voice, with a test button that plays the introduction and song together.
6. **Warm-up song:** on each player’s page, a warm-up song for when they pitch.

## Finish line

Previews with the `SampleData` teams, a song library of fifteen songs, and an empty team. Entering a twelve-player roster takes under three minutes in the simulator.
