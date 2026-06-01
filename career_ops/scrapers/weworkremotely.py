"""
We Work Remotely Job Scraper
Fetches from RSS feed: https://weworkremotely.com/categories/remote-backend-jobs/feed.xml
"""

import re
from datetime import datetime, timedelta
from typing import Optional

import httpx

from .remoteok import NormalizedJob


class WeWorkRemotelyScaper:
    """Scrape We Work Remotely jobs via RSS"""

    FEED_URLS = [
        "https://weworkremotely.com/categories/remote-backend-jobs/feed.xml",
        "https://weworkremotely.com/categories/remote-python-jobs/feed.xml",
        "https://weworkremotely.com/categories/remote-data-science-jobs/feed.xml",
        "https://weworkremotely.com/categories/remote-fullstack-jobs/feed.xml",
    ]
    KEYWORDS = ["python", "data", "fullstack", "react", "backend", "sql"]
    TIMEOUT = 30

    @staticmethod
    def _should_include_job(title: str, description: str) -> bool:
        """Filter jobs by relevance"""
        combined = (title + " " + description).lower()
        return any(kw in combined for kw in WeWorkRemotelyScaper.KEYWORDS)

    @staticmethod
    def _parse_rss_entry(entry_text: str) -> Optional[dict]:
        """Parse RSS entry XML to extract job data"""
        try:
            # Extract title
            title_match = re.search(r"<title>(.+?)</title>", entry_text)
            title = title_match.group(1) if title_match else ""

            # Extract description
            desc_match = re.search(r"<description>(.+?)</description>", entry_text, re.DOTALL)
            description = desc_match.group(1) if desc_match else ""

            # Clean HTML
            description = re.sub(r"<[^>]+>", "", description)

            # Extract link
            link_match = re.search(r"<link>(.+?)</link>", entry_text)
            link = link_match.group(1) if link_match else ""

            # Extract company from title (format: "Company Name: Job Title")
            if ":" in title:
                company, job_title = title.split(":", 1)
                company = company.strip()
                job_title = job_title.strip()
            else:
                company = "Unknown"
                job_title = title

            # Extract published date
            pub_match = re.search(r"<pubDate>(.+?)</pubDate>", entry_text)
            pub_date_str = pub_match.group(1) if pub_match else None

            return {
                "title": job_title,
                "company": company,
                "description": description,
                "link": link,
                "published": pub_date_str,
            }

        except Exception as e:
            print(f"[WWR] Parse error: {str(e)[:80]}")
            return None

    async def fetch(self) -> list[NormalizedJob]:
        """Fetch and normalize jobs from We Work Remotely RSS"""

        jobs = []

        try:
            async with httpx.AsyncClient(timeout=self.TIMEOUT) as client:
                for feed_url in self.FEED_URLS:
                    print(f"[WWR] Fetching {feed_url.split('/')[-2]}...")

                    response = await client.get(feed_url)
                    response.raise_for_status()

                    rss_content = response.text

                    # Extract all <item> entries
                    items = re.findall(r"<item>(.*?)</item>", rss_content, re.DOTALL)
                    print(f"[WWR] Found {len(items)} items in feed")

                    for item in items:
                        entry_data = self._parse_rss_entry(item)
                        if not entry_data:
                            continue

                        # Filter by keywords
                        if not self._should_include_job(entry_data["title"], entry_data["description"]):
                            continue

                        try:
                            # Parse date
                            posted_at = datetime.now()
                            if entry_data["published"]:
                                # Try to parse RFC 2822 date
                                from email.utils import parsedate_to_datetime

                                try:
                                    posted_at = parsedate_to_datetime(entry_data["published"])
                                except:
                                    pass

                            expires_at = posted_at + timedelta(days=30)

                            # Detect seniority
                            title_lower = entry_data["title"].lower()
                            if "senior" in title_lower or "lead" in title_lower:
                                seniority = "senior"
                            elif "junior" in title_lower:
                                seniority = "junior"
                            else:
                                seniority = "mid"

                            # Create normalized job
                            job = NormalizedJob(
                                source="weworkremotely",
                                source_id=entry_data["link"],
                                source_url=entry_data["link"],
                                title=entry_data["title"],
                                company=entry_data["company"],
                                company_url=None,
                                description=entry_data["description"],
                                description_clean=entry_data["description"][:500],
                                job_type="full_time",
                                seniority=seniority,
                                remote_type="fully_remote",
                                location_required=None,
                                salary_min=None,  # WWR doesn't always provide salary
                                salary_max=None,
                                salary_currency="USD",
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
                            print(f"[WWR] Normalize error: {str(e)[:80]}")
                            continue

        except Exception as e:
            print(f"[WWR] Fetch error: {str(e)[:100]}")

        print(f"[WWR] Normalized {len(jobs)} matching jobs")
        return jobs


async def scrape_weworkremotely() -> list[dict]:
    """Convenience function to scrape and return dicts"""
    scraper = WeWorkRemotelyScaper()
    jobs = await scraper.fetch()
    return [job.to_dict() for job in jobs]


if __name__ == "__main__":
    import asyncio

    async def main():
        scraper = WeWorkRemotelyScaper()
        jobs = await scraper.fetch()
        print(f"\n[RESULT] {len(jobs)} jobs found")
        for job in jobs[:3]:
            print(f"  • {job.title} @ {job.company}")

    asyncio.run(main())
