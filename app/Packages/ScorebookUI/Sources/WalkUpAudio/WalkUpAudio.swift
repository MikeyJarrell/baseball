// WalkUpAudio: the song library, walk-up songs, the stadium announcer and pitchers'
// warm-up songs.
//
// The files in this folder:
// - StadiumAudioPlayer.swift: the player itself, the real version of Model's
//   `WalkUpAudioPlayer` promise. The app makes one and shares it.
// - AudioGraph.swift: the chain of sound pieces inside the player, including the stadium
//   echo on announcer introductions.
// - AnnouncerVoice.swift: the phone's speech voice reading “Now batting, number two,
//   Derek Jeter. Number two.”
// - SoundFileImporter.swift: copying song and introduction files in from the Files app,
//   iCloud Drive included.
// - WalkUpAudioTestScreen.swift and TestSongMaker.swift: a workbench screen, with made-up
//   test songs, for checking every sound before the batting screen exists.
//
// Setting it up in the app shell (details in plan/handoffs/walk-up-audio.md):
//
//     let audio = StadiumAudioPlayer(audioFolder: storage.audioFolder,
//                                    library: try await storage.loadSongLibrary())
//     audio.walkUpLength = settings.walkUpSongSeconds
//     audio.onLibraryChanged = { library in Task { try await storage.saveSongLibrary(library) } }

import Model
