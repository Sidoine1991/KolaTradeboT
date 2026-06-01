"""
8-Factor Intelligent Job Matching Algorithm
Scores profile-to-job fit from 0.0 to 1.0
"""

from dataclasses import dataclass
from typing import Optional

from ..parsing.cv_parser import ParsedProfile


@dataclass
class MatchScore:
    """Detailed score breakdown"""

    profile_id: str
    job_id: str

    score_skills_primary: float = 0.0
    score_skills_secondary: float = 0.0
    score_experience: float = 0.0
    score_remote_fit: float = 0.0
    score_seniority_fit: float = 0.0
    score_salary_fit: float = 0.0
    score_semantic: float = 0.0
    score_recency: float = 0.0

    score_total: float = 0.0

    # Weights (must sum to 1.0)
    WEIGHTS = {
        "skills_primary": 0.30,
        "skills_secondary": 0.15,
        "experience": 0.15,
        "remote_fit": 0.15,
        "seniority_fit": 0.08,
        "salary_fit": 0.05,
        "semantic": 0.10,
        "recency": 0.02,
    }

    def compute_total(self):
        """Compute weighted total score"""
        self.score_total = (
            self.score_skills_primary * self.WEIGHTS["skills_primary"]
            + self.score_skills_secondary * self.WEIGHTS["skills_secondary"]
            + self.score_experience * self.WEIGHTS["experience"]
            + self.score_remote_fit * self.WEIGHTS["remote_fit"]
            + self.score_seniority_fit * self.WEIGHTS["seniority_fit"]
            + self.score_salary_fit * self.WEIGHTS["salary_fit"]
            + self.score_semantic * self.WEIGHTS["semantic"]
            + self.score_recency * self.WEIGHTS["recency"]
        )
        return self.score_total

    def to_dict(self):
        """Convert to DB-ready dict"""
        return {
            "profile_id": self.profile_id,
            "job_id": self.job_id,
            "score_skills_primary": round(self.score_skills_primary, 3),
            "score_skills_secondary": round(self.score_skills_secondary, 3),
            "score_experience": round(self.score_experience, 3),
            "score_remote_fit": round(self.score_remote_fit, 3),
            "score_seniority_fit": round(self.score_seniority_fit, 3),
            "score_salary_fit": round(self.score_salary_fit, 3),
            "score_semantic": round(self.score_semantic, 3),
            "score_recency": round(self.score_recency, 3),
            "score_total": round(self.score_total, 3),
            "status": "new",
        }


