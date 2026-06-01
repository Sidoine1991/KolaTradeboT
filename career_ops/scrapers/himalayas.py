"""
Himalayas Job Scraper
Fetches remote jobs from Himalayas public API
https://www.himalayas.app/
"""

import json
from datetime import datetime, timedelta
from typing import Optional

import httpx

from .remoteok import NormalizedJob


class HimalayasScraper:
    """Scrape Himalayas remote jobs"""

    API_URL = "https://www.himalayas.app/api/v1/jobs"
    KEYWORDS = ["python", "data", "fullstack", "react", "backend", "sql"]
    TIMEOUT = 30

    @staticmethod
    def _should_include_job(job: dict) -> bool:
        """Filter jobs by relevance"""
        title = (job.get("title") or "").lower()
        description = (job.get("description") or "").lower()
        combined = title + " " + description

        return any(kw in combined for kw in HimalayasScraper.KEYWORDS)

    @staticmethod
    def _parse_salary(job: dict) -> tuple[Optional[int], Optional[int]]:
        """Extract salary range from job"""
        salary_min = job.get("salary_min")
        salary_max = job.get("salary_max")

        if salary_min and salary_max:
            return int(salary_min), int(salary_max)

        return None, None

    async def fetch(self) -> list[NormalizedJob]:
        """Fetch and normalize jobs from Himalayas API"""

        jobs = []

        try:
            print(f"[Himalayas] Fetching from {self.API_URL}...")

            async with httpx.AsyncClient(timeout=self.TIMEOUT) as client:
                # Himalayas API pagination
                offset = 0
                limit = 50
                total_fetched = 0

                while total_fetched < 200:  # Fetch up to 200 jobs
                    params = {
                        "offset": offset,
                        "limit": limit,
                        "remote_type": "fully_remote",  # Only fully remote
                    }

                    response = await client.get(self.API_URL, params=params)
                    response.raise_for_status()

                    raw_jobs = response.json()
                    if not raw_jobs:
                        break

                    total_fetched += len(raw_jobs)
                    print(f"[Himalayas] Got {len(raw_jobs)} jobs (total: {total_fetched})")

                    # Process jobs
                    for raw_job in raw_jobs:
                        if not self._should_include_job(raw_job):
                            continue

                        try:
                            # Parse dates
                            posted_str = raw_job.get("published_at")
                            posted_at = (
                                datetime.fromisoformat(posted_str.replace("Z", "+00:00"))
                                if posted_str
                                else datetime.now()
                            )
                            expires_at = posted_at + timedelta(days=30)

                            # Parse salary
                            salary_min, salary_max = self._parse_salary(raw_job)

                            # Detect seniority
                            title_lower = raw_job.get("title", "").lower()
                            if "senior" in title_lower or "lead" in title_lower:
                                seniority = "senior"
                            elif "junior" in title_lower:
                                seniority = "junior"
                            else:
                                seniority = "mid"

                            # Create normalized job
                            job = NormalizedJob(
                                source="himalayas",
                                source_id=str(raw_job.get("id")),
                                source_url=raw_job.get("url"),
                                title=raw_job.get("title", ""),
                                company=raw_job.get("company_name", ""),
                                company_url=raw_job.get("company_url"),
                                description=raw_job.get("description", ""),
                                description_clean=raw_job.get("description", "")[:500],
                                job_type="full_time",
                                seniority=seniority,
                                remote_type="fully_remote",
                                location_required=None,
                                salary_min=salary_min,
                                salary_max=salary_max,
                                salary_currency=raw_job.get("currency", "USD"),
                                salary_period="yearly",
                                required_skills=[],
                                preferred_skills=[],
                                experience_years_min=3 if seniority == "senior" else 1,
                                experience_years_max=10 if seniority == "senior" else 5,
                                posted_at=posted_at,
                                expires_at=expires_at,
                            )

                            jobs.append(job)

                        except Exception as e:
                            print(f"[Himalayas] Normalize error: {str(e)[:80]}")
                            continue

                    offset += limit

        except Exception as e:
            print(f"[Himalayas] Fetch error: {str(e)[:100]}")

        print(f"[Himalayas] Normalized {len(jobs)} matching jobs")
        return jobs


async def scrape_himalayas() -> list[dict]:
    """Convenience function to scrape and return dicts"""
    scraper = HimalayasScraper()
    jobs = await scraper.fetch()
    return [job.to_dict() for job in jobs]


if __name__ == "__main__":
    import asyncio

    async def main():
        scraper = HimalayasScraper()
        jobs = await scraper.fetch()
        print(f"\n[RESULT] {len(jobs)} jobs found")
        for job in jobs[:3]:
            print(f"  • {job.title} @ {job.company}")

    asyncio.run(main())
