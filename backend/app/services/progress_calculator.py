import logging
from datetime import datetime, timedelta
from supabase import Client

logger = logging.getLogger(__name__)


class ProgressCalculator:
    def __init__(self, supabase: Client):
        self.supabase = supabase

    async def update_progress(self, user_id: str, session_id: str) -> dict:
        result = (
            self.supabase.table("stroke_analyses")
            .select("*")
            .eq("session_id", session_id)
            .execute()
        )
        strokes = result.data or []

        if not strokes:
            return {}

        stroke_scores: dict[str, list[float]] = {}
        for stroke in strokes:
            stype = stroke["stroke_type"]
            mechanics = stroke.get("mechanics", {})
            scores = [
                v["score"]
                for v in mechanics.values()
                if isinstance(v, dict) and "score" in v
            ]
            if scores:
                stroke_scores.setdefault(stype, []).extend(scores)

        session_stroke_avgs = {
            stype: sum(scores) / len(scores) * 10
            for stype, scores in stroke_scores.items()
        }

        thirty_days_ago = (datetime.utcnow() - timedelta(days=30)).isoformat()
        history_result = (
            self.supabase.table("progress_snapshots")
            .select("*")
            .eq("user_id", user_id)
            .gte("snapshot_date", thirty_days_ago)
            .order("snapshot_date", desc=True)
            .execute()
        )
        history = history_result.data or []

        if len(history) >= 2:
            recent_avg = history[0].get("overall_score", 0)
            older_avg = history[-1].get("overall_score", 0)
            if recent_avg > older_avg + 2:
                trend = "improving"
            elif recent_avg < older_avg - 2:
                trend = "declining"
            else:
                trend = "stable"
        else:
            trend = "stable"

        overall = sum(session_stroke_avgs.values()) / max(len(session_stroke_avgs), 1)

        weakest = min(session_stroke_avgs, key=session_stroke_avgs.get, default="forehand")
        focus = f"Focus on improving your {weakest} this week"

        snapshot = {
            "user_id": user_id,
            "snapshot_date": datetime.utcnow().date().isoformat(),
            "overall_score": round(overall, 1),
            "forehand_score": round(session_stroke_avgs.get("forehand", 0), 1),
            "backhand_score": round(session_stroke_avgs.get("backhand", 0), 1),
            "serve_score": round(session_stroke_avgs.get("serve", 0), 1),
            "volley_score": round(session_stroke_avgs.get("volley", 0), 1),
            "trending_direction": trend,
        }

        self.supabase.table("progress_snapshots").upsert(snapshot).execute()
        return {**snapshot, "weekly_focus": focus}

    async def get_progress(self, user_id: str) -> dict:
        latest = (
            self.supabase.table("progress_snapshots")
            .select("*")
            .eq("user_id", user_id)
            .order("snapshot_date", desc=True)
            .limit(1)
            .execute()
        )

        ninety_days_ago = (datetime.utcnow() - timedelta(days=90)).isoformat()
        history = (
            self.supabase.table("progress_snapshots")
            .select("snapshot_date, overall_score")
            .eq("user_id", user_id)
            .gte("snapshot_date", ninety_days_ago)
            .order("snapshot_date")
            .execute()
        )

        week_ago = (datetime.utcnow() - timedelta(days=7)).isoformat()
        month_ago = (datetime.utcnow() - timedelta(days=30)).isoformat()

        weekly_sessions = (
            self.supabase.table("sessions")
            .select("id", count="exact")
            .eq("user_id", user_id)
            .eq("status", "ready")
            .gte("recorded_at", week_ago)
            .execute()
        )

        monthly_sessions = (
            self.supabase.table("sessions")
            .select("id", count="exact")
            .eq("user_id", user_id)
            .eq("status", "ready")
            .gte("recorded_at", month_ago)
            .execute()
        )

        snap = latest.data[0] if latest.data else {}
        weakest = "forehand"
        if snap:
            scores = {
                "forehand": snap.get("forehand_score", 0),
                "backhand": snap.get("backhand_score", 0),
                "serve": snap.get("serve_score", 0),
                "volley": snap.get("volley_score", 0),
            }
            weakest = min(scores, key=scores.get)

        return {
            "overall_score": snap.get("overall_score", 0),
            "forehand_score": snap.get("forehand_score", 0),
            "backhand_score": snap.get("backhand_score", 0),
            "serve_score": snap.get("serve_score", 0),
            "volley_score": snap.get("volley_score", 0),
            "trend": snap.get("trending_direction", "stable"),
            "weekly_focus": f"Focus on improving your {weakest} this week",
            "sessions_this_week": weekly_sessions.count or 0,
            "sessions_this_month": monthly_sessions.count or 0,
            "history": [
                {"date": h["snapshot_date"], "score": h["overall_score"]}
                for h in (history.data or [])
            ],
        }
