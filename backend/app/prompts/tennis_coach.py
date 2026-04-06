STROKE_SPECIFIC_CONTEXT: dict[str, str] = {
    "forehand": """**Forehand — Biomechanical Ideals**
- Kinetic chain: ground force → hip rotation → shoulder rotation → arm → racket
- Low-to-high swing path: contact point at hip height, finish above opposite shoulder
- Arm extension at contact: 160–175° (near full extension, slight elbow bend)
- Shoulder rotation (unit turn): 80–100° from baseline
- Wrist snap (windshield wiper finish): racket face rotates from vertical → face-down after contact
- Stance: open or semi-open for modern topspin; closed for flat/slice
- Contact point: 12–18 inches in front of front hip, slightly inside the ball
- Ideal knee bend at contact: 120–145° (athletic crouch, not locked)
- Follow-through: racket finishes over non-dominant shoulder or wraps around body""",

    "backhand": """**Backhand — Biomechanical Ideals**
- Two-handed: both arms drive through contact; non-dominant arm leads, contact at hip height
- One-handed: full shoulder turn (90°+), contact slightly in front and higher than 2H, high finish
- Arm extension (1H at contact): 155–175°; (2H): 130–155° with both arms extending
- Compact takeback: racket tip points down during backswing (not looping wide)
- Contact zone: ball contacted at waist–chest height; too low = loss of control
- Footwork: crossover step for wide balls; split step before every shot
- Follow-through (2H): both arms extend fully, finish high above shoulder
- Follow-through (1H): full arm extension, racket points to sky""",

    "serve": """**Serve — Biomechanical Ideals**
- Trophy pose: elbow at shoulder height, racket pointing up, front arm extended toward target
- Knee bend at trophy pose: 100–130° (leg drive is critical for power)
- Ball toss: released at full arm extension above and slightly in front of head (flat/slice) or to the right for kick
- Arm extension at ball contact: 175–180° (maximal reach, full extension)
- Pronation: forearm rotates inward through contact (adds pace + topspin)
- Shoulder rotation: full coil; hitting shoulder drops, non-hitting shoulder leads
- Foot position: feet shoulder-width, front foot angled ~45° toward net post
- Hip drive: hips rotate open before shoulder rotation (kinetic chain)
- Contact point height: ideally 9–12 inches above full reach for flat serve""",

    "volley": """**Volley — Biomechanical Ideals**
- Grip: continental (critical — no grip change at net)
- Backswing: compact punch motion; racket face barely moves behind body
- Contact point: in front of body at net height or above; ball contacted early
- Elbow: slightly bent, roughly at shoulder height for high volleys
- Wrist: firm and locked — no wrist lag or flip
- Footwork: split step as opponent strikes; step into the volley (low-to-high for underspin)
- Follow-through: short and punchy, NOT a full swing
- Body position: stay low (knees bent 130–150°); don't reach or straighten legs prematurely
- Low volleys: open racket face, slice under the ball, finish toward target""",

    "volley_forehand": """**Forehand Volley — Biomechanical Ideals** (same as volley above)
- Continental grip; punch motion; contact in front; firm wrist; split step""",

    "volley_backhand": """**Backhand Volley — Biomechanical Ideals** (same as volley above)
- Continental grip; lead with elbow; contact in front of body; slice for depth""",

    "overhead": """**Overhead / Smash — Biomechanical Ideals**
- Footwork: turn sideways immediately, point non-dominant hand at ball, backpedal with crossover steps
- Trophy position: mirrors the serve (elbow up, racket behind head)
- Contact point: slightly in front and above head, arm near full extension (170–180°)
- Pronation through contact: same motion as flat serve
- Weight transfer: forward into the shot (don't fall backward)
- Follow-through: racket finishes across body on same side as hitting hand""",
}


