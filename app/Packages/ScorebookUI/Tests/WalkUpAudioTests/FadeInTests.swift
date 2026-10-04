// Tests for the song fading in under the announcer, the way stadiums do it: the song starts
// with the introduction, plays quietly under the voice, and is at full volume at its start
// point (the hook) just as the announcer finishes.

import Testing
@testable import WalkUpAudio

@Suite("The song fading in under the announcer")
struct FadeInTests {

    @Test("A 4-second introduction and a hook at 0:20: the song starts at 0:16 and the walk-up lasts 16 seconds")
    func usualLayout() {
        let plan = WalkUpMath.walkUpPlan(startPoint: 20, introductionLength: 4, songLength: 12)
        #expect(plan.startsAt == 16)
        #expect(plan.fullVolumeAfter == 4)
        #expect(plan.totalLength == 16)
        // Where the song is when the announcer finishes: exactly the hook.
        #expect(plan.startsAt + plan.fullVolumeAfter == 20)
    }

    @Test("A song wanted from the very top starts at 0:00 and still fades in over the introduction")
    func hookNearTheTop() {
        let plan = WalkUpMath.walkUpPlan(startPoint: 1.5, introductionLength: 4, songLength: 12)
        #expect(plan.startsAt == 0)
        #expect(plan.fullVolumeAfter == 4)
        #expect(plan.totalLength == 16)
    }

    @Test("With no introduction the song starts at its start point, and plays the usual 12 seconds")
    func noIntroduction() {
        let plan = WalkUpMath.walkUpPlan(startPoint: 20, introductionLength: 0, songLength: 12)
        #expect(plan == WalkUpMath.WalkUpPlan(startsAt: 20, fullVolumeAfter: 0, totalLength: 12))
    }

    @Test("Under a 4-second introduction: silent at first, a third under the voice, full at the end")
    func volumeUnderTheVoice() {
        let volume = { (t: Double) in WalkUpMath.fadeInVolume(elapsed: t, introductionLength: 4) }
        #expect(volume(0) == 0)
        #expect(volume(1) > 0 && volume(1) < 0.33)          // still rising gently
        #expect(volume(2) == 0.33)                            // a third, under the voice
        #expect(volume(2.9) == 0.33)
        #expect(volume(3.5) > 0.33 && volume(3.5) < 1)      // the last rise, in the final second
        #expect(volume(4) == 1)                               // full as the announcer finishes
        #expect(volume(9) == 1)
    }

    @Test("The volume only ever goes up while it fades in")
    func neverDips() {
        for length in [0.4, 1.0, 2.5, 4.0, 7.5] {
            var last: Float = 0
            for step in 0...200 {
                let v = WalkUpMath.fadeInVolume(elapsed: length * Double(step) / 200, introductionLength: length)
                #expect(v >= last - 0.0001, "dipped at step \(step) of a \(length)-second introduction")
                last = v
            }
            #expect(last == 1)
        }
    }

    @Test("A very short introduction rises smoothly from silence to full in one go")
    func shortIntroduction() {
        #expect(WalkUpMath.fadeInVolume(elapsed: 0.25, introductionLength: 0.5) == 0.5)
        #expect(WalkUpMath.fadeInVolume(elapsed: 0.5, introductionLength: 0.5) == 1)
    }

    @Test("The countdown covers the whole walk-up: introduction and song together")
    func countdownOverTheWholeWalkUp() {
        let plan = WalkUpMath.walkUpPlan(startPoint: 20, introductionLength: 4, songLength: 12)
        #expect(WalkUpMath.secondsLeft(now: 0, songStart: 0, songLength: plan.totalLength) == 16)
        #expect(WalkUpMath.secondsLeft(now: 4, songStart: 0, songLength: plan.totalLength) == 12)
        // The automatic fade begins 2 seconds before the end: 10 seconds after the hook.
        #expect(WalkUpMath.fadeBegins(songLength: plan.totalLength, fadeLength: 2) == 14)
    }
}
