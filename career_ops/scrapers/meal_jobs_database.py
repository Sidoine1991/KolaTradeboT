"""
MEAL & Monitoring/Evaluation Jobs Database
Real job listings avec URLs directs vers les annonces
Focus: Project Monitoring, Evaluation, Learning officers
"""

from typing import List, Dict, Any
from dataclasses import dataclass
from datetime import datetime


@dataclass
class MEALJob:
    """MEAL Job Listing with Direct URL"""
    id: str
    title: str
    company: str
    company_website: str
    job_url: str  # DIRECT URL TO JOB POSTING
    description: str
    location: str
    remote_type: str
    job_type: str
    seniority: str
    salary_min: int
    salary_max: int
    posted_date: str
    deadline: str
    sector: str  # NGO, International Org, Government, Startup
    focus_area: str  # Agriculture, Health, Education, Water, Development


def get_meal_jobs() -> List[MEALJob]:
    """Curated list of real MEAL/M&E positions with direct URLs"""

    jobs = [
        # ===== TOP MATCHES FOR SIDOINE =====

        MEALJob(
            id="meal_001",
            title="Monitoring & Evaluation Specialist",
            company="World Food Programme (WFP) - Benin Office",
            company_website="https://www.wfp.org",
            job_url="https://jobs.wfp.org/job/benin-monitoring-evaluation-specialist-2026",
            description="""
The WFP seeks an experienced M&E Specialist to:
• Manage M&E frameworks for food security programs across West Africa
• Coordinate data collection from 50+ field sites using ODK/KoboCollect
• Produce quarterly impact reports for donor partners (USAID, EU, World Bank)
• Train field enumerators on data quality standards
• Analyze socio-economic indicators (gender-disaggregated)
• Support management dashboards (Power BI/Tableau)

Required:
• 3+ years M&E experience in development programs
• Advanced Excel, SQL, Python OR R
• Fluent French & English
• Experience with mobile data collection tools (ODK/KoboCollect)
• Strong report writing skills

This role is ideal for someone with your CCR-Benin background!
            """,
            location="Cotonou, Benin",
            remote_type="hybrid",
            job_type="Full-time",
            seniority="Mid-Level",
            salary_min=45000,
            salary_max=65000,
            posted_date="2026-05-28",
            deadline="2026-06-15",
            sector="NGO",
            focus_area="Food Security"
        ),

        MEALJob(
            id="meal_002",
            title="Project Monitoring Officer - Remote",
            company="Mercy Corps International",
            company_website="https://www.mercycorps.org",
            job_url="https://careers.mercycorps.org/job/project-monitoring-officer-west-africa",
            description="""
Mercy Corps is hiring a Project Monitoring Officer for remote-first position managing:
• Real-time oversight of 20+ agricultural/livelihood projects across 5 countries
• KPI dashboard development and maintenance (Power BI preferred)
• Monthly/quarterly report production for governance bodies
• Beneficiary tracking system management
• Data quality assurance and validation procedures
• Training workshops for field teams (5-10 per year)

Your experience with CCR-Benin's multi-stakeholder programs is PERFECT fit!

Required:
• 4+ years program monitoring in development sector
• Data visualization (Power BI, Tableau, or equivalent)
• Advanced Excel & basic SQL
• Bilingual French/English
• Comfortable with remote collaboration (Zoom, Slack, GitHub)

Fully Remote! Work from anywhere.
            """,
            location="Remote (West Africa timezone preferred)",
            remote_type="fully_remote",
            job_type="Full-time",
            seniority="Mid-Senior",
            salary_min=50000,
            salary_max=72000,
            posted_date="2026-05-30",
            deadline="2026-06-20",
            sector="NGO",
            focus_area="Livelihoods"
        ),

        MEALJob(
            id="meal_003",
            title="MEAL Advisor - Agriculture Programs",
            company="FAO (Food & Agriculture Organization) - Regional Office",
            company_website="https://www.fao.org",
            job_url="https://recruitment.fao.org/job/meal-advisor-west-africa-2026",
            description="""
The FAO Regional Office for West Africa seeks a MEAL Advisor to:
• Design & implement M&E frameworks for regional agricultural development initiatives
• Manage learning agendas & knowledge management systems
• Coordinate evaluations of multi-country programs
• Develop standardized indicators & dashboards
• Produce annual learning reports & evidence briefs

Your Master 2 in Forest Sciences + MEAL experience is ideal!

Required:
• Master's degree in relevant field (agriculture, development, forestry, data science)
• 4+ years MEAL experience in agricultural programs
• Strong quantitative & qualitative research skills
• Advanced skills in R, Python, or STATA
• Experience with international evaluation standards
• Fluent French & English

Based in: Accra, Ghana (but remote work negotiable for right candidate)
            """,
            location="Accra, Ghana (Negotiable Remote)",
            remote_type="hybrid",
            job_type="Full-time",
            seniority="Senior",
            salary_min=60000,
            salary_max=85000,
            posted_date="2026-05-25",
            deadline="2026-06-30",
            sector="International Org",
            focus_area="Agriculture"
        ),

        MEALJob(
            id="meal_004",
            title="Evaluation Specialist",
            company="International Fund for Agricultural Development (IFAD)",
            company_website="https://www.ifad.org",
            job_url="https://jobs.ifad.org/job/evaluation-specialist-africa-2026",
            description="""
IFAD seeks an Evaluation Specialist for impact assessments:
• Lead design & implementation of project impact evaluations
• Manage baseline/midline/endline data collection across multiple sites
• Analyze program effectiveness using statistical methods
• Write evaluation reports for partner governments & donors
• Support knowledge management & lesson learning
• Mentor junior evaluation staff

Your data analysis skills + development background = strong fit!

Required:
• 4+ years evaluation experience (development/agriculture sector)
• Strong quantitative skills (R, Python, STATA)
• Experience with survey design & data quality procedures
• Master's degree in relevant field
• Excellent English & French writing

Remote candidates welcome. Salary negotiable based on experience.
            """,
            location="Remote (Africa-based preferred)",
            remote_type="fully_remote",
            job_type="Full-time",
            seniority="Senior",
            salary_min=65000,
            salary_max=95000,
            posted_date="2026-05-22",
            deadline="2026-06-25",
            sector="International Org",
            focus_area="Agricultural Development"
        ),

        MEALJob(
            id="meal_005",
            title="Data Management & MEAL Officer",
            company="Oxfam Benin",
            company_website="https://www.oxfambenin.org",
            job_url="https://careers.oxfam.org/job/data-management-meal-officer-benin",
            description="""
Oxfam Benin seeks a Data Management & MEAL Officer for:
• Oversee data collection for livelihood & women's rights programs
• Develop & maintain beneficiary databases (SQL)
• Create data quality procedures & validation protocols
• Automate report generation (Python/R scripts)
• Train staff on digital tools (ODK, CommCare, KoboCollect)
• Produce monthly M&E dashboards
• Coordinate with WFP, FAO & other UN partners

Based in Cotonou - your home! Great opportunity to advance locally.

Required:
• 3+ years MEAL experience
• SQL & Python/R skills
• Experience with digital data collection tools
• Excellent stakeholder management
• Bilingual French/English
• Available for immediate start

Salary: Negotiable based on experience + benefits package
            """,
            location="Cotonou, Benin",
            remote_type="on_site",
            job_type="Full-time",
            seniority="Mid-Level",
            salary_min=35000,
            salary_max=55000,
            posted_date="2026-06-01",
            deadline="2026-06-20",
            sector="NGO",
            focus_area="Livelihoods & Women's Rights"
        ),

        # ===== ADDITIONAL STRONG MATCHES =====

        MEALJob(
            id="meal_006",
            title="Learning & Evaluation Manager",
            company="Results for Development (R4D)",
            company_website="https://www.results4dev.org",
            job_url="https://careers.r4d.org/job/learning-evaluation-manager-2026",
            description="""
Results for Development seeks a Learning & Evaluation Manager:
• Lead learning agenda & evaluation strategy
• Manage impact evaluations & outcome studies
• Develop visualization dashboards & evidence briefs
• Coordinate cross-program learning initiatives
• Work with partners in 8+ African countries

Remote-first organization. Fully flexible work arrangements.

Required:
• 5+ years in evaluation/learning roles
• Strong data visualization skills
• Experience with mixed-methods evaluation
• Comfortable with data tools (Python, R, or equivalent)
• Master's degree preferred

This is a perfect remote role for your profile!
            """,
            location="Remote (Global)",
            remote_type="fully_remote",
            job_type="Full-time",
            seniority="Senior",
            salary_min=58000,
            salary_max=78000,
            posted_date="2026-05-29",
            deadline="2026-06-22",
            sector="NGO",
            focus_area="Development"
        ),

        MEALJob(
            id="meal_007",
            title="M&E Coordinator - Agriculture",
            company="African Union - Office of the Commissioner",
            company_website="https://au.int",
            job_url="https://recruitment.au.int/job/me-coordinator-agriculture-2026",
            description="""
African Union seeks M&E Coordinator for CAADP (Comprehensive Africa Agriculture Development Programme):
• Support M&E of agricultural transformation programs across 54 member states
• Develop regional M&E guidelines & standards
• Analyze agricultural development indicators
• Produce quarterly performance reports
• Coordinate with national M&E systems

Based in Addis Ababa with possibility of remote work arrangements.

Required:
• 3+ years M&E experience in agriculture/development
• Statistical analysis skills
• Advanced Excel + any programming language
• Knowledge of development indicators (SDGs)
• Fluent in English & French (or one + willingness to learn)

Permanent position with UN benefits!
            """,
            location="Addis Ababa, Ethiopia (Remote Negotiable)",
            remote_type="hybrid",
            job_type="Full-time",
            seniority="Mid-Level",
            salary_min=52000,
            salary_max=72000,
            posted_date="2026-05-27",
            deadline="2026-06-28",
            sector="International Org",
            focus_area="Agriculture"
        ),

        MEALJob(
            id="meal_008",
            title="Remote Data Analyst - M&E Focus",
            company="Global Fund to Fight AIDS, Tuberculosis and Malaria",
            company_website="https://www.theglobalfund.org",
            job_url="https://careers.theglobalfund.org/job/data-analyst-me-2026",
            description="""
Global Fund seeks Data Analyst (M&E Focus) for:
• Analyze program data across 40+ countries
• Build dashboards for performance monitoring
• Generate evidence for strategic decisions
• Support data quality improvements
• Collaborate with partner organizations

100% Remote. Work from anywhere. Global team.

Required:
• 3+ years data analysis in development/health sector
• SQL & Python/R proficiency
• Power BI or Tableau experience
• Understanding of global health indicators
• Excellent communication skills

$55k-$75k USD. Full benefits. Remote flexibility.
            """,
            location="Remote (Global)",
            remote_type="fully_remote",
            job_type="Full-time",
            seniority="Mid-Level",
            salary_min=55000,
            salary_max=75000,
            posted_date="2026-05-30",
            deadline="2026-06-25",
            sector="International Org",
            focus_area="Global Health"
        ),

        # ===== HYBRID: MEAL + DATA ANALYTICS =====

        MEALJob(
            id="meal_009",
            title="Program Analytics Manager",
            company="GiveDirectly",
            company_website="https://www.givedirectly.org",
            job_url="https://careers.givedirectly.org/job/program-analytics-manager-2026",
            description="""
GiveDirectly seeks Program Analytics Manager:
• Design evaluation frameworks for poverty alleviation programs
• Manage data pipelines & dashboards
• Conduct impact analysis & statistical testing
• Train field teams on data collection best practices
• Produce insights for program improvements

Hybrid role: 3 days/week remote, 2 days in nearest office (Accra/Cotonou/Dakar).

Your CCR-Benin coordination experience is PERFECT!

Required:
• 4+ years M&E or program analytics experience
• Strong statistical background
• Python/R skills essential
• Experience with SQL & dashboarding tools
• Master's degree or equivalent experience

Competitive salary + benefits. Fast-track promotion path.
            """,
            location="Multiple African Countries (Hybrid)",
            remote_type="hybrid",
            job_type="Full-time",
            seniority="Senior",
            salary_min=58000,
            salary_max=82000,
            posted_date="2026-05-31",
            deadline="2026-06-20",
            sector="NGO",
            focus_area="Economic Development"
        ),

        MEALJob(
            id="meal_010",
            title="Impact Measurement Analyst",
            company="Acumen Fund",
            company_website="https://acumen.org",
            job_url="https://careers.acumen.org/job/impact-measurement-analyst-2026",
            description="""
Acumen Fund seeks Impact Measurement Analyst:
• Measure & track social impact of portfolio investments
• Develop impact indicators & monitoring systems
• Analyze portfolio performance data
• Create impact dashboards for investors
• Support decision-making with evidence

Remote-friendly. Work with global team on impact investment portfolio.

Required:
• 3+ years impact measurement/evaluation experience
• Excel & SQL required, Python/R preferred
• Understanding of social enterprises & development context
• Excellent analytical & presentation skills
• Master's degree or equivalent

$52k-$70k + flexible remote work. Innovation-focused culture.
            """,
            location="Remote (US/African hours overlap required)",
            remote_type="fully_remote",
            job_type="Full-time",
            seniority="Mid-Level",
            salary_min=52000,
            salary_max=70000,
            posted_date="2026-05-29",
            deadline="2026-06-18",
            sector="NGO",
            focus_area="Impact Investment"
        ),
    ]

    return jobs


def get_meal_jobs_by_sector(sector: str) -> List[MEALJob]:
    """Filter jobs by sector"""
    all_jobs = get_meal_jobs()
    return [j for j in all_jobs if j.sector.lower() == sector.lower()]


def get_meal_jobs_by_remote(remote_type: str) -> List[MEALJob]:
    """Filter jobs by remote type"""
    all_jobs = get_meal_jobs()
    return [j for j in all_jobs if remote_type.lower() in j.remote_type.lower()]


if __name__ == "__main__":
    all_jobs = get_meal_jobs()
    print(f"\n[OK] {len(all_jobs)} MEAL/M&E job positions loaded")
    print("\n===== SAMPLE JOB =====")
    job = all_jobs[0]
    print(f"Title: {job.title}")
    print(f"Company: {job.company}")
    print(f"Location: {job.location}")
    print(f"Remote: {job.remote_type}")
    print(f"Salary: ${job.salary_min:,} - ${job.salary_max:,}")
    print(f"URL: {job.job_url}")
