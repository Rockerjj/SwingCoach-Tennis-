"""
Curated coaching cue database.

Each entry maps a specific biomechanical deviation to a vetted coaching
response sourced from USTA, ITF, and peer-reviewed research. The LLM
must select from or closely adapt these cues rather than inventing advice.
"""

COACHING_CUES = {
    "forehand": {
        "ready_position": {
            "knees_too_straight": {
                "cue": "Sit into an athletic stance — bend your knees like you're about to steal a base",
                "why": "Straight legs lock the hips and prevent explosive first-step movement",
                "drill": "Split-step reaction drill: partner feeds random directions, 3 sets of 10 split steps",
                "source": "USTA Player Development"
            },
            "weight_on_heels": {
                "cue": "Stay light on the balls of your feet — feel like you could jump any direction",
                "why": "Heel-heavy stance adds 200-300ms to reaction time",
                "drill": "Ready-position holds with side shuffles on coach command, 2 sets of 30 seconds",
                "source": "USTA Player Development"
            },
        },
        "unit_turn": {
            "shoulder_rotation_low": {
                "cue": "Turn your chest so your front shoulder points toward the net post",
                "why": "Insufficient shoulder coil limits stored rotational energy — the swing starts weak",
                "drill": "Mirror unit-turn drill: racket on shoulder, check that your back is partially visible to opponent, 3 sets of 12 reps",
                "source": "USTA Player Development; Elliott, Reid & Crespo 2009"
            },
            "hip_rotation_low": {
                "cue": "Load into your back hip — feel your weight settle before you uncoil",
                "why": "Hip pre-loading creates the ground-up kinetic chain that generates effortless power",
                "drill": "Medicine ball rotational throws against a wall, 3 sets of 8 each side, same hip-first motion as your forehand",
                "source": "ITF Coaching Manual; Landlinger et al. 2010"
            },
            "late_preparation": {
                "cue": "Start your turn the moment you read the ball — racket back before the bounce",
                "why": "Late preparation compresses the entire swing and forces you to rush through contact",
                "drill": "Rally drill: partner yells 'turn' at feed, racket must be fully back before ball bounces, 3 sets of 15",
                "source": "USTA High Performance Coaching"
            },
        },
        "backswing": {
            "racket_too_low": {
                "cue": "Loop the racket higher on the take-back — think up before you go down",
                "why": "A low take-back shortens the swing arc and reduces racket head speed",
                "drill": "Shadow swings focusing on racket tip pointing up at the peak of the backswing, 3 sets of 10",
                "source": "ITF Coaching Manual"
            },
            "backswing_too_long": {
                "cue": "Keep it compact — your hands shouldn't go past your back hip",
                "why": "Over-extended backswing creates timing problems and reduces consistency",
                "drill": "Backswing with a towel tucked under your hitting arm, 20 reps (towel falls = too big)",
                "source": "Nick Bollettieri Tennis Academy"
            },
        },
        "forward_swing": {
            "arm_dominant_swing": {
                "cue": "Let your hips start the party — the arm just follows the body rotation",
                "why": "Arm-dominant swings top out at 60% of potential power. Hip-led swings use the full kinetic chain.",
                "drill": "Hit forehands with your feet planted, focus ONLY on feeling the hips fire first, 3 sets of 10",
                "source": "USTA Player Development; Landlinger et al. 2010"
            },
            "swing_path_flat": {
                "cue": "Brush up the back of the ball — swing low to high, not flat through",
                "why": "A flat swing path produces no topspin, reducing margin over the net and consistency",
                "drill": "Hit over a rope strung 3 feet above the net, 20 balls. Forces upward swing path.",
                "source": "ITF Coaching Manual"
            },
        },
        "contact_point": {
            "elbow_too_bent": {
                "cue": "Reach out and meet the ball further in front — full arm, long lever",
                "why": "Cramped contact with a bent elbow reduces power by 30-40% and limits control",
                "drill": "Self-drop drill: drop ball, freeze at contact with arm fully extended, check position, 4 sets of 6",
                "source": "USTA High Performance Coaching; Elliott 2006"
            },
            "contact_too_close": {
                "cue": "Create space between you and the ball — it should feel like you're reaching for it",
                "why": "Contact too close to the body jams the swing and prevents full extension",
                "drill": "Place a cone 2 feet in front of your hitting side, hit 20 balls making contact at the cone",
                "source": "USTA Player Development"
            },
            "contact_too_late": {
                "cue": "Hit the ball before it passes your front hip — meet it early, not late",
                "why": "Late contact shifts the swing from forward to across, losing directional control",
                "drill": "Partner feeds, focus on contacting every ball when it's in front of your lead foot, 3 sets of 10",
                "source": "USTA Player Development"
            },
            "contact_too_high": {
                "cue": "Let the ball drop into your strike zone — waist to chest height",
                "why": "Hitting above shoulder height forces an awkward arm position and reduces power",
                "drill": "Feeding drill at medium height, deliberately let high balls drop, 20 reps",
                "source": "ITF Coaching Manual"
            },
        },
        "follow_through": {
            "deceleration_early": {
                "cue": "Swing through three balls, not one — accelerate past contact",
                "why": "Early deceleration before contact reduces racket speed at impact and kills topspin",
                "drill": "Extended follow-through shadow swings: push the racket face forward as long as possible before wrapping, 3 sets of 10",
                "source": "USTA Player Development"
            },
            "finish_too_low": {
                "cue": "Let the racket finish across your body at shoulder height or above",
                "why": "A low finish indicates a flat swing path, limiting topspin and net clearance",
                "drill": "Catch-the-racket drill: non-dominant hand catches the racket at the shoulder on follow-through, 20 reps",
                "source": "ITF Coaching Manual"
            },
        },
        "recovery": {
            "no_split_step": {
                "cue": "Split step as your opponent makes contact — land light, ready to push off",
                "why": "Without a split step, you're always a half-step behind on the next ball",
                "drill": "Hit-and-recover: hit forehand, sprint to center, split step, repeat 3 sets of 10",
                "source": "USTA Player Development"
            },
            "slow_recovery": {
                "cue": "Reset to center immediately — don't admire your shot",
                "why": "Standing and watching opens the court for your opponent's next ball",
                "drill": "Partner hits alternating sides, you must touch center cone between every shot, 2 sets of 20",
                "source": "USTA Player Development"
            },
        },
    },
    "backhand": {
        "unit_turn": {
            "shoulder_rotation_low": {
                "cue": "Turn your shoulders until your chin is near your front shoulder",
                "why": "Insufficient coil on the backhand limits the rotational energy available for the forward swing",
                "drill": "Shadow backhand unit turns with 2-second hold at full rotation, 3 sets of 10",
                "source": "USTA Player Development"
            },
            "hands_too_far_from_body": {
                "cue": "Keep your hands close to your body on the turn — compact and connected",
                "why": "Wide hands disconnect the arms from the body's rotation, reducing power transfer",
                "drill": "Towel drill: tuck towel between arm and body during turn, 20 reps",
                "source": "ITF Coaching Manual"
            },
        },
        "contact_point": {
            "elbow_too_straight": {
                "cue": "Keep a slight bend in both arms at contact — firm but not locked",
                "why": "On a two-handed backhand, locked elbows reduce control and stress the joints",
                "drill": "Drop-feed backhands freezing at contact, check for slight elbow bend, 4 sets of 6",
                "source": "Korean J Applied Biomechanics"
            },
            "contact_too_late": {
                "cue": "Meet the ball out front — your top hand should drive forward, not across",
                "why": "Late backhand contact forces a push instead of a drive, losing depth and pace",
                "drill": "Feed drill with contact point marker cone, 20 reps focusing on early contact",
                "source": "USTA Player Development"
            },
        },
        "follow_through": {
            "truncated_finish": {
                "cue": "Finish high and fully across your body — don't stop at contact",
                "why": "A short follow-through indicates deceleration before impact",
                "drill": "Shadow backhand swings finishing with racket pointing to the back fence, 3 sets of 10",
                "source": "ITF Coaching Manual"
            },
        },
    },
    "serve": {
        "trophy_position": {
            "knee_bend_insufficient": {
                "cue": "Bend your knees deeper — load the legs like you're about to jump",
                "why": "Leg drive contributes 10-15% of serve speed. Straight legs eliminate this energy source.",
                "drill": "Serve from the knee-bend position: pause in trophy, check deep bend, then serve, 3 sets of 8",
                "source": "Frontiers 2024 meta-analysis"
            },
            "toss_inconsistent": {
                "cue": "Release the ball at eye level with a straight arm — let it float up, don't throw it",
                "why": "An inconsistent toss forces compensations in the swing, killing accuracy",
                "drill": "10 tosses in a row catching the ball on the racket face without swinging, 3 sets",
                "source": "USTA Player Development"
            },
        },
        "contact_point": {
            "elbow_not_extended": {
                "cue": "Reach for the sky — contact at full extension, as high as you can",
                "why": "Every inch of contact height adds angle and margin over the net",
                "drill": "Serve to targets on the wall at maximum reach, 20 reps focusing on height",
                "source": "Frontiers 2024 meta-analysis"
            },
            "no_pronation": {
                "cue": "Turn the doorknob through contact — pronate your forearm naturally",
                "why": "Pronation adds 10-20% serve speed and is essential for controlling spin",
                "drill": "Pronation isolation: serve into the fence from 10 feet, focus only on the wrist turn, 3 sets of 10",
                "source": "Elliott 2006; USTA Player Development"
            },
        },
    },
    "volley": {
        "ready_position": {
            "racket_too_low": {
                "cue": "Hands up, racket at chest height — be ready before the ball arrives",
                "why": "A low racket forces a big upswing instead of a compact punch forward",
                "drill": "Ready position holds at net, partner hits random volleys, 2 sets of 10",
                "source": "USTA Player Development"
            },
        },
        "contact_point": {
            "too_much_swing": {
                "cue": "Punch, don't swing — short and firm, let the ball's pace do the work",
                "why": "A full swing at the net creates timing errors and sends balls long",
                "drill": "Wall volleys from 6 feet: compact punch only, 50 reps alternating sides",
                "source": "ITF Coaching Manual; Elliott 1988"
            },
            "wrist_floppy": {
                "cue": "Lock your wrist at contact — firm hand, solid racket face",
                "why": "A loose wrist on volleys causes the racket to twist, losing directional control",
                "drill": "Volley catches: partner tosses, you catch with racket face flat and firm, 20 reps",
                "source": "USTA Player Development"
            },
            "contact_behind_body": {
                "cue": "Step forward and catch the ball in front — racket ahead of your body",
                "why": "Contact behind the body on volleys pushes the ball up instead of forward",
                "drill": "Net drill: place cone 1 foot ahead, contact every volley at the cone, 3 sets of 10",
                "source": "ITF Coaching Manual"
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
                lines.append(f"  Cue: \"{entry['cue']}\"")
                lines.append(f"  Why: {entry['why']}")
                lines.append(f"  Drill: {entry['drill']}")
                lines.append(f"  Source: {entry['source']}")
    return "\n".join(lines)
