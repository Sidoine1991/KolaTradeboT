"""
AWS RDS Repository - CRUD operations for Career-Ops
Wraps psycopg2 for database access
"""

import os
from typing import Optional, List, Dict
from pathlib import Path
from dotenv import load_dotenv

load_dotenv(Path(__file__).parent.parent.parent / ".env")

DATABASE_URL = os.getenv("DATABASE_URL")


class RDSRepository:
    """AWS RDS database operations"""

    def __init__(self):
        self.db_url = DATABASE_URL
        if not self.db_url:
            raise ValueError("DATABASE_URL not set in .env")

    def get_connection(self):
        """Create database connection"""
        try:
            import psycopg2
            return psycopg2.connect(self.db_url)
        except ImportError:
            raise ImportError("psycopg2 not installed. Run: pip install psycopg2-binary")

    def insert_job(self, job_dict: Dict) -> Optional[int]:
        """Insert normalized job into RDS"""
        try:
            conn = self.get_connection()
            cursor = conn.cursor()

            cursor.execute("""
                INSERT INTO career_ops.jobs (
                    source, source_id, source_url, title, company, company_url,
                    description, description_clean, job_type, seniority, remote_type,
                    location_required, salary_min, salary_max, salary_currency,
                    salary_period, required_skills, preferred_skills,
                    experience_years_min, experience_years_max, posted_at, expires_at,
                    fingerprint, is_active
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                    %s, %s, %s, %s, %s, %s, %s, %s, %s
                ) ON CONFLICT (fingerprint) DO NOTHING
                RETURNING id
            """, (
                job_dict['source'],
                job_dict.get('source_id'),
                job_dict['source_url'],
                job_dict['title'],
                job_dict['company'],
                job_dict.get('company_url'),
                job_dict.get('description'),
                job_dict.get('description_clean'),
                job_dict.get('job_type'),
                job_dict.get('seniority'),
                job_dict.get('remote_type'),
                job_dict.get('location_required'),
                job_dict.get('salary_min'),
                job_dict.get('salary_max'),
                job_dict.get('salary_currency'),
                job_dict.get('salary_period'),
                job_dict.get('required_skills', []),
                job_dict.get('preferred_skills', []),
                job_dict.get('experience_years_min'),
                job_dict.get('experience_years_max'),
                job_dict.get('posted_at'),
                job_dict.get('expires_at'),
                job_dict['fingerprint'],
                job_dict.get('is_active', True),
            ))

            result = cursor.fetchone()
            conn.commit()
            cursor.close()
            conn.close()

            return result[0] if result else None

        except Exception as e:
            print(f"[ERROR] insert_job failed: {str(e)[:100]}")
            return None

    def insert_match(self, match_dict: Dict) -> Optional[int]:
        """Insert job match score into RDS"""
        try:
            conn = self.get_connection()
            cursor = conn.cursor()

            cursor.execute("""
                INSERT INTO career_ops.job_matches (
                    profile_id, job_id, score_skills_primary, score_skills_secondary,
                    score_experience, score_remote_fit, score_seniority_fit,
                    score_salary_fit, score_semantic, score_recency, score_total, status
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (profile_id, job_id) DO UPDATE SET
                    score_total = EXCLUDED.score_total,
                    updated_at = CURRENT_TIMESTAMP
                RETURNING id
            """, (
                match_dict['profile_id'],
                match_dict['job_id'],
                match_dict['score_skills_primary'],
                match_dict['score_skills_secondary'],
                match_dict['score_experience'],
                match_dict['score_remote_fit'],
                match_dict['score_seniority_fit'],
                match_dict['score_salary_fit'],
                match_dict['score_semantic'],
                match_dict['score_recency'],
                match_dict['score_total'],
                match_dict.get('status', 'new'),
            ))

            result = cursor.fetchone()
            conn.commit()
            cursor.close()
            conn.close()

            return result[0] if result else None

        except Exception as e:
            print(f"[ERROR] insert_match failed: {str(e)[:100]}")
            return None

    def get_profile(self, profile_id: int = 1) -> Optional[Dict]:
        """Get career profile by ID (default: Sidoine)"""
        try:
            conn = self.get_connection()
            cursor = conn.cursor()

            cursor.execute("""
                SELECT id, full_name, email, location, years_experience,
                       skills_primary, skills_secondary, skills_tools,
                       min_salary_usd, target_roles, experience_keywords
                FROM career_ops.career_profile
                WHERE id = %s
            """, (profile_id,))

            row = cursor.fetchone()
            cursor.close()
            conn.close()

            if row:
                return {
                    'id': row[0],
                    'full_name': row[1],
                    'email': row[2],
                    'location': row[3],
                    'years_experience': row[4],
                    'skills_primary': row[5],
                    'skills_secondary': row[6],
                    'skills_tools': row[7],
                    'min_salary_usd': row[8],
                    'target_roles': row[9],
                    'experience_keywords': row[10],
                }
            return None

        except Exception as e:
            print(f"[ERROR] get_profile failed: {str(e)[:100]}")
            return None

    def get_top_matches(self, profile_id: int = 1, limit: int = 10) -> List[Dict]:
        """Get top-scored matches for profile"""
        try:
            conn = self.get_connection()
            cursor = conn.cursor()

            cursor.execute("""
                SELECT j.id, j.title, j.company, j.salary_min, j.salary_max,
                       m.score_total, m.score_skills_primary, m.score_experience,
                       j.source_url, j.remote_type
                FROM career_ops.job_matches m
                JOIN career_ops.jobs j ON m.job_id = j.id
                WHERE m.profile_id = %s AND m.score_total >= 0.55
                ORDER BY m.score_total DESC
                LIMIT %s
            """, (profile_id, limit))

            rows = cursor.fetchall()
            cursor.close()
            conn.close()

            matches = []
            for row in rows:
                matches.append({
                    'job_id': row[0],
                    'title': row[1],
                    'company': row[2],
                    'salary_min': row[3],
                    'salary_max': row[4],
                    'score_total': row[5],
                    'score_skills_primary': row[6],
                    'score_experience': row[7],
                    'source_url': row[8],
                    'remote_type': row[9],
                })

            return matches

        except Exception as e:
            print(f"[ERROR] get_top_matches failed: {str(e)[:100]}")
            return []

    def log_scraper_run(self, source: str, jobs_found: int, jobs_new: int) -> bool:
        """Log scraper execution"""
        try:
            conn = self.get_connection()
            cursor = conn.cursor()

            cursor.execute("""
                INSERT INTO career_ops.scraper_runs (
                    source, jobs_found, jobs_new, jobs_duplicate, status, completed_at
                ) VALUES (%s, %s, %s, %s, %s, CURRENT_TIMESTAMP)
            """, (
                source,
                jobs_found,
                jobs_new,
                jobs_found - jobs_new,
                'completed',
            ))

            conn.commit()
            cursor.close()
            conn.close()

            return True

        except Exception as e:
            print(f"[ERROR] log_scraper_run failed: {str(e)[:100]}")
            return False
