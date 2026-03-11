-- Tennique Database Schema
-- Deploy via Supabase SQL Editor or CLI

-- Enable UUID generation
create extension if not exists "uuid-ossp";

-- ============================================================
-- USERS
-- ============================================================
create table public.users (
  id uuid primary key default uuid_generate_v4(),
  apple_user_id text unique,
  email text,
  display_name text,
  subscription_tier text default 'free' check (subscription_tier in ('free', 'core', 'pro', 'elite')),
  free_analyses_used int default 0,
  free_analyses_limit int default 3,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================================
-- SESSIONS (recording sessions)
-- ============================================================
create table public.sessions (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references public.users(id) on delete cascade,
  title text,
  duration_seconds float,
  stroke_count int default 0,
  status text default 'recording' check (status in ('recording', 'processing', 'analyzing', 'ready', 'failed')),
  video_url text,
  thumbnail_url text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index idx_sessions_user_id on public.sessions(user_id);
create index idx_sessions_status on public.sessions(status);

-- ============================================================
-- STROKE ANALYSES
-- ============================================================
create table public.stroke_analyses (
  id uuid primary key default uuid_generate_v4(),
  session_id uuid references public.sessions(id) on delete cascade,
  stroke_index int not null,
  stroke_type text check (stroke_type in ('forehand', 'backhand', 'serve', 'volley')),
  overall_grade text,
  overall_score float,
  phase_scores jsonb default '{}',
  coaching_feedback jsonb default '[]',
  pose_data jsonb,
  key_frame_urls text[] default '{}',
  model_used text default 'gpt-4o',
  created_at timestamptz default now()
);

create index idx_stroke_analyses_session_id on public.stroke_analyses(session_id);

-- ============================================================
-- PROGRESS TRACKING
-- ============================================================
create table public.progress (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references public.users(id) on delete cascade,
  stroke_type text not null,
  metric_name text not null,
  metric_value float not null,
  recorded_at timestamptz default now()
);

create index idx_progress_user_id on public.progress(user_id);
create index idx_progress_stroke_type on public.progress(stroke_type);

-- ============================================================
-- USER FEEDBACK
-- ============================================================
create table public.feedback (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references public.users(id) on delete set null,
  session_id uuid references public.sessions(id) on delete set null,
  rating int check (rating between 1 and 5),
  comment text,
  feedback_type text default 'general' check (feedback_type in ('general', 'analysis_quality', 'bug_report', 'feature_request')),
  created_at timestamptz default now()
);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

-- Enable RLS on all tables
alter table public.users enable row level security;
alter table public.sessions enable row level security;
alter table public.stroke_analyses enable row level security;
alter table public.progress enable row level security;
alter table public.feedback enable row level security;

-- Users: can only read/update their own row
create policy "Users can view own profile"
  on public.users for select
  using (auth.uid() = id);

create policy "Users can update own profile"
  on public.users for update
  using (auth.uid() = id);

-- Sessions: users can CRUD their own sessions
create policy "Users can view own sessions"
  on public.sessions for select
  using (auth.uid() = user_id);

create policy "Users can create sessions"
  on public.sessions for insert
  with check (auth.uid() = user_id);

create policy "Users can update own sessions"
  on public.sessions for update
  using (auth.uid() = user_id);

create policy "Users can delete own sessions"
  on public.sessions for delete
  using (auth.uid() = user_id);

-- Stroke analyses: viewable if user owns the session
create policy "Users can view own stroke analyses"
  on public.stroke_analyses for select
  using (
    exists (
      select 1 from public.sessions
      where sessions.id = stroke_analyses.session_id
      and sessions.user_id = auth.uid()
    )
  );

create policy "Service role can insert stroke analyses"
  on public.stroke_analyses for insert
  with check (true);

-- Progress: users can CRUD their own
create policy "Users can view own progress"
  on public.progress for select
  using (auth.uid() = user_id);

create policy "Users can insert own progress"
  on public.progress for insert
  with check (auth.uid() = user_id);

-- Feedback: users can create, view own
create policy "Users can submit feedback"
  on public.feedback for insert
  with check (auth.uid() = user_id);

create policy "Users can view own feedback"
  on public.feedback for select
  using (auth.uid() = user_id);

-- ============================================================
-- SERVICE ROLE BYPASS (for backend API)
-- ============================================================
-- The service_role key bypasses RLS by default in Supabase.
-- Backend uses service_role for: creating stroke analyses,
-- updating session status, inserting progress data.

-- ============================================================
-- STORAGE BUCKETS
-- ============================================================
-- Run these in the Supabase dashboard under Storage:
-- 1. Create bucket: "videos" (public: false)
-- 2. Create bucket: "key-frames" (public: false)
-- 3. Create bucket: "thumbnails" (public: true)

-- Storage policies (run in SQL editor):
insert into storage.buckets (id, name, public) values ('videos', 'videos', false);
insert into storage.buckets (id, name, public) values ('key-frames', 'key-frames', false);
insert into storage.buckets (id, name, public) values ('thumbnails', 'thumbnails', true);

-- Videos: users can upload/read their own
create policy "Users can upload videos"
  on storage.objects for insert
  with check (bucket_id = 'videos' and auth.uid()::text = (storage.foldername(name))[1]);

create policy "Users can view own videos"
  on storage.objects for select
  using (bucket_id = 'videos' and auth.uid()::text = (storage.foldername(name))[1]);

-- Key frames: service role handles most, users can view own
create policy "Users can view own key frames"
  on storage.objects for select
  using (bucket_id = 'key-frames' and auth.uid()::text = (storage.foldername(name))[1]);

create policy "Service can upload key frames"
  on storage.objects for insert
  with check (bucket_id = 'key-frames');

-- Thumbnails: public read, authenticated upload
create policy "Anyone can view thumbnails"
  on storage.objects for select
  using (bucket_id = 'thumbnails');

create policy "Authenticated users can upload thumbnails"
  on storage.objects for insert
  with check (bucket_id = 'thumbnails' and auth.role() = 'authenticated');
