"""
Career-Ops Test Scheduler (with test data, no network calls)
For development/testing WITHOUT external APIs or network dependency
"""

import asyncio
import json
import sys
from datetime import datetime
from pathlib import Path

# Ensure imports work
sys.path.insert(0, str(Path(__file__).parent.parent))

from career_ops.parsing.cv_parser import extract_sidoine_profile
from career_ops.scrapers.test_data import generate_test_jobs
from career_ops.matching.intelligent_scorer import IntelligentJobScorer
from career_ops.db.rds_repository import RDSRepository
from career_ops.delivery.intelligent_digest_builder import IntelligentDigestBuilder


async def run_test_pipeline():
    """Test pipeline using local test data (no network calls)"""

    print("=" * 70)
    print("CAREER-OPS TEST PIPELINE (Test Data Only)")
    print(f"Started: {datetime.now().isoformat()}")
    print("=" * 70)
    print()

    # Setup
    try:
        repo = RDSRepository()
        print("[OK] RDS Repository initialized")
    except Exception as e:
        print(f"[WARNING] RDS connection failed: {str(e)[:100]}")
        print("[INFO] Continuing with in-memory storage only")
        repo = None

    try:
        profile = extract_sidoine_profile()
        print(f"[OK] Profile loaded: {profile.full_name}")
    except Exception as e:
        print(f"[ERROR] Profile load failed: {str(e)[:100]}")
        return

    # STEP 1: Load test jobs (no network)
    print("\n[STEP 1] Load Test Jobs")
    print("-" * 70)

    all_jobs = generate_test_jobs()
    print(f"[OK] Loaded {len(all_jobs)} test jobs (no network calls)")
    for job in all_jobs[:3]:
        print(f"  • {job.title} @ {job.company}")

    # STEP 2: Insert & Score
    print("\n[STEP 2] Insert, Score & Analyze")
    print("-" * 70)

    scorer = IntelligentJobScorer()
    jobs_stored = 0
    jobs_duplicate = 0
    matches = []
    match_details = []

    for i, job in enumerate(all_jobs):
        job_dict = job.to_dict()

        # Insert
        if repo:
            try:
                job_id = repo.insert_job(job_dict)
                if not job_id:
                    jobs_duplicate += 1
                    continue
                jobs_stored += 1
            except Exception as e:
                print(f"  [WARNING] Insert failed: {str(e)[:60]}")
                jobs_stored += 1
                job_id = i + 1
        else:
            job_id = i + 1
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

        if repo:
            try:
                repo.insert_match(match_dict)
            except Exception as e:
                print(f"  [WARNING] Match insert failed: {str(e)[:60]}")

        # Store for display
        if score_result.get("should_apply"):
            matches.append(
                {
                    "id": i + 1,
                    "title": job_dict.get("title", ""),
                    "company": job_dict.get("company", ""),
                    "score": score_result.get("algorithm_score", 0),
                    "salary_min": job_dict.get("salary_min"),
                    "salary_max": job_dict.get("salary_max"),
                }
            )
            match_details.append(match_dict)

    print(f"  Stored: {jobs_stored} jobs")
    print(f"  Duplicates: {jobs_duplicate}")
    print(f"  Matches (score >= 0.55): {len(matches)}")

    # STEP 3: Display matches
    print("\n[STEP 3] Top Matches")
    print("-" * 70)

    for i, match in enumerate(matches[:5], 1):
        score = match["score"]
        grade = "[EXCELLENT]" if score >= 0.75 else "[GOOD]" if score >= 0.55 else "[MARGINAL]"
        print(f"  {i}. {grade} {match['title']} @ {match['company']}")
        print(f"     Score: {score:.2f} | Salary: ${match['salary_min']}-${match['salary_max']}")

    # STEP 4: Build digest
    print("\n[STEP 4] Build Digest")
    print("-" * 70)

    try:
        digest_builder = IntelligentDigestBuilder()
        digest_text = await digest_builder.build_intelligent_digest(
            profile.full_name,
            [
                {
                    "title": m["title"],
                    "company": m["company"],
                    "score": m["score"],
                    "salary_min": m["salary_min"],
                    "salary_max": m["salary_max"],
                    "source_url": "",
                }
                for m in matches
            ],
        )
        print(f"  Digest built: {len(digest_text)} chars")
        print("\n" + digest_text[:300] + "...\n")
    except Exception as e:
        print(f"  [WARNING] Digest failed: {str(e)[:60]}")
        digest_text = f"Found {len(matches)} job matches today."

    # STEP 5: Save report
    print("[STEP 5] Save Report")
    print("-" * 70)

    report = {
        "timestamp": datetime.now().isoformat(),
        "profile": profile.full_name,
        "test_mode": True,
        "sources": {
            "total_jobs": len(all_jobs),
            "new_jobs": jobs_stored,
            "duplicates": jobs_duplicate,
            "source": "test_data",
        },
        "matches": {
            "total": len(matches),
            "excellent": len([m for m in matches if m["score"] >= 0.75]),
            "good": len([m for m in matches if 0.55 <= m["score"] < 0.75]),
        },
        "top_matches": [
            {
                "title": m["title"],
                "company": m["company"],
                "score": m["score"],
                "salary_min": m["salary_min"],
                "salary_max": m["salary_max"],
            }
            for m in matches[:5]
        ],
    }

    report_dir = Path("reports/career_ops")
    report_dir.mkdir(parents=True, exist_ok=True)
    report_file = report_dir / f"test_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"

    with open(report_file, "w") as f:
        json.dump(report, f, indent=2)

    print(f"[OK] Report saved: {report_file}")

    # SUMMARY
    print()
    print("=" * 70)
    print("TEST PIPELINE COMPLETE")
    print("=" * 70)
    print(f"Test jobs: {len(all_jobs)}")
    print(f"Jobs scored: {jobs_stored}")
    print(f"Matches: {len(matches)}")
    if matches:
        print(f"  [EXCELLENT] (>= 0.75): {len([m for m in matches if m['score'] >= 0.75])}")
        print(f"  [GOOD] (0.55-0.74): {len([m for m in matches if 0.55 <= m['score'] < 0.75])}")
    print(f"Report: {report_file}")
    print()


if __name__ == "__main__":
    asyncio.run(run_test_pipeline())
