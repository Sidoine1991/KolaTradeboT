"""
Career-Ops Autonomous Scheduler
Runs daily at 06:00 WAT via Windows Task Scheduler
Orchestrates: Scrape → Score → Store → Deliver
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
from career_ops.matching.intelligent_scorer import IntelligentJobScorer
from career_ops.db.rds_repository import RDSRepository
from career_ops.delivery.psychobot_client import PsychoBotClient
from career_ops.delivery.intelligent_digest_builder import IntelligentDigestBuilder


async def run_scheduled_pipeline():
    """
    Main autonomous pipeline
    Called by Windows Task Scheduler at 06:00 WAT
    """

    print("=" * 70)
    print("CAREER-OPS AUTONOMOUS SCHEDULER")
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

    # STEP 1: Scrape all 4 sources
    print("\n[STEP 1] Scrape All Sources")
    print("-" * 70)

    all_jobs = []
    scrapers = [
        ("RemoteOK", RemoteOKScraper()),
        ("Himalayas", HimalayasScraper()),
        ("We Work Remotely", WeWorkRemotelyScaper()),
        ("Indeed", IndeedScraper()),
    ]

    for name, scraper in scrapers:
        print(f"  [{name}]", end="")
        try:
            jobs = await scraper.fetch()
            all_jobs.extend(jobs)
            print(f" -> {len(jobs)} jobs")
        except Exception as e:
            print(f" [ERROR] {str(e)[:60]}")
            continue

    print(f"\n  Total: {len(all_jobs)} jobs from 4 sources")

    # STEP 2: Insert & Score with Claude
    print("\n[STEP 2] Insert, Score & Analyze Jobs")
    print("-" * 70)

    scorer = IntelligentJobScorer()
    jobs_stored = 0
    jobs_duplicate = 0
    matches = []

    for i, raw_job in enumerate(all_jobs):
        if i % 10 == 0:
            print(f"  Processing: {i}/{len(all_jobs)}", end="\r")

        job_dict = raw_job.to_dict()

        # Insert into RDS
        job_id = repo.insert_job(job_dict)
        if not job_id:
            jobs_duplicate += 1
            continue

        jobs_stored += 1

        # Score with Claude (intelligent)
        try:
            score_result = await scorer.score_with_reasoning(profile, job_dict)
        except:
            # Fallback to algorithm if Claude fails
            from career_ops.matching.scorer import JobScorer
            algo_score = JobScorer.score(profile, job_dict)
            score_result = {
                "algorithm_score": algo_score.score_total,
                "should_apply": algo_score.score_total >= 0.55,
                "recommendation": "consider" if algo_score.score_total >= 0.55 else "skip",
            }

        # Insert match
        match_dict = {
            "profile_id": 1,
            "job_id": job_id,
            "score_skills_primary": score_result.get("algorithm_components", {}).get("skills_primary", 0),
            "score_skills_secondary": score_result.get("algorithm_components", {}).get("skills_secondary", 0),
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

        # Track if should apply
        if score_result.get("should_apply"):
            matches.append({
                "title": raw_job.title,
                "company": raw_job.company,
                "score": score_result.get("algorithm_score", 0),
                "salary_min": raw_job.salary_min,
                "salary_max": raw_job.salary_max,
                "source_url": raw_job.source_url,
            })

    print(f"\n  Stored: {jobs_stored} new jobs")
    print(f"  Duplicates: {jobs_duplicate}")
    print(f"  Matches (score >= 0.55): {len(matches)}")

    # STEP 3: Query top matches
    print("\n[STEP 3] Query Top Matches")
    print("-" * 70)

    top_matches = repo.get_top_matches(profile_id=1, limit=20)
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
        print(f"  [WARNING] Intelligent digest failed: {str(e)[:60]}")
        # Fallback to simple digest
        digest_text = f"Found {len(top_matches)} job matches for {profile.full_name} today."

    # STEP 5: Send via PsychoBot
    print("\n[STEP 5] Send via PsychoBot")
    print("-" * 70)

    try:
        client = PsychoBotClient()
        success = await client.send_digest(digest_text)
        if success:
            print("[OK] Digest sent via WhatsApp")
        else:
            print("[WARNING] WhatsApp delivery failed (offline?)")
    except Exception as e:
        print(f"[WARNING] PsychoBot error: {str(e)[:80]}")

    # STEP 6: Log & Save
    print("\n[STEP 6] Log & Save Report")
    print("-" * 70)

    repo.log_scraper_run("combined", jobs_found=len(all_jobs), jobs_new=jobs_stored)

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
    }

    # Save report
    report_dir = Path("reports/career_ops")
    report_dir.mkdir(parents=True, exist_ok=True)
    report_file = report_dir / f"daily_{datetime.now().strftime('%Y%m%d')}.json"

    with open(report_file, "w") as f:
        json.dump(report, f, indent=2)

    print(f"[OK] Report saved: {report_file}")

    # SUMMARY
    print()
    print("=" * 70)
    print("PIPELINE COMPLETE")
    print("=" * 70)
    print(f"Jobs scraped: {len(all_jobs)}")
    print(f"Jobs stored: {jobs_stored}")
    print(f"Matches: {len(top_matches)}")
    print(f"Digest: Sent to WhatsApp")
    print(f"Duration: {(datetime.now()).isoformat()}")
    print()


if __name__ == "__main__":
    asyncio.run(run_scheduled_pipeline())
