"""
Career-Ops Week 2 Pipeline
3 real job sources + intelligent scoring + WhatsApp delivery
RemoteOK + Himalayas + We Work Remotely → RDS → PsychoBot
"""

import sys
import json
import asyncio
from pathlib import Path
from datetime import datetime

sys.path.insert(0, str(Path(__file__).parent.parent))

from career_ops.parsing.cv_parser import extract_sidoine_profile
from career_ops.scrapers.remoteok import RemoteOKScraper
from career_ops.scrapers.himalayas import HimalayasScraper
from career_ops.scrapers.weworkremotely import WeWorkRemotelyScaper
from career_ops.matching.scorer import JobScorer, grade_score
from career_ops.db.rds_repository import RDSRepository
from career_ops.delivery.digest_builder import DigestBuilder
from career_ops.delivery.psychobot_client import PsychoBotClient


async def run_week2_pipeline():
    """Execute Week 2 pipeline with 3 sources"""

    print("=" * 70)
    print("CAREER-OPS WEEK 2 PIPELINE")
    print("3 Real Job Sources + RDS Storage + WhatsApp Delivery")
    print("=" * 70)
    print(f"Date: {datetime.now().isoformat()}")
    print()

    # Initialize
    try:
        repo = RDSRepository()
        print("[OK] AWS RDS Repository initialized")
    except Exception as e:
        print(f"[ERROR] RDS connection failed: {str(e)[:100]}")
        return

    # STEP 1: Parse profile
    print("\n[STEP 1] Parse Sidoine's Profile")
    print("-" * 70)
    try:
        profile = extract_sidoine_profile()
        print(f"[OK] {profile.full_name} ({profile.years_experience} years)")
        print(f"     Skills: {', '.join(profile.skills_primary[:3])}...")
    except Exception as e:
        print(f"[ERROR] {str(e)[:100]}")
        return

    # STEP 2: Scrape from 3 sources
    print("\n[STEP 2] Scrape Jobs from 3 Sources")
    print("-" * 70)

    all_jobs = []
    scrapers = [
        ("RemoteOK", RemoteOKScraper()),
        ("Himalayas", HimalayasScraper()),
        ("We Work Remotely", WeWorkRemotelyScaper()),
    ]

    for name, scraper in scrapers:
        print(f"\n  [{name}]")
        try:
            jobs = await scraper.fetch()
            all_jobs.extend(jobs)
            print(f"    -> {len(jobs)} jobs fetched")
        except Exception as e:
            print(f"    [ERROR] {str(e)[:80]}")

    print(f"\n  Total jobs from 3 sources: {len(all_jobs)}")

    # STEP 3: Insert into RDS + Score
    print("\n[STEP 3] Insert Jobs & Score Against Profile")
    print("-" * 70)

    matches = []
    jobs_stored = 0
    jobs_duplicate = 0

    for raw_job in all_jobs:
        job_dict = raw_job.to_dict()

        # Insert into RDS
        job_id = repo.insert_job(job_dict)

        if not job_id:
            jobs_duplicate += 1
            continue

        jobs_stored += 1

        # Score the job
        score = JobScorer.score(profile, job_dict)
        grade = grade_score(score.score_total)

        # Insert match into RDS
        match_dict = {
            "profile_id": 1,
            "job_id": job_id,
            "score_skills_primary": score.score_skills_primary,
            "score_skills_secondary": score.score_skills_secondary,
            "score_experience": score.score_experience,
            "score_remote_fit": score.score_remote_fit,
            "score_seniority_fit": score.score_seniority_fit,
            "score_salary_fit": score.score_salary_fit,
            "score_semantic": score.score_semantic,
            "score_recency": score.score_recency,
            "score_total": score.score_total,
            "status": "new",
        }

        repo.insert_match(match_dict)

        # Store match
        matches.append({
            "title": raw_job.title,
            "company": raw_job.company,
            "score": score.score_total,
            "grade": grade,
            "salary_min": raw_job.salary_min,
            "salary_max": raw_job.salary_max,
            "source_url": raw_job.source_url,
        })

    print(f"  Jobs stored: {jobs_stored}")
    print(f"  Duplicates: {jobs_duplicate}")

    # STEP 4: Filter & rank
    print("\n[STEP 4] Filter & Rank Matches")
    print("-" * 70)

    top_matches = repo.get_top_matches(profile_id=1, limit=20)

    if not top_matches:
        print("  No matches found.")
        top_matches = []
    else:
        # Convert RDS matches to match dict format
        top_matches_formatted = [
            {
                "title": m["title"],
                "company": m["company"],
                "score": m["score_total"],
                "salary_min": m["salary_min"],
                "salary_max": m["salary_max"],
                "source_url": m["source_url"],
            }
            for m in top_matches
        ]

        excellent = len([m for m in top_matches if m["score_total"] >= 0.75])
        good = len([m for m in top_matches if 0.55 <= m["score_total"] < 0.75])

        print(f"  Excellent (>= 0.75): {excellent}")
        print(f"  Good (0.55-0.74): {good}")
        print(f"  Total matches: {len(top_matches)}")

        # STEP 5: Build digest
        print("\n[STEP 5] Build WhatsApp Digest")
        print("-" * 70)

        digest = DigestBuilder.build_full_digest(profile.full_name, top_matches_formatted)

        print(f"  Digest preview:")
        print(f"  {digest['message'][:200]}...")

        # STEP 6: Send via PsychoBot
        print("\n[STEP 6] Send via PsychoBot WhatsApp")
        print("-" * 70)

        try:
            client = PsychoBotClient()
            success = await client.send_digest(digest["message"])

            if success:
                print("[OK] Digest sent via WhatsApp!")
            else:
                print("[WARNING] Could not send via WhatsApp (PsychoBot offline?)")

        except Exception as e:
            print(f"[WARNING] {str(e)[:100]}")

        # STEP 7: Log & Report
        print("\n[STEP 7] Generate Report")
        print("-" * 70)

        # Log scraper runs
        repo.log_scraper_run("remoteok", jobs_found=len(all_jobs), jobs_new=jobs_stored)

        # Save report
        report = {
            "date": datetime.now().isoformat(),
            "profile": profile.full_name,
            "sources": {
                "total_jobs": len(all_jobs),
                "jobs_stored": jobs_stored,
                "duplicates": jobs_duplicate,
            },
            "matches": {
                "total": len(top_matches),
                "excellent": excellent,
                "good": good,
            },
            "top_matches": [
                {
                    "rank": i + 1,
                    "title": m["title"],
                    "company": m["company"],
                    "score": round(m["score_total"], 3),
                    "source": m.get("source_url", "N/A")[:50],
                }
                for i, m in enumerate(top_matches[:5])
            ],
        }

        report_dir = Path("reports/career_ops")
        report_dir.mkdir(parents=True, exist_ok=True)
        report_file = report_dir / f"week2_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"

        with open(report_file, "w") as f:
            json.dump(report, f, indent=2)

        print(f"[OK] Report saved: {report_file}")

    print()
    print("=" * 70)
    print("WEEK 2 PIPELINE COMPLETE")
    print("=" * 70)
    print()
    print("Summary:")
    print(f"  - 3 job sources scraped")
    print(f"  - {jobs_stored} unique jobs stored in RDS")
    print(f"  - {len(top_matches)} matches scored & ranked")
    print(f"  - Digest delivered via WhatsApp")
    print()
    print("Next: Week 3 adds autonomy (Windows Scheduler @ 06:00 daily)")


if __name__ == "__main__":
    asyncio.run(run_week2_pipeline())