SYSTEM_PROMPT = """You are an elite tennis coach AI. You receive pre-computed stroke data from on-device analysis (timestamps, joint angles, stroke types) and your job is to provide coaching evaluation ONLY.

## CRITICAL RULES
1. You MUST use the timestamps and angles provided in the detected_strokes data. DO NOT invent or override them.
2. If an angle is marked NOT_VISIBLE, say "not measurable from this angle" -- do NOT fabricate a value.
3. You MUST produce one stroke entry for EACH detected stroke provided. Do not skip any.
4. Every phase_breakdown timestamp MUST exactly match what was provided in the detected stroke data.
5. The key_angles in each phase MUST use the measured values provided. Add ideal ranges for comparison.

## Your Role
- Score each phase (1-10) based on the measured angles vs ideal biomechanical ranges
- Assign zone status (in_zone / warning / out_of_zone) based on deviation from ideal
- Write 1-2 sentence coaching notes referencing the actual measured angles
- Provide one coaching cue and one drill per phase
- Generate analysis categories with subchecks
- Identify the single top priority improvement

## Scoring Guidelines
- 1-3: Significant deviation (>30° from ideal range)
- 4-6: Moderate deviation (15-30° from ideal)
- 7-8: Minor deviation (<15° from ideal)
- 9-10: Within ideal range

## Ideal Ranges (for scoring reference)
- Elbow at contact: 155-175°
- Knee bend (ready): 130-155°
- Shoulder rotation (unit turn): 60-90°+
- Hip angle (ready): 155-175°
- Arm extension at contact: 160-180°
"""

ANALYSIS_PROMPT_TEMPLATE = """Evaluate this tennis session. Player skill level: {skill_level}. Player is {handedness}-handed.

## Session Info
- Duration: {duration_seconds}s
- Total strokes detected on-device: {stroke_count}
- Representative strokes sent for analysis (best data quality per stroke type):

## Stroke-Specific Biomechanical Reference
The following ideal ranges apply to the strokes detected in this session. Use these to score phases and write coaching notes.

{stroke_specific_context}

## Pre-Computed Stroke Data
The following strokes were detected by on-device pose analysis. Timestamps and angles are REAL MEASUREMENTS from the video -- use them as-is.

{detected_strokes_summary}

## Instructions
For each detected stroke above, produce a complete analysis with:
1. Grade (A+ through F) based on the measured angles vs ideal ranges
2. phase_breakdown using the EXACT timestamps and angles provided (add ideal ranges for comparison)
3. analysis_categories with subchecks
4. Coaching notes, cues, drills, and improvement plan
5. overlay_instructions with the measured angles formatted for display

Respond with valid JSON:
```json
{{
  "session_grade": "B+",
  "strokes_detected": [
    {{
      "type": "forehand",
      "timestamp": 8.2,
      "grade": "B",
      "grading_rationale": "2-4 sentences referencing the MEASURED angles and how they compare to ideal.",
      "next_reps_plan": "Specific drills with rep counts.",
      "verified_sources": ["Real reference 1", "Real reference 2"],
      "mechanics": {{
        "backswing": {{"score": 6, "note": "Based on measured elbow angle of X vs ideal Y.", "why_score": "...", "improve_cue": "...", "drill": "...", "sources": ["..."]}},
        "contact_point": {{"score": 7, "note": "...", "why_score": "...", "improve_cue": "...", "drill": "...", "sources": ["..."]}},
        "follow_through": {{"score": 8, "note": "...", "why_score": "...", "improve_cue": "...", "drill": "...", "sources": ["..."]}},
        "stance": {{"score": 7, "note": "...", "why_score": "...", "improve_cue": "...", "drill": "...", "sources": ["..."]}}
      }},
      "phase_breakdown": {{
        "ready_position": {{
          "score": 7,
          "status": "in_zone",
          "note": "Use the measured angles to describe what was observed.",
          "timestamp": 6.8,
          "key_angles": ["Knee: 142° (ideal: 130-155°)", "Hip: 168° (ideal: 155-175°)"],
          "improve_cue": "One concise cue.",
          "drill": "Specific drill with reps."
        }},
        "unit_turn": {{"score": 5, "status": "warning", "note": "...", "timestamp": 7.1, "key_angles": ["..."], "improve_cue": "...", "drill": "..."}},
        "backswing": {{"score": 6, "status": "warning", "note": "...", "timestamp": 7.4, "key_angles": ["..."], "improve_cue": "...", "drill": "..."}},
        "forward_swing": {{"score": 7, "status": "in_zone", "note": "...", "timestamp": 7.8, "key_angles": ["..."], "improve_cue": "...", "drill": "..."}},
        "contact_point": {{"score": 7, "status": "in_zone", "note": "...", "timestamp": 8.2, "key_angles": ["..."], "improve_cue": "...", "drill": "..."}},
        "follow_through": {{"score": 8, "status": "in_zone", "note": "...", "timestamp": 8.5, "key_angles": ["..."], "improve_cue": "...", "drill": "..."}},
        "recovery": {{"score": 5, "status": "warning", "note": "...", "timestamp": 9.0, "key_angles": ["..."], "improve_cue": "...", "drill": "..."}}
      }},
      "analysis_categories": [
        {{"name": "Setup Posture", "description": "Ready position and stance", "status": "in_zone", "thumbnail_phase": "ready_position", "subchecks": [{{"checkpoint": "Knee Bend", "result": "Good", "status": "in_zone"}}]}},
        {{"name": "Swing Path", "description": "Racket path through swing", "status": "warning", "thumbnail_phase": "backswing", "subchecks": [{{"checkpoint": "Takeaway", "result": "On Plane", "status": "in_zone"}}]}},
        {{"name": "Footwork", "description": "Movement and positioning", "status": "in_zone", "thumbnail_phase": "ready_position", "subchecks": []}},
        {{"name": "Contact Zone", "description": "Strike position", "status": "in_zone", "thumbnail_phase": "contact_point", "subchecks": []}},
        {{"name": "Follow-Through", "description": "Finish and deceleration", "status": "in_zone", "thumbnail_phase": "follow_through", "subchecks": []}},
        {{"name": "Spine Stability", "description": "Core posture", "status": "in_zone", "thumbnail_phase": "forward_swing", "subchecks": []}},
        {{"name": "Posture at Impact", "description": "Body alignment at contact", "status": "warning", "thumbnail_phase": "contact_point", "subchecks": []}}
      ],
      "overlay_instructions": {{
        "angles_to_highlight": ["Elbow: 140° (ideal: 155-175°)", "Shoulder rotation: 25° (ideal: 60-90°)"],
        "trajectory_line": true,
        "comparison_ghost": false
      }}
    }}
  ],
  "tactical_notes": ["Observation about shot patterns."],
  "top_priority": "Single highest-impact improvement.",
  "overall_mechanics_score": 72.5,
  "session_summary": "2-3 sentence summary."
}}
```

Return ONLY the JSON, no additional text."""


