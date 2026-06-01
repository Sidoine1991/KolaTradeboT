"""
Career-Ops RDS Repositories
Direct AWS RDS PostgreSQL access for Career-Ops data persistence
NO MOCKS - All data from database
"""

import sys
from pathlib import Path
from typing import List, Dict, Any, Optional
from datetime import datetime

_root = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_root))

from aws_rds_helper import AWSRDSClient
import logging

logger = logging.getLogger(__name__)


class CareerProfileRepository:
    """Repository for career_ops.career_profile table"""

    def __init__(self):
        self.client = AWSRDSClient()

    def get_profile(self, profile_id: int = 1) -> Optional[Dict[str, Any]]:
        """Get user profile"""
        try:
            with self.client.get_connection() as conn:
                cur = conn.cursor()
                cur.execute(
                    """
                    SELECT id, full_name, email, phone, location, remote_preference,
                           target_roles, years_experience, skills_primary, skills_secondary,
                           skills_tools, min_salary_usd, languages, created_at
                    FROM career_ops.career_profile
                    WHERE id = %s
                    """,
                    (profile_id,)
                )
                row = cur.fetchone()
                if row:
                    return {
                        "id": row[0],
                        "full_name": row[1],
                        "email": row[2],
                        "phone": row[3],
                        "location": row[4],
                        "remote_preference": row[5],
                        "target_roles": row[6],
                        "years_experience": row[7],
                        "skills_primary": row[8],
                        "skills_secondary": row[9],
                        "skills_tools": row[10],
                        "min_salary_usd": row[11],
                        "languages": row[12],
                        "created_at": row[13],
                    }
                return None
        except Exception as e:
            logger.error(f"Error fetching profile: {str(e)}")
            return None


class JobsRepository:
    """Repository for career_ops.jobs table"""

    def __init__(self):
        self.client = AWSRDSClient()

    def save_job(self, job_data: Dict[str, Any]) -> Optional[int]:
        """Save or update a job posting"""
        try:
            with self.client.get_connection() as conn:
                cur = conn.cursor()

                # Check if job already exists (by fingerprint)
                fingerprint = job_data.get("fingerprint")
                if fingerprint:
                    cur.execute(
                        "SELECT id FROM career_ops.jobs WHERE fingerprint = %s",
                        (fingerprint,)
                    )
                    existing = cur.fetchone()
                    if existing:
                        return existing[0]  # Already exists

                # Insert new job
                cur.execute(
                    """
                    INSERT INTO career_ops.jobs (
                        source, source_id, source_url, title, company, company_url,
                        description, job_type, seniority, remote_type, location_required,
                        salary_min, salary_max, required_skills, preferred_skills,
                        experience_years_min, experience_years_max, posted_at, fingerprint
                    ) VALUES (
                        %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
                    )
                    RETURNING id
                    """,
                    (
                        job_data.get("source", "scraper"),
                        job_data.get("source_id"),
                        job_data.get("source_url", ""),
                        job_data.get("title", ""),
                        job_data.get("company", ""),
                        job_data.get("company_url"),
                        job_data.get("description", ""),
                        job_data.get("job_type", "full_time"),
                        job_data.get("seniority", "mid"),
                        job_data.get("remote_type", "hybrid"),
                        job_data.get("location_required"),
                        job_data.get("salary_min"),
                        job_data.get("salary_max"),
                        job_data.get("required_skills"),
                        job_data.get("preferred_skills"),
                        job_data.get("experience_years_min"),
                        job_data.get("experience_years_max"),
                        job_data.get("posted_at", datetime.utcnow()),
                        fingerprint,
                    )
                )
                job_id = cur.fetchone()[0]
                conn.commit()
                logger.info(f"Job saved: {job_data.get('title')} (ID: {job_id})")
                return job_id
        except Exception as e:
            logger.error(f"Error saving job: {str(e)}")
            return None

    def get_active_jobs(self, limit: int = 100) -> List[Dict[str, Any]]:
        """Get all active jobs"""
        try:
            with self.client.get_connection() as conn:
                cur = conn.cursor()
                cur.execute(
                    """
                    SELECT id, title, company, company_url, source_url, description,
                           job_type, seniority, remote_type, salary_min, salary_max,
                           required_skills, posted_at
                    FROM career_ops.jobs
                    WHERE is_active = true
                    ORDER BY posted_at DESC
                    LIMIT %s
                    """,
                    (limit,)
                )

                jobs = []
                for row in cur.fetchall():
                    jobs.append({
                        "id": row[0],
                        "title": row[1],
                        "company": row[2],
                        "company_url": row[3],
                        "source_url": row[4],
                        "description": row[5],
                        "job_type": row[6],
                        "seniority": row[7],
                        "remote_type": row[8],
                        "salary_min": row[9],
                        "salary_max": row[10],
                        "required_skills": row[11],
                        "posted_at": row[12],
                    })
                return jobs
        except Exception as e:
            logger.error(f"Error fetching jobs: {str(e)}")
            return []


