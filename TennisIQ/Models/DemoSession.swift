import Foundation

/// Pre-baked demo analysis data so new users can see the full "wow" experience
/// before they even record a session. Ships with the app bundle.
enum DemoSession {

    // MARK: - Demo Analysis Response

    static let analysisResponse = AnalysisResponse(
        sessionGrade: "B+",
        strokesDetected: [demoForehand, demoBackhand],
        tacticalNotes: [
            "Your forehand is your weapon — the contact point and weight transfer are legit. Build your game around it.",
            "Backhand preparation is the bottleneck. Fix the shoulder turn and everything downstream gets better.",
            "Good habit of split-stepping back to center after shots. That footwork discipline will pay off as you face faster opponents."
        ],
        topPriority: "Get your racket back earlier on every shot. Right now you're rushing your preparation, which compresses your swing and costs you power. Racket should be fully back before the ball bounces on your side.",
        overallMechanicsScore: 74.5,
        sessionSummary: "Solid session — your forehand contact is the real deal and you're moving well between shots. The biggest thing to work on is preparation speed, especially on the backhand side. Get that shoulder turn started earlier and you'll see immediate improvement in power and consistency."
    )

    // MARK: - Demo Forehand

    static let demoForehand = StrokeResult(
        type: .forehand,
        timestamp: 3.2,
        grade: "B+",
        mechanics: StrokeMechanics(
            backswing: MechanicDetail(
                score: 7,
                note: "You're getting the racket back, but it's a beat late. By the time you start your forward swing, you're playing catch-up instead of swinging freely.",
                whyScore: "Late preparation is compressing your swing window and limiting power.",
                improveCue: "Racket back before the bounce.",
                drill: "Rally drill: have your partner feed medium-pace balls. Your ONLY focus is having the racket fully back before the ball bounces. 3 sets of 15.",
                sources: ["USTA Player Development — Forehand Fundamentals"]
            ),
            contactPoint: MechanicDetail(
                score: 8,
                note: "This is your money spot. You're making contact nicely out in front with good extension — keep doing exactly this.",
                whyScore: "Contact position is ahead of the body with near-full arm extension. Textbook.",
                improveCue: "Reach out and meet it early.",
                drill: "Drop-feed drill: self-feed 20 balls, hit each one at the same contact point out front. Consistency is the goal.",
                sources: ["USTA Player Development — Contact Point Guide"]
            ),
            followThrough: MechanicDetail(
                score: 7,
                note: "Good finish over the shoulder, but you're pulling back a touch early. Think about brushing through three balls, not just one.",
                whyScore: "Slight early deceleration is leaving topspin on the table.",
                improveCue: "Swing through the ball, not to it.",
                drill: "Towel drill: hang a towel at contact height, swing through it fully 20 times. Focus on accelerating THROUGH contact.",
                sources: nil
            ),
            stance: MechanicDetail(
                score: 7,
                note: "Nice athletic base with good knee bend. You could load a bit more into your back leg before exploding forward — that's free power.",
                whyScore: "Stance is solid but not fully leveraging ground-force power.",
                improveCue: "Sit into your back hip, then push.",
                drill: "Split step to loaded position: partner feeds, you split step then sit into the back leg before swinging. 3 sets of 10.",
                sources: nil
            ),
            toss: nil
        ),
        overlayInstructions: OverlayInstructions(
            anglesToHighlight: [
                "Elbow: 105° (ideal: 90-120°)",
                "Arm extension: 172° (ideal: 165-180°)",
                "Knee: 148° (ideal: 130-155°)",
                "Shoulder rotation: 72° (ideal: 60-90°)"
            ],
            trajectoryLine: true,
            comparisonGhost: false,
            swingPathPoints: nil,
            swingPlaneAngle: nil,
            pathAnnotations: nil
        ),
        gradingRationale: "Your forehand has a really solid foundation — you're making contact well out in front and your weight transfer is smooth. The main thing holding you back is preparation timing. Get that racket back earlier and you'll have more time to set up, which means more power and better consistency.",
        nextRepsPlan: "This week: 3 basket sessions of 30 forehands. Have your partner yell 'turn' the moment they feed — your racket should be back before the ball bounces on your side. Film one session so we can compare.",
        verifiedSources: ["USTA Player Development", "Tennis Warehouse University"],
        phaseBreakdown: PhaseBreakdown(
            readyPosition: PhaseDetail(
                score: 7, status: .inZone,
                note: "Good athletic stance — knees bent, weight forward on the balls of your feet. You look ready to move.",
                timestamp: 1.8,
                keyAngles: ["Knees nicely bent in athletic position", "Weight shifted forward — good balance"],
                improveCue: "Stay light on your toes between shots.",
                drill: "Ready position hold: 30 seconds between points, consciously reset to athletic stance."
            ),
            unitTurn: PhaseDetail(
                score: 7, status: .inZone,
                note: "Shoulders are turning well — you're getting good coil that'll translate to power.",
                timestamp: 2.1,
                keyAngles: ["Good shoulder turn creating separation from hips"],
                improveCue: "Show your back pocket to your opponent.",
                drill: "Mirror drill: practice unit turn in front of a mirror, check that your non-dominant shoulder points toward the net. 20 reps."
            ),
            backswing: PhaseDetail(
                score: 6, status: .warning,
                note: "The take-back is late. Your racket should be fully back before the ball bounces on your side — right now you're rushing to catch up.",
                timestamp: 2.4,
                keyAngles: ["Elbow position is fine — timing is the issue"],
                improveCue: "Racket back before the bounce.",
                drill: "Early prep drill with ball machine at moderate pace: the ONLY goal is racket back before each bounce. 3 sets of 20."
            ),
            forwardSwing: PhaseDetail(
                score: 8, status: .inZone,
                note: "Nice acceleration through the hitting zone. Your hips are leading the swing — that's where the effortless power comes from.",
                timestamp: 2.9,
                keyAngles: ["Hips leading the kinetic chain", "Good low-to-high swing path"],
                improveCue: "Drive from the ground up — legs, hips, then arm.",
                drill: "Medicine ball rotational throws against a wall: 3 sets of 10 each side."
            ),
            contactPoint: PhaseDetail(
                score: 8, status: .inZone,
                note: "Excellent contact — arm is extended, ball is well out in front of your body. This is your strongest phase.",
                timestamp: 3.2,
                keyAngles: ["Arm almost fully extended at contact", "Contact point ahead of front hip — textbook"],
                improveCue: "Reach out and meet it early.",
                drill: "Target practice: place cones at different depths, hit 20 forehands to each zone maintaining the same contact point."
            ),
            followThrough: PhaseDetail(
                score: 7, status: .inZone,
                note: "Clean finish over the shoulder. Just extend through the ball a little longer before wrapping the racket around.",
                timestamp: 3.6,
                keyAngles: ["Good over-the-shoulder finish", "Could push through contact point longer"],
                improveCue: "Swing through three balls, not one.",
                drill: "Extended follow-through shadow swings: 20 reps, focus on pushing the racket face forward longer."
            ),
            recovery: PhaseDetail(
                score: 7, status: .inZone,
                note: "Quick recovery step back to center. Good split step habit — that's a sign of a disciplined player.",
                timestamp: 4.1,
                keyAngles: ["Fast recovery to neutral position"],
                improveCue: "Split step as they hit.",
                drill: "Hit-and-recover cone drill: hit a forehand, sprint to center cone, split step. 3 sets of 10."
            )
        ),
        analysisCategories: [
            AnalysisCategory(
                name: "Preparation", description: "How early and efficiently you set up", status: .warning,
                subchecks: [
                    SubCheck(checkpoint: "Take-back Timing", result: "Late — needs to start earlier", status: .warning),
                    SubCheck(checkpoint: "Unit Turn", result: "Good rotation", status: .inZone)
                ], thumbnailPhase: "backswing"
            ),
            AnalysisCategory(
                name: "Contact Quality", description: "Where and how you strike the ball", status: .inZone,
                subchecks: [
                    SubCheck(checkpoint: "Contact Position", result: "Well out in front", status: .inZone),
                    SubCheck(checkpoint: "Arm Extension", result: "Nearly full — great reach", status: .inZone)
                ], thumbnailPhase: "contact_point"
            ),
            AnalysisCategory(
                name: "Power Generation", description: "Ground-up kinetic chain", status: .inZone,
                subchecks: [
                    SubCheck(checkpoint: "Hip Rotation", result: "Leading the swing", status: .inZone),
                    SubCheck(checkpoint: "Weight Transfer", result: "Solid", status: .inZone)
                ], thumbnailPhase: "forward_swing"
            ),
            AnalysisCategory(
                name: "Finish & Recovery", description: "Follow-through and court positioning", status: .inZone,
                subchecks: [
                    SubCheck(checkpoint: "Follow-Through", result: "Over shoulder — could extend more", status: .warning),
                    SubCheck(checkpoint: "Recovery Speed", result: "Quick", status: .inZone)
                ], thumbnailPhase: "follow_through"
            )
        ]
    )

