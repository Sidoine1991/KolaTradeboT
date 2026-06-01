"""
RemoteOK Job Scraper
Fetches from https://remoteok.com/api/jobs.json (public JSON API)
"""

import json
import hashlib
from datetime import datetime, timedelta
from typing import Optional

import httpx


class NormalizedJob:
    """Normalized job representation across all sources"""

    def __init__(self, **kwargs):
        self.source = kwargs.get("source", "remoteok")
        self.source_id = kwargs.get("source_id")
        self.source_url = kwargs.get("source_url")

        self.title = kwargs.get("title", "")
        self.company = kwargs.get("company", "")
        self.company_url = kwargs.get("company_url")
        self.description = kwargs.get("description", "")
        self.description_clean = kwargs.get("description_clean")

        self.job_type = kwargs.get("job_type")
        self.seniority = kwargs.get("seniority", "mid")
        self.remote_type = kwargs.get("remote_type", "fully_remote")
        self.location_required = kwargs.get("location_required")

        self.salary_min = kwargs.get("salary_min")
        self.salary_max = kwargs.get("salary_max")
        self.salary_currency = kwargs.get("salary_currency", "USD")
        self.salary_period = kwargs.get("salary_period", "yearly")

        self.required_skills = kwargs.get("required_skills", [])
        self.preferred_skills = kwargs.get("preferred_skills", [])
        self.experience_years_min = kwargs.get("experience_years_min")
        self.experience_years_max = kwargs.get("experience_years_max")

        self.posted_at = kwargs.get("posted_at")
        self.expires_at = kwargs.get("expires_at")

        self.fingerprint = self._generate_fingerprint()

    def _generate_fingerprint(self) -> str:
        """Generate unique job fingerprint"""
        base = f"{self.company}|{self.title}|{self.posted_at}"
        return hashlib.sha256(base.encode()).hexdigest()[:16]

    def to_dict(self):
        """Convert to DB-ready dict"""
        return {
            "source": self.source,
            "source_id": self.source_id,
            "source_url": self.source_url,
            "title": self.title,
            "company": self.company,
            "company_url": self.company_url,
            "description": self.description,
            "description_clean": self.description_clean,
            "job_type": self.job_type,
            "seniority": self.seniority,
            "remote_type": self.remote_type,
            "location_required": self.location_required,
            "salary_min": self.salary_min,
            "salary_max": self.salary_max,
            "salary_currency": self.salary_currency,
            "salary_period": self.salary_period,
            "required_skills": self.required_skills,
            "preferred_skills": self.preferred_skills,
            "experience_years_min": self.experience_years_min,
            "experience_years_max": self.experience_years_max,
            "posted_at": self.posted_at.isoformat() if self.posted_at else None,
            "expires_at": self.expires_at.isoformat() if self.expires_at else None,
            "fingerprint": self.fingerprint,
        }


