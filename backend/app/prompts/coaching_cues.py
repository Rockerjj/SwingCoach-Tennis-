"""
Curated coaching cue database — sourced from world-class coaches and
peer-reviewed biomechanics research.

Sources: USTA Player Development, ITF Coaching Manual, Patrick Mouratoglou
Academy, Nick Bollettieri Tennis Handbook, Elliott/Reid/Crespo biomechanics
research, PTR certification curriculum, Frontiers in Sports Science 2024.

Each entry maps a specific biomechanical deviation to a vetted coaching
response. The LLM must select from or closely adapt these cues.
"""

COACHING_CUES = {
    "forehand": {
        "ready_position": {
            "knees_too_straight": {
                "cue": "Bend your knees and sit into an athletic stance — like a shortstop ready to field a ground ball",
                "why": "Straight legs lock the hips and add 200-300ms to your first-step reaction time",
                "drill": "Split-step reaction drill: partner points left or right, explode to that side. 3 sets of 10.",
                "source": "USTA Player Development"
            },
            "weight_on_heels": {
                "cue": "Stay on the balls of your feet — you should feel like you could jump in any direction",
                "why": "Weight on the heels makes it impossible to push off explosively toward the ball",
                "drill": "Ready-position bouncing: small rhythmic bounces on the balls of your feet between shots. Practice during rallies.",
                "source": "USTA Player Development"
            },
            "racket_too_low": {
                "cue": "Keep your hands and racket up at chest height — don't let them hang by your waist",
                "why": "A low ready position adds an unnecessary upward motion before you can start your backswing",
                "drill": "Rally 20 balls consciously resetting hands to chest height after every shot.",
                "source": "PTR Level 1 Certification"
            },
        },
        "unit_turn": {
            "shoulder_rotation_low": {
                "cue": "Turn your chest until your front shoulder points toward the net post — your opponent should see your back",
                "why": "Insufficient shoulder coil limits the stored rotational energy available for the forward swing. Elite players achieve 60-90 degrees of shoulder turn.",
                "drill": "Mirror unit-turn drill: racket on shoulder, turn until your back pocket is visible to opponent. Hold 2 seconds. 3 sets of 12.",
                "source": "USTA Player Development; Elliott, Reid & Crespo 2009"
            },
            "hip_rotation_low": {
                "cue": "Load into your back hip — feel your weight settle there before you uncoil",
                "why": "Hip pre-loading creates the ground-up kinetic chain. Power starts from the ground, through the hips, into the trunk, and out through the arm.",
                "drill": "Medicine ball rotational throws against a wall: same hip-first motion as your forehand. 3 sets of 8 each side.",
                "source": "ITF Coaching Manual; Landlinger et al. 2010"
            },
            "late_preparation": {
                "cue": "Start your turn the instant you read the ball — racket should be back before the ball bounces on your side",
                "why": "Late preparation compresses the entire swing and forces rushing through contact. Early preparation gives you time, which gives you options.",
                "drill": "Rally drill: partner yells 'turn' at feed. Your racket must be fully back before ball bounces. 3 sets of 15.",
                "source": "Nick Bollettieri Tennis Handbook; USTA High Performance"
            },
            "arm_takes_racket_back": {
                "cue": "Don't take the racket back with your arm — let the body turn bring it back naturally as one unit",
                "why": "An arm-only take-back disconnects the racket from your body rotation, making the swing arm-dominant instead of body-driven",
                "drill": "Non-dominant hand on the racket throat during unit turn. Both hands guide the turn together. 20 reps.",
                "source": "Mouratoglou Academy; Coach Adri (Tennisnerd)"
            },
        },
        "backswing": {
            "racket_loop_too_low": {
                "cue": "Loop the racket higher on the take-back — the tip should point up before it drops down behind you",
                "why": "A low, flat take-back shortens the swing arc and reduces the racket head speed you can generate",
                "drill": "Shadow swings: check that racket tip points to the sky at the top of your backswing. 3 sets of 10.",
                "source": "ITF Coaching Manual"
            },
            "backswing_too_big": {
                "cue": "Keep it compact — your racket hand shouldn't go past your back hip",
                "why": "An over-extended backswing creates timing problems and inconsistency, especially on fast balls",
                "drill": "Backswing with towel tucked under hitting arm — if the towel falls, your take-back is too big. 20 reps.",
                "source": "Nick Bollettieri Tennis Handbook"
            },
            "no_racket_drop": {
                "cue": "Let the racket drop below the ball before you swing forward — this is where topspin comes from",
                "why": "Without the racket dropping below the contact point, the swing path is flat and you can't generate topspin",
                "drill": "Slow-motion shadow swings: pause at the lowest point of the racket drop, check it's below waist height. 3 sets of 10.",
                "source": "Mouratoglou Academy"
            },
        },
        "forward_swing": {
            "arm_dominant_swing": {
                "cue": "Let your hips start the forward swing — the arm is just along for the ride",
                "why": "Arm-dominant swings max out at 60% of potential power. Hip-led swings use the full kinetic chain: ground to legs to hips to trunk to arm.",
                "drill": "Hit forehands with feet planted, focus ONLY on feeling hips fire first. If your hips don't move first, stop and reset. 3 sets of 10.",
                "source": "USTA Player Development; Landlinger et al. 2010"
            },
            "swing_path_too_flat": {
                "cue": "Brush up the back of the ball — your swing path should go from low to high, not straight through",
                "why": "A flat swing path produces no topspin, reducing your margin over the net and landing consistency",
                "drill": "Hit over a rope strung 4 feet above the net. Forces a steep low-to-high swing path. 20 balls.",
                "source": "ITF Coaching Manual"
            },
            "no_weight_transfer": {
                "cue": "Drive your body weight forward into the shot — you should feel your weight shift from back foot to front foot",
                "why": "Static weight robs the shot of depth and penetration. Weight transfer adds linear momentum to the rotation.",
                "drill": "Step-in forehand drill: deliberately step forward with your front foot as you swing. 3 sets of 10.",
                "source": "Mouratoglou Academy; USTA Player Development"
            },
        },
        "contact_point": {
            "elbow_too_bent": {
                "cue": "Reach out and meet the ball further in front — your arm should be almost fully extended at contact",
                "why": "Cramped contact with a bent elbow reduces power by 30-40% and limits directional control. Ideal elbow extension at contact is 155-175 degrees.",
                "drill": "Self-drop drill: drop ball, freeze at contact with arm fully extended. Check position before hitting next ball. 4 sets of 6.",
                "source": "USTA High Performance; Elliott 2006"
            },
            "contact_too_close_to_body": {
                "cue": "Create space between your body and the ball — strike the ball at arm's length, not jammed in close",
                "why": "Contact too close to the body prevents full extension and forces a pushing motion instead of a driving swing",
                "drill": "Bollettieri chair drill: sit on a chair facing the net, partner feeds, you must reach out to make contact. Then stand and repeat. 20 reps.",
                "source": "Nick Bollettieri (Tennis.com); USTA Player Development"
            },
            "contact_too_late": {
                "cue": "Hit the ball before it passes your front hip — meet it early, out in front",
                "why": "Late contact shifts your swing from driving forward to pulling across, costing you directional control and depth",
                "drill": "Place a cone at your ideal contact point (2 feet in front of your lead hip). Hit 20 balls making contact at the cone.",
                "source": "USTA Player Development"
            },
            "wrist_too_stiff": {
                "cue": "Relax your hand and wrist — let the racket head whip through naturally, don't muscle it",
                "why": "A stiff wrist kills racket head speed. The wrist should lag naturally during the forward swing and release through contact.",
                "drill": "Wrist-release drill: hit forehands at 50% effort focusing only on feeling a loose, whippy wrist. 20 balls.",
                "source": "Mouratoglou Academy; biomechanics research"
            },
        },
        "follow_through": {
            "deceleration_early": {
                "cue": "Accelerate through the ball, not to it — swing through three balls, not one",
                "why": "Decelerating before contact reduces racket speed at impact and kills topspin potential",
                "drill": "Shadow swings: push the racket face forward as long as possible before wrapping. Hold the finish position 2 seconds. 3 sets of 10.",
                "source": "USTA Player Development"
            },
            "finish_too_low": {
                "cue": "Finish with the racket across your body at shoulder height or above — let it wrap around",
                "why": "A low finish indicates a flat swing path. The modern forehand finishes high (over the shoulder or windshield-wiper across the body).",
                "drill": "Catch-the-racket drill: non-dominant hand catches the racket at your opposite shoulder on follow-through. 20 reps.",
                "source": "ITF Coaching Manual"
            },
            "stopping_at_contact": {
                "cue": "The stroke doesn't end at contact — follow through fully in the direction you want the ball to go",
                "why": "Stopping at contact makes the stroke jerky, reduces accuracy, and can cause arm injuries over time",
                "drill": "Hit 20 forehands where your only focus is completing the full follow-through. Don't think about anything else.",
                "source": "Mouratoglou Academy"
            },
        },
        "recovery": {
            "no_split_step": {
                "cue": "Split step as your opponent makes contact — land light on both feet, ready to push off in any direction",
                "why": "Without a split step, you're always a half-step late getting to the next ball",
                "drill": "Hit-and-recover: hit forehand, sprint to center, split step, repeat. 3 sets of 10.",
                "source": "USTA Player Development"
            },
            "watching_the_shot": {
                "cue": "Don't admire your shot — recover to center immediately after contact",
                "why": "Standing and watching leaves the court wide open for your opponent's reply",
                "drill": "Partner hits alternating sides. You must touch the center cone between every shot. 2 sets of 20.",
                "source": "USTA Player Development"
            },
        },
    },
    "backhand": {
        "unit_turn": {
            "shoulder_rotation_low": {
                "cue": "Rotate your upper body until your chin touches your front shoulder — your opponent should see your back",
                "why": "Insufficient backhand coil limits the rotational energy available. Elite two-handed backhands achieve 80-100 degrees of shoulder rotation.",
                "drill": "Shadow backhand unit turns with a 2-second hold at full rotation. Check chin-on-shoulder position. 3 sets of 10.",
                "source": "Korean J Applied Biomechanics; USTA"
            },
            "hands_too_far_from_body": {
                "cue": "Keep your hands close to your body on the turn — compact and connected to your trunk rotation",
                "why": "Wide hands disconnect the arms from the body's rotation, so you swing with your arms instead of your core",
                "drill": "Towel drill: tuck a towel between your arm and body during the unit turn. If it falls, your hands are too wide. 20 reps.",
                "source": "ITF Coaching Manual"
            },
            "no_hip_loading": {
                "cue": "Coil your hips with your shoulders — don't just turn your arms, turn your whole body",
                "why": "Hip engagement is essential for power. Players who fail to engage hips overuse the upper body and generate tension.",
                "drill": "Backhand unit turn with hands behind your back: feel the hips and trunk rotate together. 3 sets of 10.",
                "source": "Feel Tennis; Mouratoglou Academy"
            },
        },
        "contact_point": {
            "contact_too_late": {
                "cue": "Meet the ball out in front — your top hand drives forward into the ball, not across your body",
                "why": "Late backhand contact forces a push instead of a drive, losing depth and directional control",
                "drill": "Feed drill with a contact-point marker cone placed 2 feet in front of your lead hip. 20 reps focusing on early contact.",
                "source": "USTA Player Development"
            },
            "elbows_collapsing": {
                "cue": "Keep your arms extended through contact — don't let your elbows collapse into your chest",
                "why": "Collapsed elbows shorten the swing radius and cut the shot short, reducing pace and depth",
                "drill": "Hit backhands and freeze at contact. Check: are your elbows away from your body? If they're touching your ribs, extend more. 4 sets of 6.",
                "source": "TennisNation; Mouratoglou Academy"
            },
            "non_dominant_hand_passive": {
                "cue": "Your top hand is the engine — think of the two-handed backhand as a left-handed forehand (for righties)",
                "why": "When the top hand is passive, the stroke becomes a guided push instead of an aggressive drive",
                "drill": "Hit 10 backhands with only your top hand (remove the bottom hand). Then add the bottom hand back. Feel the difference.",
                "source": "Mouratoglou Academy; TennisGate"
            },
        },
        "follow_through": {
            "truncated_finish": {
                "cue": "Finish high and fully across your body — think about hitting through six balls, not one",
                "why": "A short follow-through indicates deceleration before impact and limits spin production",
                "drill": "Shadow backhands: finish with racket pointing toward the back fence behind your opposite shoulder. 3 sets of 10.",
                "source": "ITF Coaching Manual; TennisNation"
            },
            "both_hands_release_early": {
                "cue": "Keep both hands on the racket through contact and into the follow-through — don't let go early",
                "why": "Releasing the top hand too early reduces stability and consistency at contact",
                "drill": "Hit 20 backhands where both hands stay on the racket until the follow-through is complete.",
                "source": "Mouratoglou Academy"
            },
        },
    },
    "serve": {
        "trophy_position": {
            "knee_bend_insufficient": {
                "cue": "Bend your knees much deeper — load the legs like you're about to jump as high as you can",
                "why": "Leg drive contributes 10-15% of serve velocity. Straight legs eliminate this entire energy source. Ideal knee flexion is 55-75 degrees.",
                "drill": "Trophy position freeze drill: toss, pause at trophy with deep knee bend, check position, then serve. 3 sets of 8.",
                "source": "Frontiers 2024 meta-analysis; USTA Player Development"
            },
            "toss_inconsistent": {
                "cue": "Release the ball at eye level with a straight arm — let it float up gently, don't throw it",
                "why": "An inconsistent toss forces last-second compensations in the swing that kill accuracy and power",
                "drill": "Toss-only practice: 10 tosses in a row, catch the ball on your racket face without swinging. Repeat 3 sets.",
                "source": "USTA Player Development"
            },
            "toss_too_far_behind": {
                "cue": "Place the toss slightly in front of you — if you didn't swing, it should land a foot inside the baseline",
                "why": "A toss behind you forces you to arch backward and reach, costing height and control at contact",
                "drill": "Toss 10 balls and let them bounce. Mark where they land. Adjust until they consistently land 12 inches inside the baseline.",
                "source": "Top Tennis Training; USTA"
            },
        },
        "racket_drop": {
            "no_racket_drop": {
                "cue": "Let the racket drop behind your back — think 'scratch your back' with the racket edge",
                "why": "The racket drop creates the stretch-shortening cycle in the shoulder that generates explosive upward acceleration",
                "drill": "Scratch-your-back drill: from trophy position, drop the racket until it touches your back, then swing up. 3 sets of 10.",
                "source": "USTA Player Development; Tennis Bros"
            },
            "elbow_too_low": {
                "cue": "Keep your elbow up and your tossing arm pointing at the ball — form an 'L' shape with your arm",
                "why": "A dropped elbow reduces shoulder rotation range and lowers the contact point",
                "drill": "Freeze at trophy: check that your elbow is at or above shoulder height. Hold 3 seconds. 3 sets of 8.",
                "source": "RPS Academies; ITF Coaching Manual"
            },
        },
        "contact_point": {
            "not_reaching_full_height": {
                "cue": "Reach for the sky — make contact at absolute full extension, as high as you can reach",
                "why": "Every inch of contact height adds angle and margin over the net. The ball should be struck at full arm extension.",
                "drill": "Serve to a target on a wall at maximum reach height. 20 reps focusing on extension, not pace.",
                "source": "Frontiers 2024 meta-analysis"
            },
            "no_pronation": {
                "cue": "Turn the doorknob through contact — your forearm naturally rotates inward as you hit",
                "why": "Pronation adds 10-20% serve speed and is essential for controlling spin direction (slice, kick, flat)",
                "drill": "Pronation isolation: serve into the fence from 10 feet away, focus only on the forearm rotation through contact. 3 sets of 10.",
                "source": "Elliott 2006; USTA Player Development"
            },
            "arm_not_loose": {
                "cue": "Think 'throw your racket' up at the ball — keep your arm completely loose, like throwing a ball",
                "why": "Tension in the arm during the serve kills racket head speed and leads to shoulder injuries",
                "drill": "Serve with intentional looseness: 50% power, 100% relaxation. Focus on the whip feeling. 20 serves.",
                "source": "Tennis Bros; Mouratoglou Academy"
            },
        },
        "follow_through": {
            "stopping_high": {
                "cue": "Let the racket finish down by your opposite hip — the full motion is up, through, and down across your body",
                "why": "Stopping the serve motion high indicates you're decelerating before contact instead of accelerating through it",
                "drill": "Serve and catch: serve, then reach down and touch your opposite knee with your racket hand. Forces full follow-through.",
                "source": "USTA Player Development"
            },
        },
    },
    "volley": {
        "ready_position": {
            "racket_too_low": {
                "cue": "Hands up, racket at chest height — be ready before the ball even crosses the net",
                "why": "A low racket position forces an upward swing instead of a compact forward punch",
                "drill": "Ready-position holds at the net: partner rapid-fires volleys, you reset hands to chest between each. 2 sets of 10.",
                "source": "USTA Player Development"
            },
            "no_split_step": {
                "cue": "Split step every time your opponent hits — land on both feet, light and balanced, then push to the ball",
                "why": "At the net, reaction time is everything. The split step loads your legs for an explosive push in either direction.",
                "drill": "Coach alternates forehand/backhand feeds at net. Focus on split step timing before each volley. 3 sets of 10.",
                "source": "ITF Coaching Manual"
            },
        },
        "contact_point": {
            "too_much_swing": {
                "cue": "Punch, don't swing — short and firm, let the incoming ball's pace do most of the work",
                "why": "A full swing at the net creates timing errors and sends balls long. The volley stroke should take 0.4-0.5 seconds total.",
                "drill": "Wall volleys from 6 feet: compact punch only, 50 reps alternating forehand and backhand.",
                "source": "ITF Coaching Manual; Elliott 1988"
            },
            "wrist_floppy": {
                "cue": "Firm wrist at contact — your racket face should stay stable like catching an egg in a frying pan",
                "why": "A loose wrist on volleys causes the racket face to twist on contact, sending balls in unpredictable directions",
                "drill": "Partner tosses balls by hand, you 'catch' them on a flat, firm racket face. Focus on zero racket twist. 20 reps.",
                "source": "USTA Player Development; My Tennis Life"
            },
            "contact_behind_body": {
                "cue": "Step forward and catch the ball out in front — your racket should be ahead of your body at contact",
                "why": "Contact behind the body angles the racket face upward, popping the ball up instead of driving it down",
                "drill": "Net drill: place a cone 1 foot ahead of your body. Contact every volley at or past the cone. 3 sets of 10.",
                "source": "ITF Coaching Manual; Tennis Predict"
            },
            "backswing_too_big": {
                "cue": "Tiny take-back — your racket should barely move backward before you punch forward",
                "why": "A big backswing on a volley means you're late to the ball. At the net, there's no time for a big swing.",
                "drill": "Start with your racket touching the net, then volley feeds with zero backswing. 3 sets of 10.",
                "source": "The Tennis Tribe; USTA"
            },
        },
        "footwork": {
            "no_step_forward": {
                "cue": "Step into every volley — transfer your weight forward through the shot",
                "why": "Staying static at the net leaves your volleys short and weak. Forward momentum adds depth and authority.",
                "drill": "Cross-step volley drill: step across with the opposite foot as you punch forward. 3 sets of 10 each side.",
                "source": "USTA Player Development; Tennis Universe"
            },
        },
    },
}


def format_cues_for_prompt() -> str:
    """Format the coaching cues database into a readable reference for the LLM prompt."""
    lines = []
    for stroke_type, phases in COACHING_CUES.items():
        lines.append(f"\n### {stroke_type.upper()}")
        for phase, deviations in phases.items():
            phase_display = phase.replace("_", " ").title()
            for deviation_key, entry in deviations.items():
                deviation_display = deviation_key.replace("_", " ")
                lines.append(f"- **{phase_display} / {deviation_display}**")
                lines.append(f'  Cue: "{entry["cue"]}"')
                lines.append(f"  Why: {entry['why']}")
                lines.append(f"  Drill: {entry['drill']}")
                lines.append(f"  Source: {entry['source']}")
    return "\n".join(lines)
