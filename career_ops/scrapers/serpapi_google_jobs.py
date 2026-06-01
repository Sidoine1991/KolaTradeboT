"""
SerpAPI Google Jobs Scraper
Scrapes Google Jobs (powered by SerpAPI) to expand job sources
No API limits with SerpAPI key (100+ jobs/day)
"""

from datetime import datetime, timedelta
from typing import Optional
import os
from pathlib import Path
from dotenv import load_dotenv

from .remoteok import NormalizedJob

load_dotenv(Path(__file__).parent.parent.parent / ".env")


class SerpAPIGoogleJobsScraper:
    """Scrape Google Jobs via SerpAPI"""

    BASE_URL = "https://serpapi.com/search"
    QUERIES = [
        "data analyst remote",
        "python developer remote",
        "full stack engineer remote",
        "backend developer remote",
        "data scientist remote",
    ]

    def __init__(self, api_key: str = None):
        self.api_key = api_key or os.getenv("SERPAPI_API_KEY")
        if not self.api_key:
            print("[SerpAPI] API key not found in .env (SERPAPI_API_KEY)")

    async def fetch(self) -> list[NormalizedJob]:
        """Fetch jobs from Google Jobs via SerpAPI"""

        if not self.api_key:
            return []

        jobs = []

        try:
            import httpx

            async with httpx.AsyncClient(timeout=30) as client:
                for query in self.QUERIES:
                    print(f"[SerpAPI] Searching: {query}")

                    try:
                        params = {
                            "q": query,
                            "engine": "google_jobs",
                            "api_key": self.api_key,
                            "num": 10,  # 10 jobs per query
                        }

                        response = await client.get(self.BASE_URL, params=params)

                        if response.status_code == 200:
                            data = response.json()

                            # Extract jobs from response
                            job_results = data.get("jobs_results", [])

                            for raw_job in job_results:
                                try:
                                    # Parse salary if available
                                    salary_min = None
                                    salary_max = None
                                    if "salary" in raw_job:
                                        salary_text = raw_job["salary"]
                                        # Parse "$50,000 - $80,000" format
                                        if "-" in salary_text:
                                            parts = salary_text.split("-")
                                            try:
                                                salary_min = int(
                                                    parts[0]
                                                    .strip()
                                                    .replace("$", "")
                                                    .replace(",", "")
                                                )
                                                salary_max = int(
                                                    parts[1]
                                                    .strip()
                                                    .replace("$", "")
                                                    .replace(",", "")
                                                )
                                            except:
                                                pass

                                    job = NormalizedJob(
                                        source="serpapi_google_jobs",
                                        source_id=raw_job.get("job_id", ""),
                                        source_url=raw_job.get("link", ""),
                                        title=raw_job.get("title", ""),
                                        company=raw_job.get("company_name", ""),
                                        company_url=raw_job.get("company_url", ""),
                                        description=raw_job.get("description", "")[:500],
                                        description_clean=raw_job.get("description", "")
                                        [:500],
                                        job_type="full_time",
                                        seniority=self._detect_seniority(
                                            raw_job.get("title", "")
                                        ),
                                        remote_type=self._detect_remote(
                                            raw_job.get("location", "")
                                        ),
                                        location_required=raw_job.get("location", ""),
                                        salary_min=salary_min,
                                        salary_max=salary_max,
                                        salary_currency="USD",
                                        salary_period="yearly",
                                        required_skills=[],
                                        preferred_skills=[],
                                        experience_years_min=1,
                                        experience_years_max=5,
                                        posted_at=datetime.now(),
                                        expires_at=datetime.now() + timedelta(days=30),
                                    )

                                    jobs.append(job)

                                except Exception as e:
                                    print(f"[SerpAPI] Parse error: {str(e)[:60]}")
                                    continue

                        else:
                            print(f"[SerpAPI] Error: {response.status_code}")

                    except Exception as e:
                        print(f"[SerpAPI] Query error ({query}): {str(e)[:80]}")
                        continue

        except ImportError:
            print("[SerpAPI] httpx not installed")
        except Exception as e:
            print(f"[SerpAPI] Fetch error: {str(e)[:100]}")

        print(f"[SerpAPI] Extracted {len(jobs)} jobs")
        return jobs

    @staticmethod
    def _detect_seniority(title: str) -> str:
        """Detect seniority from title"""
        title_lower = title.lower()
        if "senior" in title_lower:
            return "senior"
        if "junior" in title_lower or "entry" in title_lower:
            return "junior"
        return "mid"

    @staticmethod
    def _detect_remote(location: str) -> str:
        """Detect remote type from location"""
        if not location:
            return "hybrid"
        location_lower = location.lower()
        if "remote" in location_lower:
            return "fully_remote"
        if "hybrid" in location_lower:
            return "hybrid"
        return "on_site"


async def scrape_serpapi_jobs() -> list[dict]:
    """Convenience function to scrape SerpAPI Google Jobs"""

    api_key = os.getenv("SERPAPI_API_KEY")

    if not api_key:
        print("[SerpAPI] API key not found")
        return []

    scraper = SerpAPIGoogleJobsScraper(api_key)
    jobs = await scraper.fetch()

    return [job.to_dict() for job in jobs]


if __name__ == "__main__":
    import asyncio

    async def main():
        jobs = await scrape_serpapi_jobs()
        print(f"\n[RESULT] {len(jobs)} jobs found from SerpAPI Google Jobs")
        for job in jobs[:5]:
            print(f"  • {job['title']} @ {job['company']}")

    asyncio.run(main())
