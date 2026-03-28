import Foundation

/// Pre-baked demo analysis data so new users can see the full "wow" experience
/// before they even record a session. Ships with the app bundle.
enum DemoSession {

    // MARK: - Demo Analysis Response

    static let analysisResponse = AnalysisResponse(
        sessionGrade: "B+",
        strokesDetected: [demoForehand, demoBackhand],
        tacticalNotes: [
            "Strong forehand foundation — consistent contact point and good hip rotation.",
            "Backhand needs more shoulder turn on the unit turn phase.",
            "Recovery footwork is quick — good split step habit forming."
        ],
        topPriority: "Increase shoulder rotation on backhand unit turn from 25° to 60°+ for more power and consistency.",
        overallMechanicsScore: 74.5,
        sessionSummary: "Solid intermediate session with 2 strokes analyzed. Your forehand mechanics are approaching advanced level with strong contact point positioning. Backhand needs work on the preparation phase — specifically shoulder coil during unit turn."
    )

    // MARK: - Demo Forehand

    static let demoForehand = StrokeResult(
        type: .forehand,
        timestamp: 3.2,
        grade: "B+",
        mechanics: StrokeMechanics(
            backswing: MechanicDetail(
                score: 7,
                note: "Good racket preparation with elbow at 105°. Slightly late on the take-back.",
                whyScore: "Elbow angle is within range but timing could be earlier.",
                improveCue: "Start your take-back as the ball crosses the net.",
                drill: "Shadow swing drill: 3 sets of 20 reps focusing on early preparation.",
                sources: ["Tennis Warehouse University — Forehand Fundamentals"]
            ),
            contactPoint: MechanicDetail(
                score: 8,
                note: "Excellent contact position with arm extension at 172°. Ball struck well in front.",
                whyScore: "Arm extension near-ideal (165-180° range). Contact point is ahead of the body.",
                improveCue: "Maintain this contact point — it's your strongest mechanic.",
                drill: "Drop-feed drill: partner feeds 20 balls, focus on consistent contact zone.",
                sources: ["USTA Player Development — Contact Point Guide"]
            ),
            followThrough: MechanicDetail(
                score: 7,
                note: "Follow-through finishes over the shoulder. Could extend more through the ball.",
                whyScore: "Good finish position but deceleration starts slightly early.",
                improveCue: "Think 'extend through 3 balls' before wrapping over your shoulder.",
                drill: "Towel drill: swing through hanging towel at contact height, 15 reps.",
                sources: nil
            ),
            stance: MechanicDetail(
                score: 7,
                note: "Semi-open stance with good knee bend at 148°.",
                whyScore: "Knee bend is in the ideal zone (130-155°). Weight transfer is solid.",
                improveCue: "Load slightly more into back leg before the forward swing.",
                drill: "Split step to loaded position: 3 sets of 10 with a partner feeding.",
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
        gradingRationale: "Strong forehand with excellent contact mechanics (B+). Arm extension of 172° is near-ideal, and knee bend at 148° shows good athletic posture. Take-back timing is the main area for improvement — starting the backswing earlier would give more time to set up.",
        nextRepsPlan: "This week: 3 sessions of 30 forehands focusing on early take-back. Use a ball machine set to moderate pace.",
        verifiedSources: ["USTA Player Development", "Tennis Warehouse University"],
        phaseBreakdown: PhaseBreakdown(
            readyPosition: PhaseDetail(
                score: 7, status: .inZone,
                note: "Good athletic ready position with knees bent and weight forward.",
                timestamp: 1.8,
                keyAngles: ["Knee: 148° (ideal: 130-155°)", "Hip: 165° (ideal: 155-175°)"],
                improveCue: "Stay light on the balls of your feet.",
                drill: "Ready position hold: 30 seconds x 5 sets between points."
            ),
            unitTurn: PhaseDetail(
                score: 7, status: .inZone,
                note: "Shoulders rotate 72° — good coil for power generation.",
                timestamp: 2.1,
                keyAngles: ["Shoulder rotation: 72° (ideal: 60-90°)"],
                improveCue: "Turn your non-dominant shoulder toward the net.",
                drill: "Mirror drill: practice unit turn in front of a mirror, 20 reps."
            ),
            backswing: PhaseDetail(
                score: 6, status: .warning,
                note: "Backswing is slightly late — elbow at 105° is fine but the timing needs work.",
                timestamp: 2.4,
                keyAngles: ["Elbow: 105° (ideal: 90-120°)"],
                improveCue: "Start take-back when ball crosses the net.",
                drill: "Early preparation drill with ball machine: focus on racket back before bounce."
            ),
            forwardSwing: PhaseDetail(
                score: 8, status: .inZone,
                note: "Good acceleration through the hitting zone with hip leading the swing.",
                timestamp: 2.9,
                keyAngles: ["Elbow: 158° (ideal: 140-175°)", "Hip lead: 35° (ideal: 20-50°)"],
                improveCue: "Drive from the ground up — legs, hips, then arm.",
                drill: "Medicine ball rotational throws: 3 sets of 10."
            ),
            contactPoint: PhaseDetail(
                score: 8, status: .inZone,
                note: "Excellent contact with arm almost fully extended at 172°.",
                timestamp: 3.2,
                keyAngles: ["Arm extension: 172° (ideal: 165-180°)", "Wrist: 175° (ideal: 170-185°)"],
                improveCue: "This is your money zone — keep hitting here.",
                drill: "Target practice: place targets and hit 20 forehands to each zone."
            ),
            followThrough: PhaseDetail(
                score: 7, status: .inZone,
                note: "Good finish over the shoulder. Slight early deceleration.",
                timestamp: 3.6,
                keyAngles: ["Arm: 125° (ideal: 90-140°)"],
                improveCue: "Extend through the ball longer before wrapping.",
                drill: "Towel drill or extended follow-through shadow swings."
            ),
            recovery: PhaseDetail(
                score: 7, status: .inZone,
                note: "Quick recovery step back to center. Good habit.",
                timestamp: 4.1,
                keyAngles: ["Knee: 152° (ideal: 150-175°)"],
                improveCue: "Split step as your opponent makes contact.",
                drill: "Recovery cone drill: hit, recover to center cone, split step."
            )
        ),
        analysisCategories: [
            AnalysisCategory(
                name: "Setup Posture", description: "Ready position and stance", status: .inZone,
                subchecks: [
                    SubCheck(checkpoint: "Knee Bend", result: "148° — Good", status: .inZone),
                    SubCheck(checkpoint: "Weight Distribution", result: "Forward", status: .inZone)
                ], thumbnailPhase: "ready_position"
            ),
            AnalysisCategory(
                name: "Swing Path", description: "Racket path through swing", status: .warning,
                subchecks: [
                    SubCheck(checkpoint: "Take-back Timing", result: "Slightly Late", status: .warning),
                    SubCheck(checkpoint: "Low-to-High Path", result: "Good", status: .inZone)
                ], thumbnailPhase: "backswing"
            ),
            AnalysisCategory(
                name: "Contact Zone", description: "Strike position", status: .inZone,
                subchecks: [
                    SubCheck(checkpoint: "Arm Extension", result: "172° — Excellent", status: .inZone),
                    SubCheck(checkpoint: "Contact Height", result: "Waist Level", status: .inZone)
                ], thumbnailPhase: "contact_point"
            ),
            AnalysisCategory(
                name: "Follow-Through", description: "Finish and deceleration", status: .inZone,
                subchecks: [
                    SubCheck(checkpoint: "Over Shoulder Finish", result: "Yes", status: .inZone),
                    SubCheck(checkpoint: "Full Extension", result: "Slight Early Decel", status: .warning)
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
                note: "Limited shoulder rotation at 25° — needs more coil for power.",
                whyScore: "Shoulder rotation is well below the ideal 60-90° range.",
                improveCue: "Turn your back to the net on the backswing.",
                drill: "Closed stance backhand drill: 3 sets of 15, focus on full rotation.",
                sources: ["ATP Coaching Manual — Two-Handed Backhand"]
            ),
            contactPoint: MechanicDetail(
                score: 7,
                note: "Contact point is slightly late but arm extension is decent at 160°.",
                whyScore: "Extension is at the low end of ideal (165-180°). Contact point needs to be more in front.",
                improveCue: "Hit the ball 6 inches further in front of your body.",
                drill: "Cone target drill: place a cone where contact should be, hit 20 backhands.",
                sources: nil
            ),
            followThrough: MechanicDetail(
                score: 7,
                note: "Good two-handed finish with hands high.",
                whyScore: "Natural follow-through path. Hands finish above the shoulder.",
                improveCue: "Let the racket wrap around your body naturally.",
                drill: "Shadow swing focusing on high finish: 20 reps between games.",
                sources: nil
            ),
            stance: MechanicDetail(
                score: 6,
                note: "Stance is too open for a two-handed backhand. Needs more closed positioning.",
                whyScore: "Open stance limits rotation power on the backhand side.",
                improveCue: "Step across with your front foot before swinging.",
                drill: "Footwork pattern drill: step-across into closed stance, 15 reps.",
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
        gradingRationale: "Backhand needs work primarily on the preparation phase. Shoulder rotation of only 25° is significantly below the ideal 60°+ range, limiting power generation. Contact point and follow-through are serviceable but would improve naturally with better preparation.",
        nextRepsPlan: "Priority drill this week: closed stance backhand with full shoulder turn. 3 sessions of 25 backhands. Film yourself and verify shoulder rotation improves.",
        verifiedSources: ["ATP Coaching Manual"],
        phaseBreakdown: PhaseBreakdown(
            readyPosition: PhaseDetail(
                score: 6, status: .warning,
                note: "Ready position is adequate but stance is too upright.",
                timestamp: 6.2,
                keyAngles: ["Knee: 155° (ideal: 130-155°)"],
                improveCue: "Bend your knees more — get lower.",
                drill: "Athletic stance holds between points."
            ),
            unitTurn: PhaseDetail(
                score: 4, status: .outOfZone,
                note: "Only 25° shoulder rotation — this is the #1 issue limiting backhand power.",
                timestamp: 6.6,
                keyAngles: ["Shoulder rotation: 25° (ideal: 60-90°)"],
                improveCue: "Show your back to the opponent on the turn.",
                drill: "Wall drill: stand with back to wall, practice full unit turn 30 reps."
            ),
            backswing: PhaseDetail(
                score: 5, status: .warning,
                note: "Backswing is compact but lacks depth due to poor unit turn.",
                timestamp: 7.0,
                keyAngles: ["Elbow: 95° (ideal: 90-120°)"],
                improveCue: "Take the racket further back with your turn.",
                drill: "Resistance band backswing: 3 sets of 15 with light band."
            ),
            forwardSwing: PhaseDetail(
                score: 6, status: .warning,
                note: "Forward swing is arm-dominant — hips should lead but they're late.",
                timestamp: 7.4,
                keyAngles: ["Hip lead: 12° (ideal: 20-50°)"],
                improveCue: "Start the forward swing with your hips, not your arms.",
                drill: "Hip rotation drill with medicine ball: 3 sets of 10."
            ),
            contactPoint: PhaseDetail(
                score: 7, status: .inZone,
                note: "Contact is slightly late but extension is close to acceptable at 160°.",
                timestamp: 7.8,
                keyAngles: ["Arm extension: 160° (ideal: 165-180°)"],
                improveCue: "Meet the ball further out in front.",
                drill: "Toss-and-hit drill: self-feed 20 balls focusing on contact point."
            ),
            followThrough: PhaseDetail(
                score: 7, status: .inZone,
                note: "Clean two-handed finish over the shoulder.",
                timestamp: 8.2,
                keyAngles: ["Arm: 118° (ideal: 90-140°)"],
                improveCue: "Let momentum carry the finish — don't cut it short.",
                drill: "Full follow-through shadow swings: 20 reps."
            ),
            recovery: PhaseDetail(
                score: 6, status: .warning,
                note: "Slow recovery — took an extra step to rebalance.",
                timestamp: 8.8,
                keyAngles: ["Knee: 160° (ideal: 150-175°)"],
                improveCue: "Push off your front foot immediately into split step.",
                drill: "Backhand-to-split-step drill: hit then explode back to center."
            )
        ),
        analysisCategories: [
            AnalysisCategory(
                name: "Setup Posture", description: "Ready position and stance", status: .warning,
                subchecks: [
                    SubCheck(checkpoint: "Knee Bend", result: "155° — Needs More", status: .warning),
                    SubCheck(checkpoint: "Stance Width", result: "Too Narrow", status: .warning)
                ], thumbnailPhase: "ready_position"
            ),
            AnalysisCategory(
                name: "Shoulder Coil", description: "Unit turn and preparation", status: .outOfZone,
                subchecks: [
                    SubCheck(checkpoint: "Shoulder Rotation", result: "25° — Insufficient", status: .outOfZone),
                    SubCheck(checkpoint: "Hip Coil", result: "Minimal", status: .warning)
                ], thumbnailPhase: "unit_turn"
            ),
            AnalysisCategory(
                name: "Contact Zone", description: "Strike position", status: .inZone,
                subchecks: [
                    SubCheck(checkpoint: "Arm Extension", result: "160° — Borderline", status: .warning),
                    SubCheck(checkpoint: "Contact Timing", result: "Slightly Late", status: .warning)
                ], thumbnailPhase: "contact_point"
            ),
            AnalysisCategory(
                name: "Follow-Through", description: "Finish mechanics", status: .inZone,
                subchecks: [
                    SubCheck(checkpoint: "Two-Hand Finish", result: "Clean", status: .inZone),
                    SubCheck(checkpoint: "Recovery Speed", result: "Slow", status: .warning)
                ], thumbnailPhase: "follow_through"
            )
        ]
    )
}