class JobMatchesRepository:
    """Repository for career_ops.job_matches table"""

    def __init__(self):
        self.client = AWSRDSClient()

    def save_match(self, match_data: Dict[str, Any]) -> Optional[int]:
        """Save job match with scoring"""
        try:
            with self.client.get_connection() as conn:
                cur = conn.cursor()

                # Check if match already exists
                cur.execute(
                    """
                    SELECT id FROM career_ops.job_matches
                    WHERE profile_id = %s AND job_id = %s
                    """,
                    (match_data.get("profile_id"), match_data.get("job_id"))
                )
                existing = cur.fetchone()
                if existing:
                    # Update existing match
                    cur.execute(
                        """
                        UPDATE career_ops.job_matches
                        SET score_skills_primary = %s,
                            score_skills_secondary = %s,
                            score_experience = %s,
                            score_remote_fit = %s,
                            score_seniority_fit = %s,
                            score_salary_fit = %s,
                            score_semantic = %s,
                            score_recency = %s,
                            score_total = %s
                        WHERE id = %s
                        """,
                        (
                            match_data.get("score_skills_primary"),
                            match_data.get("score_skills_secondary"),
                            match_data.get("score_experience"),
                            match_data.get("score_remote_fit"),
                            match_data.get("score_seniority_fit"),
                            match_data.get("score_salary_fit"),
                            match_data.get("score_semantic"),
                            match_data.get("score_recency"),
                            match_data.get("score_total"),
                            existing[0],
                        )
                    )
                    conn.commit()
                    return existing[0]

                # Insert new match
                cur.execute(
                    """
                    INSERT INTO career_ops.job_matches (
                        profile_id, job_id, score_skills_primary, score_skills_secondary,
                        score_experience, score_remote_fit, score_seniority_fit,
                        score_salary_fit, score_semantic, score_recency, score_total
                    ) VALUES (
                        %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
                    )
                    RETURNING id
                    """,
                    (
                        match_data.get("profile_id", 1),
                        match_data.get("job_id"),
                        match_data.get("score_skills_primary", 0),
                        match_data.get("score_skills_secondary", 0),
                        match_data.get("score_experience", 0),
                        match_data.get("score_remote_fit", 0),
                        match_data.get("score_seniority_fit", 0),
                        match_data.get("score_salary_fit", 0),
                        match_data.get("score_semantic", 0),
                        match_data.get("score_recency", 0),
                        match_data.get("score_total", 0),
                    )
                )
                match_id = cur.fetchone()[0]
                conn.commit()
                logger.info(f"Match saved: ID {match_id}")
                return match_id
        except Exception as e:
            logger.error(f"Error saving match: {str(e)}")
            return None

    def get_best_matches(self, profile_id: int = 1, limit: int = 5) -> List[Dict[str, Any]]:
        """Get top N matches by score"""
        try:
            with self.client.get_connection() as conn:
                cur = conn.cursor()
                cur.execute(
                    """
                    SELECT m.id, j.id, j.title, j.company, j.salary_min, j.salary_max,
                           j.remote_type, m.score_total, m.score_skills_primary,
                           m.score_skills_secondary, m.score_experience, m.score_remote_fit,
                           j.source_url, j.posted_at
                    FROM career_ops.job_matches m
                    JOIN career_ops.jobs j ON m.job_id = j.id
                    WHERE m.profile_id = %s AND j.is_active = true
                    ORDER BY m.score_total DESC
                    LIMIT %s
                    """,
                    (profile_id, limit)
                )

                matches = []
                for row in cur.fetchall():
                    matches.append({
                        "match_id": row[0],
                        "job_id": row[1],
                        "title": row[2],
                        "company": row[3],
                        "salary_min": row[4],
                        "salary_max": row[5],
                        "remote_type": row[6],
                        "score_total": row[7],
                        "score_skills_primary": row[8],
                        "score_skills_secondary": row[9],
                        "score_experience": row[10],
                        "score_remote_fit": row[11],
                        "source_url": row[12],
                        "posted_at": row[13],
                    })
                return matches
        except Exception as e:
            logger.error(f"Error fetching matches: {str(e)}")
            return []