    // MARK: - Demo Backhand

    static let demoBackhand = StrokeResult(
        type: .backhand,
        timestamp: 7.8,
        grade: "B-",
        mechanics: StrokeMechanics(
            backswing: MechanicDetail(
                score: 5,
                note: "Your shoulders are barely turning — you're hitting with just your arms instead of your whole body. That's like trying to throw a punch with just your fist.",
                whyScore: "Minimal shoulder rotation means you're generating power from arms only, not the kinetic chain.",
                improveCue: "Turn your back to the net on the backswing.",
                drill: "Wall drill: stand with your back to a wall, practice turning until your front shoulder touches the wall. 3 sets of 15.",
                sources: ["ATP Coaching Manual — Two-Handed Backhand"]
            ),
            contactPoint: MechanicDetail(
                score: 7,
                note: "Contact point is a little late — you're hitting beside your body instead of out in front. When you get it out front, it's a much cleaner strike.",
                whyScore: "Extension is borderline — contact needs to move forward for consistency.",
                improveCue: "Meet the ball 6 inches further in front.",
                drill: "Cone target drill: place a cone where contact should be (out in front of your lead hip), hit 20 backhands. Reset the cone if you're not reaching it.",
                sources: nil
            ),
            followThrough: MechanicDetail(
                score: 7,
                note: "Good two-handed finish with hands high. This is actually one of the better parts of your backhand — trust it.",
                whyScore: "Natural follow-through path with hands finishing above the shoulder.",
                improveCue: "Let the racket wrap around naturally.",
                drill: "Shadow swing focusing on high finish: 20 reps between games.",
                sources: nil
            ),
            stance: MechanicDetail(
                score: 6,
                note: "Your stance is too open for a two-handed backhand. You need to step across with your front foot to generate rotation.",
                whyScore: "Open stance limits hip and shoulder rotation on the backhand side.",
                improveCue: "Step across with your front foot before you swing.",
                drill: "Footwork ladder drill: step across into closed stance, shadow swing. 3 sets of 15. Make the step automatic.",
                sources: nil
            ),
            toss: nil
        ),
        overlayInstructions: OverlayInstructions(
            anglesToHighlight: [
                "Shoulder rotation: 25° (ideal: 60-90°)",
                "Arm extension: 160° (ideal: 165-180°)",
                "Knee: 155° (ideal: 130-155°)"
            ],
            trajectoryLine: true,
            comparisonGhost: false,
            swingPathPoints: nil,
            swingPlaneAngle: nil,
            pathAnnotations: nil
        ),
        gradingRationale: "Your backhand has potential but it's being held back by one big thing: preparation. You're barely turning your shoulders, which means you're swinging with just your arms. Fix the shoulder turn and everything else — power, consistency, contact point — gets better automatically.",
        nextRepsPlan: "Priority this week: closed stance backhands with full shoulder turn. 3 sessions of 25 backhands. Have someone film you from behind — you should see your back facing the net at the peak of your backswing. If you can't see it, you're not turning enough.",
        verifiedSources: ["ATP Coaching Manual"],
        phaseBreakdown: PhaseBreakdown(
            readyPosition: PhaseDetail(
                score: 6, status: .warning,
                note: "You're standing a little too tall here. Get lower — bend those knees more. Lower center of gravity means faster first step.",
                timestamp: 6.2,
                keyAngles: ["Standing too upright — needs more knee bend"],
                improveCue: "Get low, stay low.",
                drill: "Athletic stance holds: between every point, drop into a low ready position for 5 seconds. Make it a habit."
            ),
            unitTurn: PhaseDetail(
                score: 4, status: .outOfZone,
                note: "This is the #1 thing to fix. You're barely turning your shoulders — it's like trying to throw a ball without winding up. Turn until your back faces the net.",
                timestamp: 6.6,
                keyAngles: ["Shoulder turn at 25° — needs to be 60°+ for real power"],
                improveCue: "Show your back to your opponent.",
                drill: "Wall drill: stand with back to wall, practice full unit turn until your front shoulder touches. 30 reps daily until it's automatic."
            ),
            backswing: PhaseDetail(
                score: 5, status: .warning,
                note: "Your backswing is compact, which isn't bad by itself — but without a good unit turn, you've got no power behind it.",
                timestamp: 7.0,
                keyAngles: ["Compact backswing — fine if unit turn improves"],
                improveCue: "Let the turn take your racket back.",
                drill: "Resistance band backswing: attach a light band to a fence, practice the take-back against resistance. 3 sets of 15."
            ),
            forwardSwing: PhaseDetail(
                score: 6, status: .warning,
                note: "You're swinging mostly with your arms. The power should come from your hips rotating first, then the arms follow. Think of it like cracking a whip.",
                timestamp: 7.4,
                keyAngles: ["Arms leading instead of hips — reverse the sequence"],
                improveCue: "Hips first, then hands.",
                drill: "Hip rotation drill: stand sideways, rotate just your hips toward the net without moving your arms. Feel the stretch. Then let the arms follow. 3 sets of 10."
            ),
            contactPoint: PhaseDetail(
                score: 7, status: .inZone,
                note: "Contact is a bit late but when you do get it out front, it's clean. This will improve naturally once your preparation gets better.",
                timestamp: 7.8,
                keyAngles: ["Contact slightly behind ideal — will improve with better prep"],
                improveCue: "Meet it out front, every time.",
                drill: "Toss-and-hit drill: self-feed 20 balls, only count the ones where you contact ahead of your front hip."
            ),
            followThrough: PhaseDetail(
                score: 7, status: .inZone,
                note: "Clean two-handed finish — hands high, good wrap. This is solid, don't overthink it.",
                timestamp: 8.2,
                keyAngles: ["Natural high finish — good mechanics"],
                improveCue: "Trust the finish — let it flow.",
                drill: "Full follow-through shadow swings: 20 reps. Don't force it, let momentum carry you."
            ),
            recovery: PhaseDetail(
                score: 6, status: .warning,
                note: "A little slow getting back to center after the backhand. You're taking an extra shuffle step to rebalance — that's costing you half a second.",
                timestamp: 8.8,
                keyAngles: ["Extra step needed to rebalance — needs cleaner weight transfer"],
                improveCue: "Push off your front foot straight into the split step.",
                drill: "Backhand-to-sprint drill: hit a backhand, immediately sprint to the center mark, split step. 3 sets of 10. Race the ball."
            )
        ),
        analysisCategories: [
            AnalysisCategory(
                name: "Preparation", description: "Shoulder turn and setup", status: .outOfZone,
                subchecks: [
                    SubCheck(checkpoint: "Shoulder Turn", result: "Way too little — #1 priority", status: .outOfZone),
                    SubCheck(checkpoint: "Stance", result: "Too open — need closed stance", status: .warning)
                ], thumbnailPhase: "unit_turn"
            ),
            AnalysisCategory(
                name: "Contact Quality", description: "Strike position and timing", status: .inZone,
                subchecks: [
                    SubCheck(checkpoint: "Contact Position", result: "Slightly late but clean", status: .warning),
                    SubCheck(checkpoint: "Arm Extension", result: "Borderline — needs more reach", status: .warning)
                ], thumbnailPhase: "contact_point"
            ),
            AnalysisCategory(
                name: "Power Generation", description: "Hip and shoulder rotation", status: .warning,
                subchecks: [
                    SubCheck(checkpoint: "Hip Rotation", result: "Arms leading — hips should lead", status: .warning),
                    SubCheck(checkpoint: "Kinetic Chain", result: "Disconnected", status: .outOfZone)
                ], thumbnailPhase: "forward_swing"
            ),
            AnalysisCategory(
                name: "Finish & Recovery", description: "Follow-through and movement", status: .inZone,
                subchecks: [
                    SubCheck(checkpoint: "Follow-Through", result: "Clean two-handed finish", status: .inZone),
                    SubCheck(checkpoint: "Recovery Speed", result: "Slow — extra step", status: .warning)
                ], thumbnailPhase: "follow_through"
            )
        ]
    )
}
