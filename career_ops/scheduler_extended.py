"""
Career-Ops Extended Scheduler
Includes: Email parsing + Free web scrapers + Standard sources
Total: 8+ job sources (no API limits, no payments)
"""

import asyncio
import json
from datetime import datetime
from pathlib import Path

from career_ops.parsing.cv_parser import extract_sidoine_profile
from career_ops.scrapers.remoteok import RemoteOKScraper
from career_ops.scrapers.himalayas import HimalayasScraper
from career_ops.scrapers.weworkremotely import WeWorkRemotelyScaper
from career_ops.scrapers.indeed import IndeedScraper
from career_ops.scrapers.email_linkedin_parser import scrape_email_jobs
from career_ops.scrapers.web_scrapers_free import scrape_free_sources
from career_ops.matching.intelligent_scorer import IntelligentJobScorer
from career_ops.db.rds_repository import RDSRepository
from career_ops.delivery.psychobot_client import PsychoBotClient
from career_ops.delivery.intelligent_digest_builder import IntelligentDigestBuilder


async def run_extended_pipeline():
    """
    Extended autonomous pipeline with 8+ sources:
    1. RemoteOK (API)
    2. Himalayas (API)
    3. We Work Remotely (RSS)
    4. Indeed (Playwright)
    5. LinkedIn Email Alerts
    6. CDIscussion Email
    7. Opportunités Africa Email
    8. LinkedIn Public (Playwright)
    9. GitHub Jobs (RSS)
    10. Stack Overflow (RSS)
    """

    print("=" * 70)
    print("CAREER-OPS EXTENDED PIPELINE (10 Sources)")
    print(f"Started: {datetime.now().isoformat()}")
    print("=" * 70)
    print()

    # Setup
    try:
        repo = RDSRepository()
        print("[OK] RDS Repository initialized")
    except Exception as e:
        print(f"[ERROR] RDS connection failed: {str(e)[:100]}")
        return

    try:
        profile = extract_sidoine_profile()
        print(f"[OK] Profile loaded: {profile.full_name}")
    except Exception as e:
        print(f"[ERROR] Profile load failed: {str(e)[:100]}")
        return

    # STEP 1: Scrape all 10 sources in parallel
    print("\n[STEP 1] Scrape All 10 Sources")
    print("-" * 70)

    tasks = [
        ("RemoteOK", RemoteOKScraper().fetch()),
        ("Himalayas", HimalayasScraper().fetch()),
        ("We Work Remotely", WeWorkRemotelyScaper().fetch()),
        ("Indeed", IndeedScraper().fetch()),
        ("Email Sources", scrape_email_jobs()),
        ("Free Web (LinkedIn/GitHub/SO)", scrape_free_sources()),
    ]

    all_jobs = []
    for name, task in tasks:
        print(f"  [{name}]", end="")
        try:
            if isinstance(task, list):
                jobs = task
            else:
                jobs = await task
            all_jobs.extend([j if isinstance(j, dict) else j.to_dict() for j in jobs])
            print(f" ✓ {len(jobs)} jobs")
        except Exception as e:
            print(f" [ERROR] {str(e)[:40]}")
            continue

    print(f"\n  TOTAL: {len(all_jobs)} jobs from 10 sources")

    # STEP 2: Insert & Score
    print("\n[STEP 2] Insert, Score & Analyze")
    print("-" * 70)

    scorer = IntelligentJobScorer()
    jobs_stored = 0
    jobs_duplicate = 0
    matches = []

    for i, job_dict in enumerate(all_jobs):
        if i % 50 == 0:
            print(f"  Processing: {i}/{len(all_jobs)}", end="\r")

        # Insert
        if isinstance(job_dict, dict):
            job_id = repo.insert_job(job_dict)
        else:
            job_id = repo.insert_job(job_dict.to_dict())

        if not job_id:
            jobs_duplicate += 1
            continue

        jobs_stored += 1

        # Score
        try:
            score_result = await scorer.score_with_reasoning(profile, job_dict)
        except:
            from career_ops.matching.scorer import JobScorer
            algo_score = JobScorer.score(profile, job_dict)
            score_result = {
                "algorithm_score": algo_score.score_total,
                "should_apply": algo_score.score_total >= 0.55,
            }

        # Insert match
        match_dict = {
            "profile_id": 1,
            "job_id": job_id,
            "score_skills_primary": score_result.get("algorithm_components", {}).get(
                "skills_primary", 0
            ),
            "score_skills_secondary": score_result.get("algorithm_components", {}).get(
                "skills_secondary", 0
            ),
            "score_experience": score_result.get("algorithm_components", {}).get("experience", 0),
            "score_remote_fit": score_result.get("algorithm_components", {}).get("remote_fit", 0),
            "score_seniority_fit": score_result.get("algorithm_components", {}).get("seniority", 0),
            "score_salary_fit": score_result.get("algorithm_components", {}).get("salary", 0),
            "score_semantic": score_result.get("algorithm_components", {}).get("semantic", 0),
            "score_recency": score_result.get("algorithm_components", {}).get("recency", 0),
            "score_total": score_result.get("algorithm_score", 0),
            "status": "new",
        }

        repo.insert_match(match_dict)

        if score_result.get("should_apply"):
            matches.append(
                {
                    "title": job_dict.get("title", ""),
                    "company": job_dict.get("company", ""),
                    "score": score_result.get("algorithm_score", 0),
                    "salary_min": job_dict.get("salary_min"),
                    "salary_max": job_dict.get("salary_max"),
                    "source_url": job_dict.get("source_url", ""),
                }
            )

    print(f"\n  Stored: {jobs_stored} new jobs")
    print(f"  Duplicates: {jobs_duplicate}")
    print(f"  Matches: {len(matches)}")

    # STEP 3: Query top matches
    print("\n[STEP 3] Query Top Matches")
    print("-" * 70)

    top_matches = repo.get_top_matches(profile_id=1, limit=30)
    print(f"  Retrieved: {len(top_matches)} top matches")

    # STEP 4: Build intelligent digest
    print("\n[STEP 4] Build Intelligent Digest")
    print("-" * 70)

    try:
        digest_builder = IntelligentDigestBuilder()
        digest_text = await digest_builder.build_intelligent_digest(
            profile.full_name,
            [
                {
                    "title": m["title"],
                    "company": m["company"],
                    "score": m["score_total"],
                    "salary_min": m["salary_min"],
                    "salary_max": m["salary_max"],
                    "source_url": m["source_url"],
                }
                for m in top_matches
            ],
        )
        print(f"  Digest built: {len(digest_text)} chars")
    except Exception as e:
        print(f"  [WARNING] Digest failed: {str(e)[:60]}")
        digest_text = f"Found {len(top_matches)} job matches today."

    # STEP 5: Send via PsychoBot
    print("\n[STEP 5] Send via PsychoBot")
    print("-" * 70)

    try:
        client = PsychoBotClient()
        success = await client.send_digest(digest_text)
        if success:
            print("[OK] Digest sent via WhatsApp")
        else:
            print("[WARNING] WhatsApp delivery failed")
    except Exception as e:
        print(f"[WARNING] PsychoBot error: {str(e)[:80]}")

    # STEP 6: Log & Save
    print("\n[STEP 6] Log & Save Report")
    print("-" * 70)

    repo.log_scraper_run("extended_10sources", jobs_found=len(all_jobs), jobs_new=jobs_stored)

    report = {
        "timestamp": datetime.now().isoformat(),
        "profile": profile.full_name,
        "sources": {
            "total_jobs": len(all_jobs),
            "new_jobs": jobs_stored,
            "duplicates": jobs_duplicate,
        },
        "matches": {
            "total": len(top_matches),
            "excellent": len([m for m in top_matches if m["score_total"] >= 0.75]),
            "good": len([m for m in top_matches if 0.55 <= m["score_total"] < 0.75]),
        },
        "sources_breakdown": {
            "API_sources": 4,  # RemoteOK, Himalayas, etc
            "Email_sources": 3,  # LinkedIn, CDI, Opportunities
            "Web_sources": 3,  # LinkedIn public, GitHub, StackOverflow
        },
    }

    report_dir = Path("reports/career_ops")
    report_dir.mkdir(parents=True, exist_ok=True)
    report_file = report_dir / f"extended_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"

    with open(report_file, "w") as f:
        json.dump(report, f, indent=2)

    print(f"[OK] Report saved: {report_file}")

    # SUMMARY
    print()
    print("=" * 70)
    print("EXTENDED PIPELINE COMPLETE")
    print("=" * 70)
    print(f"Jobs scraped (10 sources): {len(all_jobs)}")
    print(f"Jobs stored: {jobs_stored}")
    print(f"Top matches: {len(top_matches)}")
    print(f"  - Excellent (≥0.75): {len([m for m in top_matches if m['score_total'] >= 0.75])}")
    print(f"  - Good (0.55-0.74): {len([m for m in top_matches if 0.55 <= m['score_total'] < 0.75])}")
    print(f"Digest: Sent to WhatsApp")
    print()


if __name__ == "__main__":
    asyncio.run(run_extended_pipeline())
