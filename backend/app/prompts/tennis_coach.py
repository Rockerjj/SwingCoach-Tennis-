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
- Strokes detected on-device: {stroke_count}

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
