"""
LinkedIn & Job Sites Email Parser
Accesses email (IMAP) to extract job offers from:
- LinkedIn job alerts
- CDIscussion
- Opportunités Africa
- Other job forwarding services
"""

import re
import imaplib
import email
from datetime import datetime, timedelta
from typing import Optional
from pathlib import Path
from dotenv import load_dotenv
import os

from .remoteok import NormalizedJob

load_dotenv(Path(__file__).parent.parent.parent / ".env")


class EmailJobParser:
    """Parse job offers from email"""

    def __init__(self, email_address: str, email_password: str, imap_server: str = "imap.gmail.com"):
        self.email_address = email_address
        self.email_password = email_password
        self.imap_server = imap_server
        self.imap = None

    async def connect(self) -> bool:
        """Connect to email IMAP"""
        try:
            self.imap = imaplib.IMAP4_SSL(self.imap_server)
            self.imap.login(self.email_address, self.email_password)
            print(f"[Email] Connected: {self.email_address}")
            return True
        except Exception as e:
            print(f"[Email] Connection failed: {str(e)[:100]}")
            return False

    async def fetch_linkedin_jobs(self, days: int = 1) -> list[NormalizedJob]:
        """Extract LinkedIn job alerts from email"""

        jobs = []

        if not self.imap:
            return jobs

        try:
            # Select inbox
            self.imap.select("INBOX")

            # Search for LinkedIn emails (last N days)
            since_date = (datetime.now() - timedelta(days=days)).strftime("%d-%b-%Y")
            status, email_ids = self.imap.search(None, f'FROM "linkedin" SINCE {since_date}')

            if status != "OK":
                return jobs

            print(f"[LinkedIn] Found {len(email_ids[0].split())} LinkedIn emails")

            for email_id in email_ids[0].split()[-50:]:  # Last 50 emails
                try:
                    status, msg_data = self.imap.fetch(email_id, "(RFC822)")
                    msg = email.message_from_bytes(msg_data[0][1])

                    # Extract text
                    text = self._extract_text(msg)

                    # Parse LinkedIn job offers (typical format: "Job Title at Company")
                    job = self._parse_linkedin_job(text)
                    if job:
                        jobs.append(job)

                except Exception as e:
                    print(f"[LinkedIn] Parse error: {str(e)[:60]}")
                    continue

        except Exception as e:
            print(f"[LinkedIn] Fetch error: {str(e)[:100]}")

        print(f"[LinkedIn] Extracted {len(jobs)} job offers")
        return jobs

    async def fetch_cdi_discussion(self, days: int = 1) -> list[NormalizedJob]:
        """Extract CDIscussion alerts from email"""

        jobs = []

        if not self.imap:
            return jobs

        try:
            self.imap.select("INBOX")

            # Search for CDIscussion emails
            since_date = (datetime.now() - timedelta(days=days)).strftime("%d-%b-%Y")
            status, email_ids = self.imap.search(None, f'FROM "cdi" SINCE {since_date}')

            if status != "OK":
                return jobs

            print(f"[CDIscussion] Found {len(email_ids[0].split())} CDIscussion emails")

            for email_id in email_ids[0].split()[-30:]:
                try:
                    status, msg_data = self.imap.fetch(email_id, "(RFC822)")
                    msg = email.message_from_bytes(msg_data[0][1])

                    text = self._extract_text(msg)
                    job = self._parse_cdi_job(text)
                    if job:
                        jobs.append(job)

                except Exception as e:
                    print(f"[CDIscussion] Parse error: {str(e)[:60]}")
                    continue

        except Exception as e:
            print(f"[CDIscussion] Fetch error: {str(e)[:100]}")

        print(f"[CDIscussion] Extracted {len(jobs)} job offers")
        return jobs

    async def fetch_opportunities_africa(self, days: int = 1) -> list[NormalizedJob]:
        """Extract Opportunités Africa alerts from email"""

        jobs = []

        if not self.imap:
            return jobs

        try:
            self.imap.select("INBOX")

            since_date = (datetime.now() - timedelta(days=days)).strftime("%d-%b-%Y")
            status, email_ids = self.imap.search(
                None, f'FROM "opportunities" SINCE {since_date}'
            )

            if status != "OK":
                return jobs

            print(f"[Opportunities Africa] Found {len(email_ids[0].split())} emails")

            for email_id in email_ids[0].split()[-30:]:
                try:
                    status, msg_data = self.imap.fetch(email_id, "(RFC822)")
                    msg = email.message_from_bytes(msg_data[0][1])

                    text = self._extract_text(msg)
                    job = self._parse_opportunities_job(text)
                    if job:
                        jobs.append(job)

                except Exception as e:
                    print(f"[Opportunities Africa] Parse error: {str(e)[:60]}")
                    continue

        except Exception as e:
            print(f"[Opportunities Africa] Fetch error: {str(e)[:100]}")

        print(f"[Opportunities Africa] Extracted {len(jobs)} job offers")
        return jobs

    @staticmethod
    def _extract_text(msg) -> str:
        """Extract plain text from email message"""

        text = ""
        if msg.is_multipart():
            for part in msg.walk():
                if part.get_content_type() == "text/plain":
                    text += part.get_payload(decode=True).decode("utf-8", errors="ignore")
        else:
            text = msg.get_payload(decode=True).decode("utf-8", errors="ignore")

        return text

    @staticmethod
    def _parse_linkedin_job(text: str) -> Optional[NormalizedJob]:
        """Parse LinkedIn job email"""

        # LinkedIn format: "Title at Company · Location"
        # Extract: title, company, description snippet

        lines = text.split("\n")
        title = ""
        company = ""
        description = ""

        for line in lines:
            if " at " in line and len(line) < 200:
                parts = line.split(" at ")
                title = parts[0].strip()
                company = parts[1].split("·")[0].strip() if "·" in parts[1] else parts[1].strip()
                break

        if not title or not company:
            return None

        # Extract description (next 5 lines)
        found = False
        for i, line in enumerate(lines):
            if title in line:
                found = True
                continue
            if found and i < len(lines) - 5:
                description += line + " "

        try:
            job = NormalizedJob(
                source="linkedin_email",
                source_id=f"linkedin_{int(datetime.now().timestamp())}",
                source_url="https://www.linkedin.com/jobs",
                title=title,
                company=company,
                company_url=None,
                description=description[:500],
                description_clean=description[:500],
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
            return job
        except:
            return None

    @staticmethod
    def _parse_cdi_job(text: str) -> Optional[NormalizedJob]:
        """Parse CDIscussion job email"""

        # CDIscussion format varies, extract key info
        lines = [l.strip() for l in text.split("\n") if l.strip()]

        title = ""
        company = ""
        for line in lines:
            if len(line) > 10 and len(line) < 150:
                title = line
                break

        if not title:
            return None

        try:
            job = NormalizedJob(
                source="cdi_discussion",
                source_id=f"cdi_{int(datetime.now().timestamp())}",
                source_url="https://www.cdiscount.com",  # Placeholder
                title=title,
                company="CDIscussion",
                company_url=None,
                description=text[:500],
                description_clean=text[:500],
                job_type="full_time",
                seniority="mid",
                remote_type="on_site",
                location_required=None,
                salary_min=None,
                salary_max=None,
                salary_currency="XOF",  # West African Franc
                salary_period="yearly",
                required_skills=[],
                preferred_skills=[],
                experience_years_min=0,
                experience_years_max=5,
                posted_at=datetime.now(),
                expires_at=datetime.now() + timedelta(days=30),
            )
            return job
        except:
            return None

    @staticmethod
    def _parse_opportunities_job(text: str) -> Optional[NormalizedJob]:
        """Parse Opportunités Africa job email"""

        lines = [l.strip() for l in text.split("\n") if l.strip()]

        # Extract title and company
        title = ""
        company = ""
        location = "Africa"

        for i, line in enumerate(lines):
            if len(line) > 10 and len(line) < 150 and i < 5:
                title = line
                if i + 1 < len(lines):
                    company = lines[i + 1]
                break

        if not title:
            return None

        try:
            job = NormalizedJob(
                source="opportunities_africa",
                source_id=f"oaf_{int(datetime.now().timestamp())}",
                source_url="https://www.opportunitiesafrica.com",
                title=title,
                company=company or "Opportunities Africa",
                company_url=None,
                description=text[:500],
                description_clean=text[:500],
                job_type="full_time",
                seniority="mid",
                remote_type="hybrid",
                location_required="Africa",
                salary_min=None,
                salary_max=None,
                salary_currency="USD",
                salary_period="yearly",
                required_skills=[],
                preferred_skills=[],
                experience_years_min=0,
                experience_years_max=5,
                posted_at=datetime.now(),
                expires_at=datetime.now() + timedelta(days=30),
            )
            return job
        except:
            return None

    def disconnect(self):
        """Disconnect from email"""
        if self.imap:
            self.imap.close()
            self.imap.logout()
            print("[Email] Disconnected")


async def scrape_email_jobs(
    email_address: str = None,
    email_password: str = None,
) -> list[dict]:
    """Convenience function to scrape all email job sources"""

    # Get from env if not provided
    email_address = email_address or os.getenv("EMAIL_ADDRESS")
    email_password = email_password or os.getenv("EMAIL_PASSWORD")

    if not email_address or not email_password:
        print("[Email] Credentials not provided")
        return []

    parser = EmailJobParser(email_address, email_password)

    if not await parser.connect():
        return []

    all_jobs = []

    # Fetch from all email sources
    linkedin_jobs = await parser.fetch_linkedin_jobs(days=1)
    all_jobs.extend(linkedin_jobs)

    cdi_jobs = await parser.fetch_cdi_discussion(days=1)
    all_jobs.extend(cdi_jobs)

    oaf_jobs = await parser.fetch_opportunities_africa(days=1)
    all_jobs.extend(oaf_jobs)

    parser.disconnect()

    return [job.to_dict() for job in all_jobs]


if __name__ == "__main__":
    import asyncio

    async def test():
        # Get from env
        email = os.getenv("EMAIL_ADDRESS")
        password = os.getenv("EMAIL_PASSWORD")

        if not email or not password:
            print("[ERROR] Set EMAIL_ADDRESS and EMAIL_PASSWORD in .env")
            return

        jobs = await scrape_email_jobs(email, password)
        print(f"\n[RESULT] {len(jobs)} jobs found from email")
        for job in jobs[:5]:
            print(f"  • {job['title']} @ {job['company']}")

    asyncio.run(test())
