"""
Test job data for Point 5 (First Complete Pipeline)
Simulates RemoteOK/other sources with realistic data matching Sidoine's profile
"""

from datetime import datetime, timedelta
from .remoteok import NormalizedJob


REALISTIC_JOBS = [
    {
        "title": "Senior Python Data Analyst",
        "company": "DataFlow AI",
        "description": "Join our data team to build ETL pipelines with Python, SQL, and Tableau. We need someone with 4+ years experience in data analysis, data engineering. Remote fully. Competitive salary.",
        "salary_min": 55000,
        "salary_max": 75000,
        "seniority": "senior",
        "required_skills": ["python", "sql", "data analysis"],
        "preferred_skills": ["pandas", "tableau", "etl"],
    },
    {
        "title": "Full-Stack Python Developer (Remote)",
        "company": "TechStartup Inc",
        "description": "Build scalable APIs with FastAPI, React frontends. 3+ years Python & web dev. We work with SQL, PostgreSQL, Plotly for visualizations. Remote-only team based globally.",
        "salary_min": 50000,
        "salary_max": 70000,
        "seniority": "mid",
        "required_skills": ["python", "react", "sql"],
        "preferred_skills": ["fastapi", "streamlit", "plotly"],
    },
    {
        "title": "Data Scientist - Machine Learning",
        "company": "ML Labs",
        "description": "We're building ML models with Python, scikit-learn, NumPy. Need 4+ years in data science, machine learning. Remote. Python, SQL, R experience valued.",
        "salary_min": 60000,
        "salary_max": 85000,
        "seniority": "senior",
        "required_skills": ["python", "machine learning", "sql"],
        "preferred_skills": ["scikit-learn", "numpy", "r"],
    },
    {
        "title": "Python Backend Engineer",
        "company": "CloudSync Systems",
        "description": "Backend engineer needed. Python, FastAPI, PostgreSQL, APIs. 2-3 years experience. Remote position. Work on data pipelines, automation.",
        "salary_min": 45000,
        "salary_max": 65000,
        "seniority": "mid",
        "required_skills": ["python", "fastapi", "postgresql"],
        "preferred_skills": ["sql", "docker", "api"],
    },
    {
        "title": "Dashboard Developer (React + Python)",
        "company": "VisualInsights Co",
        "description": "Build interactive dashboards with React, Python backends. 3+ years UI/data viz. Plotly, Streamlit, Tableau experience. Remote-friendly.",
        "salary_min": 50000,
        "salary_max": 72000,
        "seniority": "mid",
        "required_skills": ["react", "python", "visualization"],
        "preferred_skills": ["plotly", "streamlit", "power bi"],
    },
    {
        "title": "ETL Specialist (Python, SQL)",
        "company": "DataPipeline Corp",
        "description": "Design ETL pipelines in Python, SQL, PostgreSQL. 4+ years. Remote. Work with Pandas, data transformation, automation scripts.",
        "salary_min": 52000,
        "salary_max": 70000,
        "seniority": "senior",
        "required_skills": ["python", "sql", "etl"],
        "preferred_skills": ["pandas", "postgresql", "automation"],
    },
]


def generate_test_jobs() -> list[NormalizedJob]:
    """Generate test jobs for pipeline"""
    jobs = []
    base_date = datetime.now() - timedelta(days=5)

    for i, job_data in enumerate(REALISTIC_JOBS):
        posted_at = base_date + timedelta(days=i % 5)
        expires_at = posted_at + timedelta(days=30)

        job = NormalizedJob(
            source="test_data",
            source_id=f"test_{i}",
            source_url=f"https://example.com/jobs/{i}",
            title=job_data["title"],
            company=job_data["company"],
            company_url=f"https://{job_data['company'].lower().replace(' ', '')}.com",
            description=job_data["description"],
            description_clean=job_data["description"][:500],
            job_type="full_time",
            seniority=job_data["seniority"],
            remote_type="fully_remote",
            location_required=None,
            salary_min=job_data["salary_min"],
            salary_max=job_data["salary_max"],
            salary_currency="USD",
            salary_period="yearly",
            required_skills=job_data.get("required_skills", []),
            preferred_skills=job_data.get("preferred_skills", []),
            experience_years_min=3 if job_data["seniority"] == "senior" else 1,
            experience_years_max=10 if job_data["seniority"] == "senior" else 5,
            posted_at=posted_at,
            expires_at=expires_at,
        )

        jobs.append(job)

    return jobs


if __name__ == "__main__":
    jobs = generate_test_jobs()
    print(f"Generated {len(jobs)} test jobs:")
    for job in jobs:
        print(f"  • {job.title} @ {job.company}")
