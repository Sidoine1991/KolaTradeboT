"""
Dual CV Parser: Data Analyst + MEAL Specialist
Extraction de compétences depuis les deux CVs de Sidoine
"""

import sys
from pathlib import Path
from typing import List, Dict, Any

_root = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_root))


class DualProfile:
    """Profil combiné: Data Analyst + MEAL Specialist"""

    def __init__(self):
        self.full_name = "Sidoine Kolaolé YEBADOKPO"
        self.location = "Cotonou, Benin"
        self.years_experience = 4.5
        self.languages = ["French", "English"]
        self.min_salary_usd = 40000
        self.remote_preference = "remote_only"

        # ===== PROFIL 1: DATA ANALYST =====
        self.skills_data_analyst = {
            "primary": ["Python", "SQL", "R", "Data Analysis", "Excel"],
            "secondary": ["Power BI", "Tableau", "Machine Learning", "Statistics", "Data Visualization"],
            "tools": ["GitHub", "Jupyter", "scikit-learn", "pandas", "NumPy"]
        }

        # ===== PROFIL 2: MEAL SPECIALIST =====
        self.skills_meal = {
            "primary": [
                "Project Monitoring",
                "Evaluation & Learning",
                "M&E Frameworks",
                "Program Management",
                "Data Quality Control"
            ],
            "secondary": [
                "KPI Dashboards",
                "Report Generation",
                "Beneficiary Tracking",
                "Gender Analysis",
                "Impact Assessment"
            ],
            "tools": [
                "ODK",
                "KoboCollect",
                "Survey Solutions",
                "CommCare",
                "Power BI",
                "Tableau",
                "Python",
                "R",
                "SQL"
            ]
        }

        # ===== COMBINED PROFILE =====
        self.skills_primary = list(set(
            self.skills_data_analyst["primary"] +
            self.skills_meal["primary"]
        ))

        self.skills_secondary = list(set(
            self.skills_data_analyst["secondary"] +
            self.skills_meal["secondary"]
        ))

        self.skills_tools = list(set(
            self.skills_data_analyst["tools"] +
            self.skills_meal["tools"]
        ))

        # Target roles: Both profiles
        self.target_roles = [
            "Data Analyst",
            "Data Scientist",
            "Full-Stack Python Developer",
            "Backend Developer",
            "M&E Specialist",
            "Project Monitoring Officer",
            "Evaluation Specialist",
            "Impact Assessment Specialist",
            "Program Manager",
            "Data Management Officer"
        ]

        # Experience highlights
        self.experience_highlights = {
            "data_analyst": [
                "4.5 years coordinating agricultural/socio-economic programs",
                "40% automation improvement in report production",
                "30% resource efficiency gain through data tools",
                "KPI dashboard management with Power BI & Tableau",
                "Data quality control procedures implementation"
            ],
            "meal_specialist": [
                "Global MEAL Advisor at CCR-Benin (4 years current role)",
                "Multi-stakeholder program coordination at national level",
                "Eligibility analysis & project validation",
                "Training field teams on digital data collection (ODK/KoboCollect)",
                "Gender-disaggregated socio-economic analysis"
            ]
        }

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for scoring"""
        return {
            "full_name": self.full_name,
            "location": self.location,
            "years_experience": self.years_experience,
            "languages": self.languages,
            "min_salary": self.min_salary_usd,
            "remote_preference": self.remote_preference,
            "skills_primary": self.skills_primary,
            "skills_secondary": self.skills_secondary,
            "skills_tools": self.skills_tools,
            "target_roles": self.target_roles,
        }

    def get_profile_summary(self) -> str:
        """Get formatted profile summary"""
        return f"""
DUAL PROFILE: Data Analyst + MEAL Specialist

Name: {self.full_name}
Location: {self.location}
Experience: {self.years_experience} years
Languages: {', '.join(self.languages)}
Remote: {self.remote_preference.replace('_', ' ').title()}
Min Salary: ${self.min_salary_usd:,}/year

========== DATA ANALYST PROFILE ==========
Primary Skills: {', '.join(self.skills_data_analyst['primary'][:3])}
Secondary Skills: {', '.join(self.skills_data_analyst['secondary'][:3])}
Tools: {', '.join(self.skills_data_analyst['tools'][:3])}

========== MEAL SPECIALIST PROFILE ==========
Primary Skills: {', '.join(self.skills_meal['primary'][:3])}
Secondary Skills: {', '.join(self.skills_meal['secondary'][:3])}
Tools: {', '.join(self.skills_meal['tools'][:3])}

========== TARGET ROLES ==========
{chr(10).join(f"• {role}" for role in self.target_roles)}
"""


def extract_dual_profile() -> DualProfile:
    """Extract combined profile from both CVs"""
    return DualProfile()


if __name__ == "__main__":
    profile = extract_dual_profile()
    print(profile.get_profile_summary())
    print("\n[OK] Dual profile loaded successfully")
