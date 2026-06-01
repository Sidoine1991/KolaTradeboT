"""
Complete Career-Ops Pipeline - AWS RDS Integration
Scrape → Score → Store in AWS RDS → Report
"""

import sys
import json
from pathlib import Path
from datetime import datetime

sys.path.insert(0, str(Path(__file__).parent.parent))

from career_ops.parsing.cv_parser import extract_sidoine_profile
from career_ops.scrapers.test_data import generate_test_jobs
from career_ops.matching.scorer import JobScorer, grade_score
from career_ops.db.rds_repository import RDSRepository


def run_pipeline_with_rds():
    """Execute complete pipeline with AWS RDS storage"""

    print("=" * 70)
    print("CAREER-OPS PIPELINE - AWS RDS INTEGRATION")
    print("=" * 70)
    print(f"Date: {datetime.now().isoformat()}")
    print()

    # Initialize RDS
    try:
        repo = RDSRepository()
        print("[OK] Connected to AWS RDS")
    except Exception as e:
        print(f"[ERROR] RDS connection failed: {str(e)[:100]}")
        print("[ACTION] Set DATABASE_URL in .env and run migration")
        return

    # STEP 1: Parse Sidoine's CV
    print("\n[STEP 1] Parse Sidoine's Profile")
    print("-" * 70)
    try:
        profile = extract_sidoine_profile()
        print(f"[OK] Profile: {profile.full_name}")
        print(f"  - Experience: {profile.years_experience} years")
        print(f"  - Skills Primary: {', '.join(profile.skills_primary)}")
        print(f"  - Min Salary: ${profile.min_salary_usd}k")
    except Exception as e:
        print(f"[ERROR] {str(e)[:100]}")
        return

    # STEP 2: Scrape jobs
    print("\n[STEP 2] Scrape Jobs (test data)")
    print("-" * 70)
    try:
        raw_jobs = generate_test_jobs()
        print(f"[OK] Found {len(raw_jobs)} test jobs")
    except Exception as e:
        print(f"[ERROR] {str(e)[:100]}")
        return

    # STEP 3: Insert jobs into RDS
    print("\n[STEP 3] Insert Jobs into AWS RDS")
    print("-" * 70)
    jobs_stored = 0
    jobs_duplicate = 0
    job_ids = []

    for raw_job in raw_jobs:
        job_dict = raw_job.to_dict()
        job_id = repo.insert_job(job_dict)

        if job_id:
            jobs_stored += 1
            job_ids.append(job_id)
            print(f"  [+] {raw_job.title[:40]:40} → ID: {job_id}")
        else:
            jobs_duplicate += 1
            print(f"  [~] {raw_job.title[:40]:40} (duplicate)")

    print(f"\n  Total stored: {jobs_stored}")
    print(f"  Duplicates: {jobs_duplicate}")

    # STEP 4: Score jobs
    print("\n[STEP 4] Score Jobs & Insert Matches")
    print("-" * 70)
    matches_stored = 0

    for i, raw_job in enumerate(raw_jobs):
        if not job_ids or i >= len(job_ids):
            continue

        job_dict = raw_job.to_dict()
        score = JobScorer.score(profile, job_dict)
        grade = grade_score(score.score_total)

        # Insert match into RDS
        match_dict = {
            'profile_id': 1,  # Sidoine's profile ID
            'job_id': job_ids[i],
            'score_skills_primary': score.score_skills_primary,
            'score_skills_secondary': score.score_skills_secondary,
            'score_experience': score.score_experience,
            'score_remote_fit': score.score_remote_fit,
            'score_seniority_fit': score.score_seniority_fit,
            'score_salary_fit': score.score_salary_fit,
            'score_semantic': score.score_semantic,
            'score_recency': score.score_recency,
            'score_total': score.score_total,
            'status': 'new',
        }

        match_id = repo.insert_match(match_dict)
        if match_id:
            matches_stored += 1

        print(f"  {grade:10} ({score.score_total:.2f}) | {raw_job.title[:40]}")

    print(f"\n  Matches stored: {matches_stored}")

    # STEP 5: Get top matches from RDS
    print("\n[STEP 5] Query Top Matches from RDS")
    print("-" * 70)
    top_matches = repo.get_top_matches(profile_id=1, limit=10)

    excellent = [m for m in top_matches if m['score_total'] >= 0.75]
    good = [m for m in top_matches if 0.55 <= m['score_total'] < 0.75]

    print(f"  EXCELLENT (>= 0.75): {len(excellent)}")
    for match in excellent:
        print(f"    - {match['title']} @ {match['company']} ({match['score_total']:.2f})")

    print(f"\n  GOOD (0.55-0.74): {len(good)}")
    for match in good[:3]:
        print(f"    - {match['title']} @ {match['company']} ({match['score_total']:.2f})")

    # STEP 6: Log scraper run
    print("\n[STEP 6] Log Scraper Run")
    print("-" * 70)
    success = repo.log_scraper_run(
        source='test_data',
        jobs_found=len(raw_jobs),
        jobs_new=jobs_stored
    )
    if success:
        print("[OK] Scraper run logged")

    # STEP 7: Generate report
    print("\n[STEP 7] Generate Report")
    print("-" * 70)
    report = {
        "date": datetime.now().isoformat(),
        "pipeline": "aws_rds",
        "profile": {
            "name": profile.full_name,
            "experience_years": profile.years_experience,
            "target_roles": profile.target_roles,
        },
        "rds_stats": {
            "jobs_inserted": jobs_stored,
            "jobs_duplicate": jobs_duplicate,
            "matches_stored": matches_stored,
        },
        "matches": [
            {
                "rank": i + 1,
                "title": match['title'],
                "company": match['company'],
                "salary": f"${match['salary_min']}-${match['salary_max']}" if match['salary_min'] else "N/A",
                "score": round(match['score_total'], 3),
                "source": match.get('source_url', 'N/A'),
            }
            for i, match in enumerate(top_matches[:5])
        ],
    }

    # Save report
    report_dir = Path("reports/career_ops")
    report_dir.mkdir(parents=True, exist_ok=True)
    report_file = report_dir / f"pipeline_rds_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"

    try:
        with open(report_file, "w") as f:
            json.dump(report, f, indent=2)
        print(f"[OK] Report saved: {report_file}")
    except Exception as e:
        print(f"[ERROR] Could not save report: {str(e)[:100]}")

    print()
    print("=" * 70)
    print("PIPELINE COMPLETE [OK]")
    print("=" * 70)
    print()
    print("Next steps:")
    print("  1. Verify data in AWS RDS:")
    print("     SELECT COUNT(*) FROM career_ops.jobs;")
    print("  2. Query top matches:")
    print("     SELECT * FROM career_ops.job_matches ORDER BY score_total DESC;")
    print("  3. Deploy real scrapers (Week 2)")


if __name__ == "__main__":
    run_pipeline_with_rds()
