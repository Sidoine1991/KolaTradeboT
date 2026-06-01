"""
Free Web Scrapers (No API, No Payment)
Scrape publicly accessible job sites using Playwright
"""

from datetime import datetime, timedelta
from typing import Optional

from .remoteok import NormalizedJob

try:
    from playwright.async_api import async_playwright
except ImportError:
    print("[WARNING] Playwright not installed")


class LinkedInPublicScraper:
    """Scrape LinkedIn jobs (public posts, no login required)"""

    SEARCH_URL = "https://www.linkedin.com/jobs/search"
    QUERIES = [
        "data+analyst+remote",
        "python+developer+remote",
        "full+stack+remote",
        "backend+engineer+remote",
    ]

    async def fetch(self) -> list[NormalizedJob]:
        """Scrape LinkedIn public job listings"""

        jobs = []

        try:
            from playwright.async_api import async_playwright
        except ImportError:
            print("[LinkedIn] Playwright not installed")
            return jobs

        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=True)

            for query in self.QUERIES:
                print(f"[LinkedIn] Searching: {query}")

                try:
                    page = await browser.new_page()
                    url = f"{self.SEARCH_URL}?keywords={query}&location=Remote"

                    await page.goto(url, wait_until="networkidle", timeout=60000)

                    # Extract job cards
                    job_cards = await page.query_selector_all(".jobs-search__results-list li")

                    for card in job_cards[:15]:
                        try:
                            # Extract text
                            title_elem = await card.query_selector(".base-search-card__title")
                            title = await title_elem.inner_text() if title_elem else ""

                            company_elem = await card.query_selector(
                                ".base-search-card__subtitle"
                            )
                            company = await company_elem.inner_text() if company_elem else ""

                            job = NormalizedJob(
                                source="linkedin_public",
                                source_id=f"li_{query}_{int(datetime.now().timestamp())}",
                                source_url=url,
                                title=title,
                                company=company,
                                company_url=None,
                                description="LinkedIn job listing",
                                description_clean="LinkedIn job listing",
                                job_type="full_time",
                                seniority="mid",
                                remote_type="fully_remote",
                                location_required=None,
                                salary_min=None,
                                salary_max=None,
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
                            print(f"[LinkedIn] Card error: {str(e)[:60]}")
                            continue

                    await page.close()

                except Exception as e:
                    print(f"[LinkedIn] Search error: {str(e)[:100]}")
                    continue

            await browser.close()

        print(f"[LinkedIn] Extracted {len(jobs)} jobs")
        return jobs


class GitHubJobsScraper:
    """Scrape GitHub Jobs (public API, no auth required)"""

    BASE_URL = "https://api.github.com/repos/github-jobs/jobs"

    async def fetch(self) -> list[NormalizedJob]:
        """Fetch from GitHub Jobs GitHub repo"""

        jobs = []

        try:
            import httpx

            async with httpx.AsyncClient(timeout=30) as client:
                # GitHub Jobs repo has JSON data
                response = await client.get(f"{self.BASE_URL}")

                if response.status_code == 200:
                    raw_jobs = response.json()

                    for raw_job in raw_jobs[:20]:
                        try:
                            job = NormalizedJob(
                                source="github_jobs",
                                source_id=raw_job.get("id", ""),
                                source_url=raw_job.get("url", ""),
                                title=raw_job.get("title", ""),
                                company=raw_job.get("company", ""),
                                company_url=raw_job.get("company_url", ""),
                                description=raw_job.get("description", "")[:500],
                                description_clean=raw_job.get("description", "")[:500],
                                job_type=raw_job.get("type", "Full-time"),
                                seniority="mid",
                                remote_type="fully_remote"
                                if raw_job.get("how_to_apply")
                                else "on_site",
                                location_required=raw_job.get("location", ""),
                                salary_min=None,
                                salary_max=None,
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
                            print(f"[GitHub Jobs] Parse error: {str(e)[:60]}")
                            continue

        except Exception as e:
            print(f"[GitHub Jobs] Fetch error: {str(e)[:100]}")

        print(f"[GitHub Jobs] Extracted {len(jobs)} jobs")
        return jobs


class StackOverflowJobsScraper:
    """Scrape Stack Overflow jobs (RSS feed, no API key)"""

    RSS_FEED = "https://stackoverflow.com/jobs/feed"

    async def fetch(self) -> list[NormalizedJob]:
        """Fetch from Stack Overflow RSS"""

        jobs = []

        try:
            import httpx
            import feedparser

            async with httpx.AsyncClient(timeout=30) as client:
                response = await client.get(self.RSS_FEED)

                if response.status_code == 200:
                    feed = feedparser.parse(response.text)

                    for entry in feed.entries[:20]:
                        try:
                            job = NormalizedJob(
                                source="stackoverflow",
                                source_id=entry.get("id", ""),
                                source_url=entry.get("link", ""),
                                title=entry.get("title", ""),
                                company="Stack Overflow",
                                company_url="https://stackoverflow.com/jobs",
                                description=entry.get("summary", "")[:500],
                                description_clean=entry.get("summary", "")[:500],
                                job_type="full_time",
                                seniority="mid",
                                remote_type="hybrid",
                                location_required=None,
                                salary_min=None,
                                salary_max=None,
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
                            print(f"[Stack Overflow] Parse error: {str(e)[:60]}")
                            continue

        except Exception as e:
            print(f"[Stack Overflow] Fetch error: {str(e)[:100]}")

        print(f"[Stack Overflow] Extracted {len(jobs)} jobs")
        return jobs


async def scrape_free_sources() -> list[dict]:
    """Scrape all free sources without API keys"""

    all_jobs = []

    # LinkedIn public
    linkedin_scraper = LinkedInPublicScraper()
    linkedin_jobs = await linkedin_scraper.fetch()
    all_jobs.extend(linkedin_jobs)

    # GitHub Jobs
    github_scraper = GitHubJobsScraper()
    github_jobs = await github_scraper.fetch()
    all_jobs.extend(github_jobs)

    # Stack Overflow
    so_scraper = StackOverflowJobsScraper()
    so_jobs = await so_scraper.fetch()
    all_jobs.extend(so_jobs)

    return [job.to_dict() for job in all_jobs]


if __name__ == "__main__":
    import asyncio

    async def main():
        jobs = await scrape_free_sources()
        print(f"\n[RESULT] {len(jobs)} jobs found from free sources")

    asyncio.run(main())
