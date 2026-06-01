"""
Indeed Job Scraper (Hard Target)
Uses Playwright for JS rendering + anti-bot handling
"""

import asyncio
from datetime import datetime, timedelta
from typing import Optional

from .remoteok import NormalizedJob

try:
    from playwright.async_api import async_playwright
except ImportError:
    print("[WARNING] Playwright not installed. Run: pip install playwright")


class IndeedScraper:
    """Scrape Indeed remote jobs using Playwright"""

    BASE_URL = "https://www.indeed.com/jobs"
    QUERIES = [
        "python developer remote",
        "data analyst remote",
        "full stack developer remote",
        "backend engineer remote",
        "data scientist remote",
    ]
    TIMEOUT = 120

    @staticmethod
    def _parse_salary(salary_str: Optional[str]) -> tuple[Optional[int], Optional[int]]:
        """Parse salary string like '$50,000 - $70,000 a year'"""
        if not salary_str:
            return None, None

        import re

        amounts = re.findall(r"\$[\d,]+", salary_str)
        if len(amounts) >= 2:
            try:
                min_sal = int(amounts[0].replace("$", "").replace(",", ""))
                max_sal = int(amounts[1].replace("$", "").replace(",", ""))
                return min_sal, max_sal
            except:
                pass

        return None, None

    async def fetch(self) -> list[NormalizedJob]:
        """Fetch and normalize jobs from Indeed"""

        jobs = []

        try:
            from playwright.async_api import async_playwright
        except ImportError:
            print("[ERROR] Playwright not installed")
            print("[ACTION] Run: pip install playwright")
            print("[ACTION] Then: playwright install chromium")
            return jobs

        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=True)
            context = await browser.new_context()

            # Set user agent to avoid bot detection
            await context.set_extra_http_headers({
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
            })

            for query in self.QUERIES:
                print(f"[Indeed] Searching: {query}")

                try:
                    page = await context.new_page()
                    url = f"{self.BASE_URL}?q={query.replace(' ', '+')}&l=Remote"

                    await page.goto(url, wait_until="networkidle", timeout=self.TIMEOUT * 1000)

                    # Wait for job cards to load
                    await page.wait_for_selector(".job-search-results", timeout=30000)

                    # Extract job listings
                    job_cards = await page.query_selector_all(".job-search-results li")
                    print(f"[Indeed] Found {len(job_cards)} job cards")

                    for i, card in enumerate(job_cards[:20]):  # Limit to first 20 per query
                        try:
                            # Extract job data
                            title_elem = await card.query_selector("[data-testid='jobTitle']")
                            title = await title_elem.inner_text() if title_elem else ""

                            company_elem = await card.query_selector("[data-testid='companyPartial']")
                            company = await company_elem.inner_text() if company_elem else ""

                            salary_elem = await card.query_selector(".salary-snippet")
                            salary_text = await salary_elem.inner_text() if salary_elem else ""

                            snippet_elem = await card.query_selector(".job-snippet")
                            description = await snippet_elem.inner_text() if snippet_elem else ""

                            link_elem = await card.query_selector("a[href*='/jobs/']")
                            job_url = await link_elem.get_attribute("href") if link_elem else ""

                            if job_url and not job_url.startswith("http"):
                                job_url = f"https://www.indeed.com{job_url}"

                            # Parse salary
                            salary_min, salary_max = self._parse_salary(salary_text)

                            # Detect seniority
                            title_lower = title.lower()
                            if "senior" in title_lower or "lead" in title_lower:
                                seniority = "senior"
                            elif "junior" in title_lower:
                                seniority = "junior"
                            else:
                                seniority = "mid"

                            # Create normalized job
                            job = NormalizedJob(
                                source="indeed",
                                source_id=job_url,
                                source_url=job_url,
                                title=title,
                                company=company,
                                company_url=None,
                                description=description,
                                description_clean=description[:500],
                                job_type="full_time",
                                seniority=seniority,
                                remote_type="fully_remote",
                                location_required=None,
                                salary_min=salary_min,
                                salary_max=salary_max,
                                salary_currency="USD",
                                salary_period="yearly",
                                required_skills=[],
                                preferred_skills=[],
                                experience_years_min=3 if seniority == "senior" else 1,
                                experience_years_max=10 if seniority == "senior" else 5,
                                posted_at=datetime.now(),
                                expires_at=datetime.now() + timedelta(days=30),
                            )

                            jobs.append(job)

                        except Exception as e:
                            print(f"[Indeed] Extract error: {str(e)[:80]}")
                            continue

                    await page.close()

                except Exception as e:
                    print(f"[Indeed] Query error: {str(e)[:100]}")
                    continue

                # Anti-bot: random delay between queries
                await asyncio.sleep(2 + (i % 3))  # 2-5 second delay

            await browser.close()

        print(f"[Indeed] Normalized {len(jobs)} jobs")
        return jobs


async def scrape_indeed() -> list[dict]:
    """Convenience function to scrape and return dicts"""
    scraper = IndeedScraper()
    jobs = await scraper.fetch()
    return [job.to_dict() for job in jobs]


if __name__ == "__main__":

    async def main():
        scraper = IndeedScraper()
        jobs = await scraper.fetch()
        print(f"\n[RESULT] {len(jobs)} jobs found")
        for job in jobs[:3]:
            print(f"  • {job.title} @ {job.company}")

    asyncio.run(main())