def build_detected_strokes_summary(detected_strokes: list) -> str:
    """Format pre-computed stroke data for the GPT prompt."""
    if not detected_strokes:
        return "No strokes detected on-device."

    lines = []
    for i, stroke in enumerate(detected_strokes):
        s_type = stroke.get("type", stroke.get("type", "unknown"))
        contact_ts = stroke.get("contact_timestamp", 0)
        lines.append(f"\n### Stroke #{i+1}: {s_type} (contact at t={contact_ts:.1f}s)")

        phases = stroke.get("phases", {})
        for phase_name in ["ready_position", "unit_turn", "backswing", "forward_swing", "contact_point", "follow_through", "recovery"]:
            phase = phases.get(phase_name)
            if not phase:
                lines.append(f"  {phase_name}: NOT DETECTED")
                continue

            ts = phase.get("timestamp", 0)
            angles = phase.get("angles", {})
            angle_strs = []
            for key, angle_data in angles.items():
                if isinstance(angle_data, dict):
                    label = angle_data.get("label", key)
                    visible = angle_data.get("visible", True)
                    if visible:
                        angle_strs.append(label)
                    else:
                        angle_strs.append(f"{key}: NOT_VISIBLE")
            angles_text = ", ".join(angle_strs) if angle_strs else "no angles measured"
            lines.append(f"  {phase_name} at t={ts:.1f}s: {angles_text}")

    return "\n".join(lines)


def get_stroke_types_from_payload(detected_strokes: list) -> set[str]:
    """Extract unique stroke types from the detected strokes list."""
    types = set()
    for stroke in detected_strokes:
        s_type = stroke.get("type", "").lower().strip()
        if s_type:
            types.add(s_type)
    return types


def build_pose_summary(frames: list, max_frames: int = 50) -> str:
    """Condense frame data into a text summary the LLM can process efficiently."""
    if not frames:
        return "No pose data available."

    step = max(1, len(frames) // max_frames)
    sampled = frames[::step]

    lines = []
    for frame in sampled:
        joints_str = ", ".join(
            f"{j['name']}({j['x']:.3f},{j['y']:.3f})"
            for j in frame["joints"]
            if j["confidence"] > 0.3
        )
        lines.append(f"t={frame['timestamp']:.2f}s: {joints_str}")

    return "\n".join(lines)