class RemoteOKScraper:
    """Scrape RemoteOK jobs for Data/Python/Fullstack roles"""

    API_URL = "https://remoteok.com/api/jobs.json"
    KEYWORDS = ["python", "data", "fullstack", "react", "backend", "sql"]
    TIMEOUT = 30

    @staticmethod
    def _extract_salary(job: dict) -> tuple[Optional[int], Optional[int]]:
        """Extract min/max salary from job salary field"""
        salary_str = job.get("salary", "")
        if not salary_str:
            return None, None

        # RemoteOK format: "$50k-$70k" or "$50000-$70000"
        import re

        matches = re.findall(r"\$(\d+[k]?)", salary_str)
        if len(matches) >= 2:
            min_sal = int(matches[0].rstrip("k")) * (1000 if "k" in matches[0] else 1)
            max_sal = int(matches[1].rstrip("k")) * (1000 if "k" in matches[1] else 1)
            return min_sal, max_sal

        return None, None

    @staticmethod
    def _detect_skills(description: str, title: str) -> tuple[list[str], list[str]]:
        """Extract required and preferred skills from description"""
        description_lower = (description + " " + title).lower()

        required_keywords = ["python", "sql", "r", "power bi", "tableau", "api", "database"]
        preferred_keywords = ["pandas", "numpy", "plotly", "streamlit", "react", "django", "fastapi"]

        required = [kw for kw in required_keywords if kw in description_lower]
        preferred = [kw for kw in preferred_keywords if kw in description_lower]

        return required, preferred

    @staticmethod
    def _should_include_job(job: dict) -> bool:
        """Filter jobs by relevance"""
        title = (job.get("title") or "").lower()
        description = (job.get("description") or "").lower()
        combined = title + " " + description

        # Must contain at least one target keyword
        return any(kw in combined for kw in RemoteOKScraper.KEYWORDS)

    async def fetch(self) -> list[NormalizedJob]:
        """Fetch and normalize jobs from RemoteOK API"""

        jobs = []

        try:
            print(f"[RemoteOK] Fetching from {self.API_URL}...")

            async with httpx.AsyncClient(timeout=self.TIMEOUT) as client:
                response = await client.get(self.API_URL)
                response.raise_for_status()

                raw_jobs = response.json()
                print(f"[RemoteOK] Got {len(raw_jobs)} raw jobs")

        except Exception as e:
            print(f"[RemoteOK] Fetch error: {str(e)[:100]}")
            return []

        # Normalize each job
        for raw_job in raw_jobs:
            # Skip non-matching jobs
            if not self._should_include_job(raw_job):
                continue

            try:
                # Parse dates
                posted_timestamp = raw_job.get("date", 0)
                posted_at = datetime.fromtimestamp(posted_timestamp) if posted_timestamp else datetime.now()

                # RemoteOK doesn't provide expiration, assume 30 days
                expires_at = posted_at + timedelta(days=30)

                # Extract salary
                salary_min, salary_max = self._extract_salary(raw_job)

                # Extract skills
                description = raw_job.get("description", "")
                title = raw_job.get("title", "")
                required_skills, preferred_skills = self._detect_skills(description, title)

                # Detect seniority from title
                title_lower = title.lower()
                if "senior" in title_lower or "lead" in title_lower:
                    seniority = "senior"
                elif "junior" in title_lower:
                    seniority = "junior"
                else:
                    seniority = "mid"

                # Create normalized job
                job = NormalizedJob(
                    source="remoteok",
                    source_id=str(raw_job.get("id")),
                    source_url=raw_job.get("url"),
                    title=title,
                    company=raw_job.get("company"),
                    company_url=raw_job.get("company_logo"),
                    description=description,
                    description_clean=description[:500],  # First 500 chars
                    job_type="full_time",
                    seniority=seniority,
                    remote_type="fully_remote",
                    location_required=None,
                    salary_min=salary_min,
                    salary_max=salary_max,
                    salary_currency="USD",
                    salary_period="yearly",
                    required_skills=required_skills,
                    preferred_skills=preferred_skills,
                    experience_years_min=3 if seniority == "senior" else 1,
                    experience_years_max=10 if seniority == "senior" else 5,
                    posted_at=posted_at,
                    expires_at=expires_at,
                )

                jobs.append(job)

            except Exception as e:
                print(f"[RemoteOK] Normalize error: {str(e)[:80]}")
                continue

        print(f"[RemoteOK] Normalized {len(jobs)} matching jobs")
        return jobs


async def scrape_remoteok() -> list[dict]:
    """Convenience function to scrape and return dicts"""
    scraper = RemoteOKScraper()
    jobs = await scraper.fetch()
    return [job.to_dict() for job in jobs]


if __name__ == "__main__":
    import asyncio

    async def main():
        scraper = RemoteOKScraper()
        jobs = await scraper.fetch()
        print(f"\n[RESULT] {len(jobs)} jobs found")
        for job in jobs[:3]:
            print(f"  • {job.title} @ {job.company} (${job.salary_min}-${job.salary_max})")

    asyncio.run(main())
