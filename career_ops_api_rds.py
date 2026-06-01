"""
Career-Ops FastAPI Router - RDS Backed
All data from AWS RDS, NO mocks
Endpoints for PsychoBot to fetch real data
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional, List
import logging
import sys
from pathlib import Path

_root = Path(__file__).resolve().parent
sys.path.insert(0, str(_root))

from career_ops.repositories.rds_repositories import (
    CareerProfileRepository,
    JobsRepository,
    JobMatchesRepository,
    ScraperRunsRepository,
)

logger = logging.getLogger("career_ops_api")

router = APIRouter(prefix="/career-ops", tags=["Career-Ops"])

# Initialize repositories
profile_repo = CareerProfileRepository()
jobs_repo = JobsRepository()
matches_repo = JobMatchesRepository()
runs_repo = ScraperRunsRepository()


class JobMatch(BaseModel):
    """Job match response model"""
    match_id: int
    job_id: int
    title: str
    company: str
    salary_min: Optional[int]
    salary_max: Optional[int]
    remote_type: str
    score_total: float
    score_breakdown: dict
    source_url: str


@router.get("/status")
async def get_status():
    """Get Career-Ops system status"""
    try:
        profile = profile_repo.get_profile(1)
        if not profile:
            return {
                "status": "degraded",
                "profile": "not found",
                "database": "accessible but empty",
            }

        jobs = jobs_repo.get_active_jobs(limit=1)
        matches = matches_repo.get_best_matches(profile_id=1, limit=1)

        return {
            "status": "operational",
            "profile": {
                "name": profile["full_name"],
                "email": profile["email"],
                "experience_years": profile["years_experience"],
            },
            "database": {
                "active_jobs": len(jobs_repo.get_active_jobs(limit=1000)),
                "recent_matches": len(matches),
            },
            "timestamp": "now",
        }
    except Exception as e:
        logger.error(f"Error getting status: {str(e)}")
        return {
            "status": "error",
            "error": str(e),
        }


@router.get("/profile")
async def get_profile():
    """Get user career profile (from RDS)"""
    try:
        profile = profile_repo.get_profile(1)
        if not profile:
            raise HTTPException(status_code=404, detail="Profile not found")

        return {
            "profile": profile,
            "source": "AWS RDS",
        }
    except Exception as e:
        logger.error(f"Error fetching profile: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/jobs/best-matches")
async def get_best_matches(limit: int = 5):
    """Get top N job matches (from RDS)"""
    try:
        matches = matches_repo.get_best_matches(profile_id=1, limit=limit)

        # Fetch full job details for each match
        formatted_matches = []
        for m in matches:
            formatted_matches.append({
                "match_id": m["match_id"],
                "job_id": m["job_id"],
                "position": m["title"],
                "company": m["company"],
                "salary": {
                    "min": m["salary_min"],
                    "max": m["salary_max"],
                    "currency": "USD",
                },
                "remote_type": m["remote_type"],
                "scores": {
                    "total": float(m["score_total"]) if m["score_total"] else 0,
                    "skills_primary": float(m["score_skills_primary"]) if m["score_skills_primary"] else 0,
                    "skills_secondary": float(m["score_skills_secondary"]) if m["score_skills_secondary"] else 0,
                    "experience": float(m["score_experience"]) if m["score_experience"] else 0,
                    "remote_fit": float(m["score_remote_fit"]) if m["score_remote_fit"] else 0,
                },
                "apply_url": m["source_url"],
                "posted_at": m["posted_at"],
            })

        return {
            "matches": formatted_matches,
            "total": len(formatted_matches),
            "source": "AWS RDS",
            "note": "ALL DATA FROM DATABASE - NO MOCKS",
        }
    except Exception as e:
        logger.error(f"Error fetching matches: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/jobs/all")
async def get_all_jobs(limit: int = 100):
    """Get all active jobs (from RDS)"""
    try:
        jobs = jobs_repo.get_active_jobs(limit=limit)

        formatted_jobs = []
        for job in jobs:
            formatted_jobs.append({
                "id": job["id"],
                "title": job["title"],
                "company": job["company"],
                "salary": {
                    "min": job["salary_min"],
                    "max": job["salary_max"],
                },
                "remote_type": job["remote_type"],
                "job_type": job["job_type"],
                "seniority": job["seniority"],
                "skills": job["required_skills"],
                "url": job["source_url"],
                "posted_at": job["posted_at"],
            })

        return {
            "jobs": formatted_jobs,
            "total": len(formatted_jobs),
            "source": "AWS RDS",
        }
    except Exception as e:
        logger.error(f"Error fetching jobs: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/scraper-runs/recent")
async def get_recent_runs(limit: int = 10):
    """Get recent scraper execution logs (from RDS)"""
    try:
        runs = runs_repo.get_recent_runs(limit=limit)

        return {
            "runs": runs,
            "total": len(runs),
            "source": "AWS RDS",
        }
    except Exception as e:
        logger.error(f"Error fetching runs: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/stats")
async def get_statistics():
    """Get Career-Ops statistics (from RDS)"""
    try:
        profile = profile_repo.get_profile(1)
        matches = matches_repo.get_best_matches(profile_id=1, limit=1000)
        runs = runs_repo.get_recent_runs(limit=100)

        # Calculate stats
        excellent_matches = len([m for m in matches if m["score_total"] >= 0.75])
        good_matches = len([m for m in matches if 0.55 <= m["score_total"] < 0.75])
        total_jobs = len(jobs_repo.get_active_jobs(limit=10000))

        return {
            "profile": {
                "name": profile["full_name"],
                "experience_years": profile["years_experience"],
                "target_roles": profile["target_roles"],
            },
            "jobs": {
                "total_active": total_jobs,
                "matches_excellent": excellent_matches,
                "matches_good": good_matches,
                "match_rate_pct": (len(matches) / max(total_jobs, 1)) * 100,
            },
            "scraper": {
                "recent_runs": len(runs),
                "last_run": runs[0] if runs else None,
            },
            "source": "AWS RDS",
        }
    except Exception as e:
        logger.error(f"Error calculating stats: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/jobs/save")
async def save_job(job_data: dict):
    """Save a new job to RDS"""
    try:
        job_id = jobs_repo.save_job(job_data)
        if job_id:
            return {
                "status": "saved",
                "job_id": job_id,
                "title": job_data.get("title"),
            }
        else:
            raise HTTPException(status_code=400, detail="Failed to save job")
    except Exception as e:
        logger.error(f"Error saving job: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/matches/save")
async def save_match(match_data: dict):
    """Save a job match score to RDS"""
    try:
        match_id = matches_repo.save_match(match_data)
        if match_id:
            return {
                "status": "saved",
                "match_id": match_id,
                "score": match_data.get("score_total"),
            }
        else:
            raise HTTPException(status_code=400, detail="Failed to save match")
    except Exception as e:
        logger.error(f"Error saving match: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/scraper-runs/log")
async def log_scraper(source: str, jobs_found: int, jobs_new: int,
                      duration_seconds: float, status: str = "completed"):
    """Log scraper execution to RDS"""
    try:
        run_id = runs_repo.log_scraper_run(source, jobs_found, jobs_new,
                                          duration_seconds, status)
        if run_id:
            return {
                "status": "logged",
                "run_id": run_id,
                "source": source,
            }
        else:
            raise HTTPException(status_code=400, detail="Failed to log run")
    except Exception as e:
        logger.error(f"Error logging run: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    print("\n[TEST] Career-Ops API Endpoints")
    print("="*60)
    print("Run with: uvicorn career_ops_api_rds:app --port 8000")
    print("="*60 + "\n")
