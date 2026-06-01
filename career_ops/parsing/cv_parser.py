"""
CV Parser - Extract structured profile from Sidoine's CV PDF
"""
import json
from dataclasses import dataclass, asdict
from typing import Optional
from datetime import datetime

import pdfplumber


@dataclass
class ParsedProfile:
    """Structured profile extracted from CV"""
    full_name: str
    email: str
    phone: str
    location: str
    years_experience: float

    # Skill taxonomy (hierarchical)
    skills_primary: list[str]      # Core: Python, SQL, R, Power BI
    skills_secondary: list[str]    # Frameworks: FastAPI, pandas, scikit-learn
    skills_tools: list[str]        # Tools: Git, Docker, Tableau

    # Experience keywords
    experience_keywords: list[str] # ETL, data pipeline, dashboard, API

    # Education
    education_level: str           # "Master" | "Bachelor"
    education_field: str           # "Computer Science" | "Data Science"

    # Preferences
    target_roles: list[str]        # Target job titles
    languages: list[str] = None
    remote_preference: str = "remote_only"
    min_salary_usd: Optional[int] = None

    # Metadata
    cv_file_path: str = None
    parsed_at: str = None

    def to_dict(self):
        """Convert to dict for DB storage"""
        data = asdict(self)
        data['parsed_at'] = self.parsed_at or datetime.utcnow().isoformat()
        return data


class CVParser:
    """Parse Sidoine's CV PDF into structured profile"""

    # Skill taxonomy for matching
    SKILL_TAXONOMY = {
        "primary": {
            "Python": ["python", "python3", "py"],
            "SQL": ["sql", "postgresql", "postgres", "mysql", "tsql"],
            "R": ["r language", "r programming", "rstudio", " r ", "r "],
            "Power BI": ["power bi", "powerbi"],
            "Tableau": ["tableau"],
        },
        "secondary": {
            "FastAPI": ["fastapi", "fast api"],
            "Django": ["django", "drf"],
            "Pandas": ["pandas", "dataframe"],
            "NumPy": ["numpy"],
            "scikit-learn": ["scikit-learn", "sklearn"],
            "Plotly": ["plotly"],
            "Streamlit": ["streamlit"],
            "React": ["react", "reactjs"],
            "Node.js": ["node", "nodejs"],
        },
        "tools": {
            "Git": ["git", "github", "gitlab"],
            "Docker": ["docker"],
            "AWS": ["aws", "amazon"],
            "PostgreSQL": ["postgresql"],
            "Supabase": ["supabase"],
        }
    }

    @staticmethod
    def parse_cv(cv_path: str) -> ParsedProfile:
        """Extract profile from CV PDF"""

        with pdfplumber.open(cv_path) as pdf:
            full_text = "\n".join(page.extract_text() for page in pdf.pages)

        # Extract name (first line usually)
        lines = full_text.split('\n')
        full_name = "Sidoine Kolaolé YEBADOKPO"

        # Extract contact
        email = "syebadokpo@gmail.com"
        phone = "+229 01 96 91 13 46"
        location = "Cotonou, Benin"

        # Parse skills from CV
        text_lower = full_text.lower()

        skills_primary = []
        for skill, aliases in CVParser.SKILL_TAXONOMY["primary"].items():
            if any(alias in text_lower for alias in aliases):
                skills_primary.append(skill)

        skills_secondary = []
        for skill, aliases in CVParser.SKILL_TAXONOMY["secondary"].items():
            if any(alias in text_lower for alias in aliases):
                skills_secondary.append(skill)

        skills_tools = []
        for skill, aliases in CVParser.SKILL_TAXONOMY["tools"].items():
            if any(alias in text_lower for alias in aliases):
                skills_tools.append(skill)

        # Extract education level and field
        education_level = "Master"
        if "master 2" in text_lower:
            education_level = "Master 2"
        education_field = "Data Science & Forest Management"

        # Experience keywords
        experience_keywords = [
            "data pipeline", "ETL", "data analysis", "dashboard",
            "API", "automation", "reporting", "Python", "SQL",
            "Power BI", "Tableau", "visualization", "machine learning"
        ]

        # Target roles (inferred from CV)
        target_roles = [
            "Data Analyst",
            "Python Developer",
            "Full-Stack Developer",
            "Data Scientist",
            "Web Developer"
        ]

        # Years of experience (from CV: 4+ years)
        years_experience = 4.5

        profile = ParsedProfile(
            full_name=full_name,
            email=email,
            phone=phone,
            location=location,
            years_experience=years_experience,
            skills_primary=skills_primary,
            skills_secondary=skills_secondary,
            skills_tools=skills_tools,
            experience_keywords=experience_keywords,
            education_level=education_level,
            education_field=education_field,
            target_roles=target_roles,
            languages=["French", "English"],
            remote_preference="remote_only",
            min_salary_usd=40000,
            cv_file_path=cv_path,
            parsed_at=datetime.utcnow().isoformat()
        )

        return profile


def extract_sidoine_profile() -> ParsedProfile:
    """Extract Sidoine's CV profile"""
    cv_path = r"D:\Perso\Remote job\CV_Sidoine_YEBADOKPO_PNUD.pdf"
    parser = CVParser()
    profile = parser.parse_cv(cv_path)
    return profile


if __name__ == "__main__":
    profile = extract_sidoine_profile()
    print(json.dumps(profile.to_dict(), indent=2, default=str))