class JobScorer:
    """Score profile-to-job matches using 8-factor algorithm"""

    @staticmethod
    def _score_skills_primary(profile: ParsedProfile, job_required: list[str]) -> float:
        """Match primary skills (Python, SQL, R, Power BI, Tableau)"""
        if not job_required:
            return 0.5  # Neutral

        profile_skills_lower = [s.lower() for s in profile.skills_primary]
        job_required_lower = [s.lower() for s in job_required]

        matches = len([s for s in job_required_lower if s in profile_skills_lower])
        return min(1.0, matches / max(len(job_required_lower), 1))

    @staticmethod
    def _score_skills_secondary(profile: ParsedProfile, job_preferred: list[str]) -> float:
        """Match secondary skills (Pandas, Plotly, React, etc.)"""
        if not job_preferred:
            return 0.5

        profile_skills_lower = [s.lower() for s in profile.skills_secondary]
        job_preferred_lower = [s.lower() for s in job_preferred]

        matches = len([s for s in job_preferred_lower if s in profile_skills_lower])
        return min(1.0, matches / max(len(job_preferred_lower), 1))

    @staticmethod
    def _score_experience(profile: ParsedProfile, job_exp_min: Optional[int]) -> float:
        """Match experience level (years)"""
        if not job_exp_min:
            return 0.7

        # Profile: 4.5 years
        # Job wants: 1-5 years → full match
        # Job wants: 7+ years → penalty
        # Job wants: <1 year → over-qualified bonus

        if profile.years_experience >= job_exp_min:
            return 1.0
        else:
            # Deficit penalty
            deficit = job_exp_min - profile.years_experience
            return max(0.3, 1.0 - (deficit * 0.1))

    @staticmethod
    def _score_remote_fit(profile: ParsedProfile, job_remote_type: str) -> float:
        """Match remote preference"""
        if profile.remote_preference == "remote_only":
            if job_remote_type == "fully_remote":
                return 1.0
            elif job_remote_type == "hybrid":
                return 0.7
            else:
                return 0.0
        return 0.8

    @staticmethod
    def _score_seniority_fit(profile: ParsedProfile, job_seniority: str) -> float:
        """Match seniority level"""
        # Profile: 4.5 years → "mid" to "senior"
        years = profile.years_experience

        if job_seniority == "senior" and years >= 4:
            return 1.0
        elif job_seniority == "mid" and 2 <= years <= 6:
            return 1.0
        elif job_seniority == "junior" and years < 3:
            return 0.9
        else:
            return 0.6

    @staticmethod
    def _score_salary_fit(profile: ParsedProfile, job_min: Optional[int], job_max: Optional[int]) -> float:
        """Match salary expectations"""
        if not job_min and not job_max:
            return 0.7

        profile_min = profile.min_salary_usd or 40000

        # Job salary below profile minimum → penalty
        if job_max and job_max < profile_min:
            return 0.5

        # Job salary above profile minimum → good
        if job_min and job_min >= profile_min:
            return 1.0

        # Somewhere in between
        return 0.75

    @staticmethod
    def _score_semantic(description: str, profile_keywords: list[str]) -> float:
        """Simple keyword matching in job description"""
        if not description or not profile_keywords:
            return 0.5

        description_lower = description.lower()
        matches = sum(1 for kw in profile_keywords if kw.lower() in description_lower)

        return min(1.0, matches / max(len(profile_keywords), 1))

    @staticmethod
    def _score_recency(posted_timestamp: int, days_old: int = 30) -> float:
        """Prefer recently posted jobs"""
        # Job posted today → 1.0
        # Job posted 30 days ago → 0.0
        # Linear decay

        if days_old <= 0:
            return 1.0
        elif days_old >= days_old:
            return 0.0
        else:
            return max(0.0, 1.0 - (days_old / 30))

    @staticmethod
    def score(profile: ParsedProfile, job_dict: dict) -> MatchScore:
        """Score a profile-to-job match"""

        score = MatchScore(
            profile_id=profile.full_name,  # Using name as ID for now
            job_id=job_dict.get("fingerprint", "unknown"),
        )

        # 1. Primary skills (30%)
        score.score_skills_primary = JobScorer._score_skills_primary(
            profile, job_dict.get("required_skills", [])
        )

        # 2. Secondary skills (15%)
        score.score_skills_secondary = JobScorer._score_skills_secondary(
            profile, job_dict.get("preferred_skills", [])
        )

        # 3. Experience level (15%)
        score.score_experience = JobScorer._score_experience(
            profile, job_dict.get("experience_years_min")
        )

        # 4. Remote fit (15%)
        score.score_remote_fit = JobScorer._score_remote_fit(
            profile, job_dict.get("remote_type", "fully_remote")
        )

        # 5. Seniority fit (8%)
        score.score_seniority_fit = JobScorer._score_seniority_fit(profile, job_dict.get("seniority", "mid"))

        # 6. Salary fit (5%)
        score.score_salary_fit = JobScorer._score_salary_fit(
            profile,
            job_dict.get("salary_min"),
            job_dict.get("salary_max"),
        )

        # 7. Semantic match (10%)
        score.score_semantic = JobScorer._score_semantic(
            job_dict.get("description", ""),
            profile.experience_keywords,
        )

        # 8. Recency (2%) - simple implementation
        score.score_recency = 0.8  # Assume recent for now

        # Compute total
        score.compute_total()

        return score


def grade_score(score: float) -> str:
    """Convert numeric score to grade"""
    if score >= 0.75:
        return "EXCELLENT"
    elif score >= 0.55:
        return "GOOD"
    elif score >= 0.40:
        return "MARGINAL"
    else:
        return "POOR"
