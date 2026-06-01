-- Career-Ops Schema v1.0 - AWS RDS PostgreSQL
-- Autonomous intelligent job prospection system

-- Create schema if not exists
CREATE SCHEMA IF NOT EXISTS career_ops;

-- Profile table: parsed from CV
CREATE TABLE IF NOT EXISTS career_ops.career_profile (
    id SERIAL PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(20),
    location VARCHAR(255),
    remote_preference VARCHAR(50) DEFAULT 'remote_only',
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
    cv_parsed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Jobs table: normalized from all sources
CREATE TABLE IF NOT EXISTS career_ops.jobs (
    id SERIAL PRIMARY KEY,

    -- Source tracking
    source VARCHAR(50) NOT NULL,         -- 'remoteok' | 'indeed' | 'wwr'
    source_id VARCHAR(255),
    source_url TEXT NOT NULL,

    -- Job details
    title VARCHAR(500) NOT NULL,
    company VARCHAR(255) NOT NULL,
    company_url TEXT,
    description TEXT,
    description_clean TEXT,

    -- Classification
    job_type VARCHAR(50),                -- 'full_time' | 'contract'
    seniority VARCHAR(50),               -- 'junior' | 'mid' | 'senior'
    remote_type VARCHAR(50),             -- 'fully_remote' | 'hybrid'
    location_required VARCHAR(255),

    -- Compensation
    salary_min INTEGER,
    salary_max INTEGER,
    salary_currency VARCHAR(10) DEFAULT 'USD',
    salary_period VARCHAR(50) DEFAULT 'yearly',

    -- Extracted from description
    required_skills TEXT[],
    preferred_skills TEXT[],
    experience_years_min INTEGER,
    experience_years_max INTEGER,

    -- Dates
    posted_at TIMESTAMP,
    expires_at TIMESTAMP,
    scraped_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Dedup fingerprint
    fingerprint VARCHAR(255) UNIQUE,
    is_active BOOLEAN DEFAULT true,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Matching scores: (profile, job) → score
CREATE TABLE IF NOT EXISTS career_ops.job_matches (
    id SERIAL PRIMARY KEY,
    profile_id INTEGER REFERENCES career_ops.career_profile(id),
    job_id INTEGER REFERENCES career_ops.jobs(id) ON DELETE CASCADE,

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
    status VARCHAR(50) DEFAULT 'new',    -- 'new' | 'sent' | 'applied' | 'rejected'
    sent_at TIMESTAMP,
    applied_at TIMESTAMP,
    user_feedback VARCHAR(50),           -- 'interested' | 'skip' | 'applied'

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(profile_id, job_id)
);

-- Scraper run log
CREATE TABLE IF NOT EXISTS career_ops.scraper_runs (
    id SERIAL PRIMARY KEY,
    source VARCHAR(50) NOT NULL,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    jobs_found INTEGER DEFAULT 0,
    jobs_new INTEGER DEFAULT 0,
    jobs_duplicate INTEGER DEFAULT 0,
    status VARCHAR(50) DEFAULT 'running',
    error_message TEXT,
    duration_seconds NUMERIC(6,1),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Application tracking
CREATE TABLE IF NOT EXISTS career_ops.applications (
    id SERIAL PRIMARY KEY,
    job_id INTEGER REFERENCES career_ops.jobs(id),
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    method VARCHAR(255),
    cover_letter_used BOOLEAN DEFAULT false,
    response_received BOOLEAN DEFAULT false,
    response_type VARCHAR(50),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_jobs_source ON career_ops.jobs(source);
CREATE INDEX IF NOT EXISTS idx_jobs_posted_at ON career_ops.jobs(posted_at DESC);
CREATE INDEX IF NOT EXISTS idx_jobs_active ON career_ops.jobs(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_jobs_fingerprint ON career_ops.jobs(fingerprint);
CREATE INDEX IF NOT EXISTS idx_matches_score ON career_ops.job_matches(score_total DESC);
CREATE INDEX IF NOT EXISTS idx_matches_status ON career_ops.job_matches(status);
CREATE INDEX IF NOT EXISTS idx_matches_profile_job ON career_ops.job_matches(profile_id, job_id);
CREATE INDEX IF NOT EXISTS idx_scraper_runs_source ON career_ops.scraper_runs(source, started_at DESC);

-- Insert Sidoine's profile
INSERT INTO career_ops.career_profile (
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
    CURRENT_TIMESTAMP
) ON CONFLICT DO NOTHING;
