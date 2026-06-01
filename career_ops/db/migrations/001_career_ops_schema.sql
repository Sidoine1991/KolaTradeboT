-- Career-Ops Schema v1.0
-- Autonomous intelligent job prospection system

-- Profile table: parsed from CV
CREATE TABLE IF NOT EXISTS career_profile (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    location TEXT,
    remote_preference TEXT DEFAULT 'remote_only',
    target_roles TEXT[],
    years_experience NUMERIC(3,1),

    -- Skill taxonomy (hierarchical)
    skills_primary TEXT[],        -- ['Python', 'SQL', 'R', 'Power BI']
    skills_secondary TEXT[],      -- ['Pandas', 'Plotly', 'React']
    skills_tools TEXT[],          -- ['Git', 'Docker']

    -- Experience keywords for matching
    experience_keywords TEXT[],

    -- Preferences
    min_salary_usd INTEGER,
    languages TEXT[],

    -- Metadata
    cv_file_path TEXT,
    cv_parsed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Jobs table: normalized from all sources
CREATE TABLE IF NOT EXISTS jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Source tracking
    source TEXT NOT NULL,         -- 'remoteok' | 'indeed' | 'wwr'
    source_id TEXT,
    source_url TEXT NOT NULL,

    -- Job details
    title TEXT NOT NULL,
    company TEXT NOT NULL,
    company_url TEXT,
    description TEXT,
    description_clean TEXT,

    -- Classification
    job_type TEXT,                -- 'full_time' | 'contract'
    seniority TEXT,               -- 'junior' | 'mid' | 'senior'
    remote_type TEXT,             -- 'fully_remote' | 'hybrid'
    location_required TEXT,

    -- Compensation
    salary_min INTEGER,
    salary_max INTEGER,
    salary_currency TEXT DEFAULT 'USD',
    salary_period TEXT DEFAULT 'yearly',

    -- Extracted from description
    required_skills TEXT[],
    preferred_skills TEXT[],
    experience_years_min INTEGER,
    experience_years_max INTEGER,

    -- Dates
    posted_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    scraped_at TIMESTAMPTZ DEFAULT now(),

    -- Dedup fingerprint
    fingerprint TEXT UNIQUE,
    is_active BOOLEAN DEFAULT true,

    created_at TIMESTAMPTZ DEFAULT now()
);

-- Matching scores: (profile, job) → score
CREATE TABLE IF NOT EXISTS job_matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID REFERENCES career_profile(id),
    job_id UUID REFERENCES jobs(id) ON DELETE CASCADE,

    -- Component scores (0.0 to 1.0)
    score_skills_primary NUMERIC(4,3),
    score_skills_secondary NUMERIC(4,3),
    score_experience NUMERIC(4,3),
    score_remote_fit NUMERIC(4,3),
    score_seniority_fit NUMERIC(4,3),
    score_salary_fit NUMERIC(4,3),
    score_semantic NUMERIC(4,3),
    score_recency NUMERIC(4,3),

    -- Final weighted score [0, 1]
    score_total NUMERIC(4,3) NOT NULL,

    -- Status workflow
    status TEXT DEFAULT 'new',    -- 'new' | 'sent' | 'applied' | 'rejected'
    sent_at TIMESTAMPTZ,
    applied_at TIMESTAMPTZ,
    user_feedback TEXT,           -- 'interested' | 'skip' | 'applied'

    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(profile_id, job_id)
);

-- Scraper run log
CREATE TABLE IF NOT EXISTS scraper_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source TEXT NOT NULL,
    started_at TIMESTAMPTZ DEFAULT now(),
    completed_at TIMESTAMPTZ,
    jobs_found INTEGER DEFAULT 0,
    jobs_new INTEGER DEFAULT 0,
    jobs_duplicate INTEGER DEFAULT 0,
    status TEXT DEFAULT 'running',
    error_message TEXT,
    duration_seconds NUMERIC(6,1),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Application tracking
CREATE TABLE IF NOT EXISTS applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID REFERENCES jobs(id),
    applied_at TIMESTAMPTZ DEFAULT now(),
    method TEXT,
    cover_letter_used BOOLEAN DEFAULT false,
    response_received BOOLEAN DEFAULT false,
    response_type TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_jobs_source ON jobs(source);
CREATE INDEX IF NOT EXISTS idx_jobs_posted_at ON jobs(posted_at DESC);
CREATE INDEX IF NOT EXISTS idx_jobs_active ON jobs(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_jobs_fingerprint ON jobs(fingerprint);
CREATE INDEX IF NOT EXISTS idx_matches_score ON job_matches(score_total DESC);
CREATE INDEX IF NOT EXISTS idx_matches_status ON job_matches(status);
CREATE INDEX IF NOT EXISTS idx_matches_profile_job ON job_matches(profile_id, job_id);
CREATE INDEX IF NOT EXISTS idx_scraper_runs_source ON scraper_runs(source, started_at DESC);

-- Insert Sidoine's profile
INSERT INTO career_profile (
    full_name, email, phone, location, remote_preference,
    target_roles, years_experience, skills_primary, skills_secondary,
    skills_tools, experience_keywords, min_salary_usd, languages,
    cv_file_path, cv_parsed_at
) VALUES (
    'Sidoine Kolaolé YEBADOKPO',
    'syebadokpo@gmail.com',
    '+229 01 96 91 13 46',
    'Cotonou, Benin',
    'remote_only',
    ARRAY['Data Analyst', 'Python Developer', 'Full-Stack Developer', 'Data Scientist', 'Web Developer'],
    4.5,
    ARRAY['Python', 'SQL', 'R', 'Power BI', 'Tableau'],
    ARRAY['Pandas', 'NumPy', 'Plotly', 'Streamlit', 'React', 'Node.js'],
    ARRAY['Git', 'PostgreSQL'],
    ARRAY['data pipeline', 'ETL', 'data analysis', 'dashboard', 'API', 'automation', 'reporting', 'visualization', 'machine learning'],
    40000,
    ARRAY['French', 'English'],
    'D:\Perso\Remote job\CV_Sidoine_YEBADOKPO_PNUD.pdf',
    NOW()
) ON CONFLICT DO NOTHING;
