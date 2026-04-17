-- TennisIQ Database Schema
-- Run this in your Supabase SQL Editor to set up the database

-- Enable UUID generation
create extension if not exists "uuid-ossp";

-- User profiles
create table if not exists user_profiles (
    id text primary key,
    display_name text not null default '',
    skill_level text not null default 'beginner' check (skill_level in ('beginner', 'intermediate', 'advanced')),
    subscription_tier text not null default 'free' check (subscription_tier in ('free', 'monthly', 'annual')),
    free_analyses_used integer not null default 0,
    created_at timestamptz not null default now()
);

-- Sessions
create table if not exists sessions (
    id text primary key default uuid_generate_v4()::text,
    user_id text not null references user_profiles(id) on delete cascade,
    recorded_at timestamptz not null default now(),
    duration_seconds integer not null default 0,
    status text not null default 'processing' check (status in ('recording', 'processing', 'analyzing', 'ready', 'failed')),
    overall_grade text,
    top_priority text,
    tactical_notes jsonb not null default '[]'::jsonb,
    created_at timestamptz not null default now()
);

create index idx_sessions_user_id on sessions(user_id);
create index idx_sessions_recorded_at on sessions(recorded_at desc);
create index idx_sessions_status on sessions(status);

-- Stroke analyses
create table if not exists stroke_analyses (
    id text primary key default uuid_generate_v4()::text,
    session_id text not null references sessions(id) on delete cascade,
    stroke_type text not null check (stroke_type in ('forehand', 'backhand', 'serve', 'volley', 'unknown')),
    timestamp float not null,
    grade text not null,
    mechanics jsonb not null default '{}'::jsonb,
    overlay_instructions jsonb not null default '{}'::jsonb,
    phase_breakdown jsonb,
    analysis_categories jsonb,
    pro_comparison jsonb,
    created_at timestamptz not null default now()
);

create index idx_stroke_analyses_session_id on stroke_analyses(session_id);

-- Analysis runs (per-call cost and latency tracking)
-- One row per /sessions/analyze attempt, populated by the backend regardless
-- of which coaching provider was used. Drives unit-economics decisions and
-- ongoing provider comparison once the eval is shipped.
create table if not exists analysis_runs (
    id text primary key default uuid_generate_v4()::text,
    session_id text references sessions(id) on delete set null,
    user_id text references user_profiles(id) on delete set null,
    provider text not null,
    model text not null,
    input_tokens integer,
    output_tokens integer,
    cost_cents integer,
    latency_ms integer,
    success boolean not null default true,
    error text,
    created_at timestamptz not null default now()
);

create index if not exists idx_analysis_runs_session_id on analysis_runs(session_id);
create index if not exists idx_analysis_runs_provider on analysis_runs(provider);
create index if not exists idx_analysis_runs_created_at on analysis_runs(created_at desc);

-- Progress snapshots
create table if not exists progress_snapshots (
    id text primary key default uuid_generate_v4()::text,
    user_id text not null references user_profiles(id) on delete cascade,
    snapshot_date date not null,
    overall_score float not null default 0,
    forehand_score float not null default 0,
    backhand_score float not null default 0,
    serve_score float not null default 0,
    volley_score float not null default 0,
    trending_direction text not null default 'stable' check (trending_direction in ('improving', 'stable', 'declining')),
    created_at timestamptz not null default now(),
    unique(user_id, snapshot_date)
);

create index idx_progress_user_date on progress_snapshots(user_id, snapshot_date desc);

-- Row Level Security
alter table user_profiles enable row level security;
alter table sessions enable row level security;
alter table stroke_analyses enable row level security;
alter table progress_snapshots enable row level security;

-- RLS Policies: users can only access their own data
create policy "Users can read own profile" on user_profiles
    for select using (auth.uid()::text = id);

create policy "Users can update own profile" on user_profiles
    for update using (auth.uid()::text = id);

create policy "Users can insert own profile" on user_profiles
    for insert with check (auth.uid()::text = id);

create policy "Users can read own sessions" on sessions
    for select using (auth.uid()::text = user_id);

create policy "Users can read own stroke analyses" on stroke_analyses
    for select using (
        session_id in (select id from sessions where user_id = auth.uid()::text)
    );

create policy "Users can read own progress" on progress_snapshots
    for select using (auth.uid()::text = user_id);

-- Service role bypasses RLS for backend writes
-- (The service key used by FastAPI has full access)

-- Storage bucket for key frame images (temporary)
insert into storage.buckets (id, name, public)
values ('session-frames', 'session-frames', false)
on conflict do nothing;
