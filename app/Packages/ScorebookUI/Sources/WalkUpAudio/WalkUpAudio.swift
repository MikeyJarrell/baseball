// WalkUpAudio: the song library, walk-up songs, the stadium announcer and between-innings music.
//
// Placeholder written by the foundation job so the module exists and builds.
// The audio builder replaces this file with a type that adopts the `WalkUpAudioPlayer`
// protocol from Model (see plan/briefs/walk-up-audio.md). That protocol runs on the main
// thread, so the real player is a `@MainActor` class.

import Model
