// Tests for the song fading in under the announcer, the way stadiums do it: the song starts
// with the introduction, plays quietly under the voice until the announcer has finished, then
// rises to full volume, reaching it at its start point (the hook).

import Testing
@testable import WalkUpAudio

@Suite("The song fading in under the announcer")
struct FadeInTests {

    @Test("A 4-second introduction and a hook at 0:20: the song starts at 0:14.5 and the walk-up lasts 17.5 seconds")
    func usualLayout() {
        let plan = WalkUpMath.walkUpPlan(startPoint: 20, introductionLength: 4, songLength: 12)
        #expect(plan.startsAt == 14.5)
        // Full volume a second and a half after the announcer finishes.
        #expect(plan.fullVolumeAfter == 5.5)
        #expect(plan.totalLength == 17.5)
        // Where the song is when it reaches full volume: exactly the hook.
        #expect(plan.startsAt + plan.fullVolumeAfter == 20)
    }

    @Test("A song wanted from the very top starts at 0:00 and still fades in over the introduction")
    func hookNearTheTop() {
        let plan = WalkUpMath.walkUpPlan(startPoint: 1.5, introductionLength: 4, songLength: 12)
        #expect(plan.startsAt == 0)
        #expect(plan.fullVolumeAfter == 5.5)
        #expect(plan.totalLength == 17.5)
    }

    @Test("With no introduction the song starts at its start point, and plays the usual 12 seconds")
    func noIntroduction() {
        let plan = WalkUpMath.walkUpPlan(startPoint: 20, introductionLength: 0, songLength: 12)
        #expect(plan == WalkUpMath.WalkUpPlan(startsAt: 20, fullVolumeAfter: 0, totalLength: 12))
    }

    @Test("Under a 4-second introduction: silent at first, a third until the announcer is done, then full")
    func volumeUnderTheVoice() {
        let volume = { (t: Double) in WalkUpMath.fadeInVolume(elapsed: t, introductionLength: 4) }
        #expect(volume(0) == 0)
        #expect(volume(1) > 0 && volume(1) < 0.33)          // still rising gently
        #expect(volume(2) == 0.33)                            // a third, under the voice
        #expect(volume(3.5) == 0.33)                          // still a third over the end of the name
        #expect(volume(4) == 0.33)                            // the announcer finishes: the rise begins
        #expect(volume(4.75) > 0.33 && volume(4.75) < 1)    // rising, after the voice
        #expect(volume(5.5) == 1)                             // full a second and a half later
        #expect(volume(9) == 1)
    }

    @Test("The song never gets louder than a third while the announcer is speaking")
    func quietUnderTheWholeIntroduction() {
        for length in [0.4, 1.0, 2.5, 4.0, 7.5] {
            for step in 0...200 {
                let v = WalkUpMath.fadeInVolume(elapsed: length * Double(step) / 200, introductionLength: length)
                #expect(v <= WalkUpMath.underVoiceLevel, "too loud at step \(step) of a \(length)-second introduction")
            }
        }
    }

    @Test("The volume only ever goes up while it fades in")
    func neverDips() {
        for length in [0.4, 1.0, 2.5, 4.0, 7.5] {
            let whole = length + WalkUpMath.finalRiseLength
            var last: Float = 0
            for step in 0...200 {
                let v = WalkUpMath.fadeInVolume(elapsed: whole * Double(step) / 200, introductionLength: length)
                #expect(v >= last - 0.0001, "dipped at step \(step) of a \(length)-second introduction")
                last = v
            }
            #expect(last == 1)
        }
    }

    @Test("With no introduction the song is at full volume from the start")
    func noIntroductionIsFullVolume() {
        #expect(WalkUpMath.fadeInVolume(elapsed: 0, introductionLength: 0) == 1)
    }

    @Test("The countdown covers the whole walk-up: introduction, rise and song together")
    func countdownOverTheWholeWalkUp() {
        let plan = WalkUpMath.walkUpPlan(startPoint: 20, introductionLength: 4, songLength: 12)
        #expect(WalkUpMath.secondsLeft(now: 0, songStart: 0, songLength: plan.totalLength) == 17.5)
        #expect(WalkUpMath.secondsLeft(now: 5.5, songStart: 0, songLength: plan.totalLength) == 12)
        // The automatic fade begins 2 seconds before the end: 10 seconds after the hook.
        #expect(WalkUpMath.fadeBegins(songLength: plan.totalLength, fadeLength: 2) == 15.5)
    }

    @Test("A fade that is called off comes back to full volume from where it had got to")
    func comingBackFromAFade() {
        #expect(WalkUpMath.comeBackVolume(progress: 0, startingFrom: 0.25) == 0.25)
        #expect(WalkUpMath.comeBackVolume(progress: 0.5, startingFrom: 0.25) == 0.625)
        #expect(WalkUpMath.comeBackVolume(progress: 1, startingFrom: 0.25) == 1)
        #expect(WalkUpMath.comeBackVolume(progress: 4, startingFrom: 0.25) == 1)
    }
}
