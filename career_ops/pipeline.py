"""
Complete Career-Ops Pipeline (Point 5)
End-to-end: Scrape → Parse CV → Score → Filter → Report
"""

import sys
import json
from pathlib import Path
from datetime import datetime

sys.path.insert(0, str(Path(__file__).parent.parent))

from career_ops.parsing.cv_parser import extract_sidoine_profile
from career_ops.scrapers.test_data import generate_test_jobs
from career_ops.matching.scorer import JobScorer, grade_score


def run_pipeline_test():
    """Execute complete pipeline with test data"""

    print("=" * 70)
    print("CAREER-OPS PIPELINE - POINT 5: COMPLETE END-TO-END TEST")
    print("=" * 70)
    print(f"Date: {datetime.now().isoformat()}")
    print()

    # STEP 1: Parse Sidoine's CV
    print("[STEP 1] Parse Sidoine's Profile")
    print("-" * 70)
    try:
        profile = extract_sidoine_profile()
        print(f"[OK] Profile: {profile.full_name}")
        print(f"  - Experience: {profile.years_experience} years")
        print(f"  - Skills Primary: {', '.join(profile.skills_primary)}")
        print(f"  - Skills Secondary: {', '.join(profile.skills_secondary[:3])}...")
        print(f"  - Min Salary: ${profile.min_salary_usd}k")
        print(f"  - Target Roles: {', '.join(profile.target_roles[:2])}...")
        print()
    except Exception as e:
        print(f"[ERROR] {str(e)[:100]}")
        return

    # STEP 2: Scrape test jobs
    print("[STEP 2] Scrape Jobs (using test data)")
    print("-" * 70)
    try:
        raw_jobs = generate_test_jobs()
        print(f"[OK] Found {len(raw_jobs)} test jobs")
        for job in raw_jobs[:3]:
            print(f"  - {job.title} @ {job.company}")
        if len(raw_jobs) > 3:
            print(f"  ... and {len(raw_jobs) - 3} more")
        print()
    except Exception as e:
        print(f"[ERROR] {str(e)[:100]}")
        return

    # STEP 3: Score jobs
    print("[STEP 3] Score Jobs (8-factor algorithm)")
    print("-" * 70)
    matches = []
    try:
        for raw_job in raw_jobs:
            job_dict = raw_job.to_dict()
            score = JobScorer.score(profile, job_dict)
            grade = grade_score(score.score_total)

            matches.append({
                "job": raw_job,
                "score": score,
                "grade": grade,
            })

            print(f"  {grade:10} ({score.score_total:.2f}) | {raw_job.title}")
            print(f"             Primary: {score.score_skills_primary:.2f} | Exp: {score.score_experience:.2f} | Sal: {score.score_salary_fit:.2f}")

        print()
    except Exception as e:
        print(f"[ERROR] {str(e)[:100]}")
        return

    # STEP 4: Filter by threshold
    print("[STEP 4] Filter by Threshold (>= 0.55)")
    print("-" * 70)
    excellent = [m for m in matches if m["score"].score_total >= 0.75]
    good = [m for m in matches if 0.55 <= m["score"].score_total < 0.75]

    print(f"  EXCELLENT (>= 0.75): {len(excellent)} jobs")
    for match in excellent:
        print(
            f"    - {match['job'].title} @ {match['job'].company} ({match['score'].score_total:.2f})"
        )

    print(f"\n  GOOD (0.55-0.74): {len(good)} jobs")
    for match in good:
        print(
            f"    - {match['job'].title} @ {match['job'].company} ({match['score'].score_total:.2f})"
        )

    print()

    # STEP 5: Generate report
    print("[STEP 5] Generate Report")
    print("-" * 70)

    report = {
        "date": datetime.now().isoformat(),
        "profile": {
            "name": profile.full_name,
            "experience_years": profile.years_experience,
            "target_roles": profile.target_roles,
        },
        "summary": {
            "jobs_scraped": len(raw_jobs),
            "jobs_excellent": len(excellent),
            "jobs_good": len(good),
        },
        "top_matches": [
            {
                "rank": i + 1,
                "title": match["job"].title,
                "company": match["job"].company,
                "salary": f"${match['job'].salary_min}k-${match['job'].salary_max}k",
                "score": round(match["score"].score_total, 3),
                "grade": match["grade"],
                "skills_match": {
                    "primary": round(match["score"].score_skills_primary, 2),
                    "secondary": round(match["score"].score_skills_secondary, 2),
                    "experience": round(match["score"].score_experience, 2),
                },
            }
            for i, match in enumerate(sorted(matches, key=lambda m: m["score"].score_total, reverse=True)[:5])
        ],
    }

    print(f"Summary:")
    print(f"  Jobs Scraped: {report['summary']['jobs_scraped']}")
    print(f"  Excellent Matches: {report['summary']['jobs_excellent']}")
    print(f"  Good Matches: {report['summary']['jobs_good']}")
    print()

    # STEP 6: Save report
    print("[STEP 6] Save Report")
    print("-" * 70)

    report_dir = Path("reports/career_ops")
    report_dir.mkdir(parents=True, exist_ok=True)
    report_file = report_dir / f"pipeline_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"

    try:
        with open(report_file, "w") as f:
            json.dump(report, f, indent=2)

        print(f"[OK] Report saved: {report_file}")
        print()

        # Print summary
        print("[RESULT SUMMARY]")
        print("-" * 70)
        print(json.dumps(report, indent=2)[:500] + "...")
        print()

    except Exception as e:
        print(f"[ERROR] {str(e)[:100]}")

    print("=" * 70)
    print("PIPELINE COMPLETE [OK]")
    print("=" * 70)


if __name__ == "__main__":
    run_pipeline_test()
