import unittest

from app.services.labelers import LabelerResult
from app.services.stroke_relabeler import _is_relabel_usable
from scripts.eval_labelers import _summarize_rows


class EvalLabelerSummaryTests(unittest.TestCase):
    def test_summary_counts_errors_and_unknowns_as_attempts(self):
        rows = [
            {
                "labeler": "candidate",
                "session_id": "s1",
                "stroke_idx": 0,
                "truth_stroke_type": "forehand",
                "pred_stroke_type": "forehand",
                "stroke_type_correct": True,
                "phase_mae_seconds": 0.1,
                "phase_mae_phases_scored": 6,
                "contact_point_abs_error": 0.05,
                "ordering_valid": True,
                "latency_ms": 1000,
                "cost_cents_estimate": 1.0,
                "error": None,
            },
            {
                "labeler": "candidate",
                "session_id": "s2",
                "stroke_idx": 0,
                "truth_stroke_type": "backhand",
                "pred_stroke_type": "unknown",
                "stroke_type_correct": False,
                "phase_mae_seconds": None,
                "phase_mae_phases_scored": 0,
                "contact_point_abs_error": None,
                "ordering_valid": False,
                "latency_ms": 900,
                "cost_cents_estimate": 0.5,
                "error": None,
            },
            {
                "labeler": "candidate",
                "session_id": "s3",
                "stroke_idx": 0,
                "truth_stroke_type": "serve",
                "pred_stroke_type": None,
                "stroke_type_correct": False,
                "phase_mae_seconds": None,
                "phase_mae_phases_scored": 0,
                "contact_point_abs_error": None,
                "ordering_valid": False,
                "latency_ms": None,
                "cost_cents_estimate": None,
                "error": "provider timeout",
            },
        ]

        summary = _summarize_rows(rows, ["candidate"])

        self.assertEqual(summary["candidate"]["attempted"], 3)
        self.assertEqual(summary["candidate"]["succeeded"], 2)
        self.assertEqual(summary["candidate"]["unknown"], 1)
        self.assertEqual(summary["candidate"]["errored"], 1)
        self.assertEqual(summary["candidate"]["stroke_type_accuracy"], 0.333)
        self.assertEqual(summary["candidate"]["phase_coverage_rate"], 0.333)
        self.assertEqual(summary["candidate"]["ordering_valid_rate"], 0.333)
        self.assertEqual(summary["candidate"]["contact_point_mae_seconds_mean"], 0.05)


class RelabelValidationTests(unittest.TestCase):
    def _result(self, **overrides):
        phases = {
            "ready_position": 10.1,
            "unit_turn": 10.4,
            "backswing": 10.8,
            "forward_swing": 11.2,
            "contact_point": 11.5,
            "follow_through": 11.9,
            "recovery": 12.4,
        }
        data = {
            "stroke_type": "forehand",
            "phases": phases,
            "confidence": 0.9,
        }
        data.update(overrides)
        return LabelerResult(**data)

    def test_relabel_requires_confidence_complete_phases_ordering_and_clip_bounds(self):
        self.assertTrue(_is_relabel_usable(self._result(), clip_start=10.0, clip_duration=3.0))

        self.assertFalse(
            _is_relabel_usable(self._result(confidence=0.7), clip_start=10.0, clip_duration=3.0)
        )

        missing = self._result()
        del missing.phases["recovery"]
        self.assertFalse(_is_relabel_usable(missing, clip_start=10.0, clip_duration=3.0))

        unordered = self._result()
        unordered.phases["contact_point"] = 10.6
        self.assertFalse(_is_relabel_usable(unordered, clip_start=10.0, clip_duration=3.0))

        out_of_bounds = self._result()
        out_of_bounds.phases["contact_point"] = 14.0
        self.assertFalse(_is_relabel_usable(out_of_bounds, clip_start=10.0, clip_duration=3.0))


if __name__ == "__main__":
    unittest.main()