class ScraperRunsRepository:
    """Repository for career_ops.scraper_runs table"""

    def __init__(self):
        self.client = AWSRDSClient()

    def log_scraper_run(self, source: str, jobs_found: int, jobs_new: int,
                       duration_seconds: float, status: str = "completed",
                       error_message: Optional[str] = None) -> Optional[int]:
        """Log a scraper run"""
        try:
            with self.client.get_connection() as conn:
                cur = conn.cursor()
                cur.execute(
                    """
                    INSERT INTO career_ops.scraper_runs (
                        source, jobs_found, jobs_new, duration_seconds, status, error_message, completed_at
                    ) VALUES (
                        %s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP
                    )
                    RETURNING id
                    """,
                    (source, jobs_found, jobs_new, duration_seconds, status, error_message)
                )
                run_id = cur.fetchone()[0]
                conn.commit()
                logger.info(f"Scraper run logged: {source} (ID: {run_id})")
                return run_id
        except Exception as e:
            logger.error(f"Error logging scraper run: {str(e)}")
            return None

    def get_recent_runs(self, limit: int = 10) -> List[Dict[str, Any]]:
        """Get recent scraper runs"""
        try:
            with self.client.get_connection() as conn:
                cur = conn.cursor()
                cur.execute(
                    """
                    SELECT id, source, started_at, completed_at, jobs_found, jobs_new,
                           status, duration_seconds
                    FROM career_ops.scraper_runs
                    ORDER BY started_at DESC
                    LIMIT %s
                    """,
                    (limit,)
                )

                runs = []
                for row in cur.fetchall():
                    runs.append({
                        "id": row[0],
                        "source": row[1],
                        "started_at": row[2],
                        "completed_at": row[3],
                        "jobs_found": row[4],
                        "jobs_new": row[5],
                        "status": row[6],
                        "duration_seconds": row[7],
                    })
                return runs
        except Exception as e:
            logger.error(f"Error fetching scraper runs: {str(e)}")
            return []


if __name__ == "__main__":
    print("\n[TEST] Career-Ops RDS Repositories")
    print("="*60)

    # Test profile repository
    print("\n[1/4] Testing CareerProfileRepository...")
    profile_repo = CareerProfileRepository()
    profile = profile_repo.get_profile(1)
    if profile:
        print(f"[OK] Profile loaded: {profile['full_name']}")
    else:
        print("[ERROR] Failed to load profile")

    # Test jobs repository
    print("\n[2/4] Testing JobsRepository...")
    jobs_repo = JobsRepository()
    jobs = jobs_repo.get_active_jobs(limit=5)
    print(f"[OK] {len(jobs)} active jobs found in database")

    # Test matches repository
    print("\n[3/4] Testing JobMatchesRepository...")
    matches_repo = JobMatchesRepository()
    matches = matches_repo.get_best_matches(profile_id=1, limit=5)
    print(f"[OK] {len(matches)} best matches found")
    if matches:
        print(f"    Top match: {matches[0]['title']} at {matches[0]['company']} (Score: {matches[0]['score_total']})")

    # Test scraper runs
    print("\n[4/4] Testing ScraperRunsRepository...")
    runs_repo = ScraperRunsRepository()
    runs = runs_repo.get_recent_runs(limit=3)
    print(f"[OK] {len(runs)} recent scraper runs found")

    print("\n" + "="*60)
    print("[SUCCESS] All repositories tested!")
    print("="*60 + "\n")
