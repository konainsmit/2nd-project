create extension if not exists "pgcrypto";

create type candidate_status as enum ('shortlisted', 'review', 'rejected', 'scheduled');
create type app_role as enum ('recruiter', 'candidate');

create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  role app_role not null default 'recruiter',
  created_at timestamptz not null default now()
);

create table if not exists job_postings (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  department text not null,
  min_experience integer not null default 0,
  required_skills jsonb not null default '[]'::jsonb,
  invite_cutoff integer not null default 80,
  reject_cutoff integer not null default 50,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists candidates (
  id uuid primary key default gen_random_uuid(),
  job_posting_id uuid not null references job_postings(id) on delete cascade,
  name text not null,
  email text not null,
  current_role text not null,
  years_experience numeric(4,1) not null default 0,
  status candidate_status not null default 'review',
  source_file text,
  uploaded_at timestamptz not null default now()
);

create table if not exists parsed_resumes (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null unique references candidates(id) on delete cascade,
  extracted_text text not null default '',
  normalized_skills jsonb not null default '[]'::jsonb,
  experience_timeline jsonb not null default '[]'::jsonb,
  parser_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists evaluations (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references candidates(id) on delete cascade,
  match_score integer not null check (match_score between 0 and 100),
  matched_skills jsonb not null default '[]'::jsonb,
  missing_skills jsonb not null default '[]'::jsonb,
  executive_summary text not null default '',
  red_flags jsonb not null default '[]'::jsonb,
  reasoning_state text not null default 'Generating Match Dossier',
  model text not null default 'gpt-4o-mini',
  latency_ms integer,
  created_at timestamptz not null default now()
);

create table if not exists interview_slots (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references candidates(id) on delete cascade,
  interviewer text not null,
  stage text not null,
  starts_at timestamptz not null,
  calendar_event_id text,
  invite_url text,
  status text not null default 'held',
  created_at timestamptz not null default now()
);

create index if not exists candidates_job_posting_idx on candidates(job_posting_id);
create index if not exists evaluations_candidate_idx on evaluations(candidate_id, created_at desc);
create index if not exists interview_slots_candidate_idx on interview_slots(candidate_id);

alter table job_postings enable row level security;
alter table profiles enable row level security;
alter table candidates enable row level security;
alter table parsed_resumes enable row level security;
alter table evaluations enable row level security;
alter table interview_slots enable row level security;

create policy "users read own profile" on profiles for select to authenticated using (auth.uid() = id);
create policy "users create own profile" on profiles for insert to authenticated with check (auth.uid() = id);
create policy "authenticated users manage job postings" on job_postings for all to authenticated using (true) with check (true);
create policy "authenticated users manage candidates" on candidates for all to authenticated using (true) with check (true);
create policy "authenticated users manage parsed resumes" on parsed_resumes for all to authenticated using (true) with check (true);
create policy "authenticated users manage evaluations" on evaluations for all to authenticated using (true) with check (true);
create policy "authenticated users manage interview slots" on interview_slots for all to authenticated using (true) with check (true);
