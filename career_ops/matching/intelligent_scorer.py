"""
Intelligent Job Scorer with Claude via NVIDIA NIM
Combines algorithmic scoring (8-factor) + Claude contextual analysis
"""

import asyncio
from typing import Optional

from ..parsing.cv_parser import ParsedProfile
from ..ai.claude_nim_client import ClaudeNIMClient
from .scorer import JobScorer, grade_score


class IntelligentJobScorer:
    """
    Hybrid scorer: 8-factor algorithm + Claude reasoning
    Uses Claude for:
      - Job description context analysis
      - Red flag detection
      - Growth opportunity assessment
      - Detailed reasoning
    """

    def __init__(self):
        self.algorithm_scorer = JobScorer()
        self.claude_client = ClaudeNIMClient()

    async def score_with_reasoning(self, profile: ParsedProfile, job_dict: dict) -> dict:
        """
        Score job with both algorithm and Claude reasoning
        Returns: score, grade, claude_analysis, recommendation
        """

        # 1. Run algorithm scoring (fast)
        algo_score = self.algorithm_scorer.score(profile, job_dict)

        # 2. Run Claude analysis (slower but deeper)
        try:
            claude_analysis = await self.claude_client.analyze_job_description(
                job_dict.get("title", "Job"),
                job_dict.get("description", "No description provided"),
            )
        except Exception as e:
            print(f"[WARNING] Claude analysis failed: {str(e)[:50]}")
            claude_analysis = {}

        # 3. Combine results
        grade = grade_score(algo_score.score_total)

        # 4. Generate recommendation based on both scores
        recommendation = self._generate_recommendation(
            algo_score.score_total,
            claude_analysis,
            profile,
            job_dict,
        )

        return {
            "job_id": job_dict.get("fingerprint"),
            "title": job_dict.get("title"),
            "company": job_dict.get("company"),

            # Algorithm score
            "algorithm_score": round(algo_score.score_total, 3),
            "algorithm_components": {
                "skills_primary": round(algo_score.score_skills_primary, 3),
                "skills_secondary": round(algo_score.score_skills_secondary, 3),
                "experience": round(algo_score.score_experience, 3),
                "remote_fit": round(algo_score.score_remote_fit, 3),
                "seniority": round(algo_score.score_seniority_fit, 3),
                "salary": round(algo_score.score_salary_fit, 3),
                "semantic": round(algo_score.score_semantic, 3),
                "recency": round(algo_score.score_recency, 3),
            },
            "grade": grade,

            # Claude analysis
            "claude_analysis": claude_analysis,
            "extracted_skills": claude_analysis.get("extracted_skills", []),
            "red_flags": claude_analysis.get("red_flags", []),
            "opportunities": claude_analysis.get("opportunities", []),

            # Recommendation
            "recommendation": recommendation,
            "should_apply": recommendation in ["strong_match", "good_match"],
        }

    async def generate_personalized_message(self, profile_name: str, job_title: str, company: str, matched_skills: list) -> str:
        """
        Generate personalized message for this opportunity
        """
        try:
            message = await self.claude_client.generate_personalized_message(
                job_title,
                company,
                matched_skills,
            )
            return message
        except:
            # Fallback message
            return f"Interested in {job_title} at {company}. My skills: {', '.join(matched_skills)}"

    @staticmethod
    def _generate_recommendation(algo_score: float, claude_analysis: dict, profile: ParsedProfile, job_dict: dict) -> str:
        """
        Generate recommendation combining both scores
        """

        if algo_score >= 0.75 and not claude_analysis.get("red_flags"):
            return "strong_match"
        elif algo_score >= 0.65 and len(claude_analysis.get("red_flags", [])) <= 1:
            return "good_match"
        elif algo_score >= 0.55 and claude_analysis.get("opportunities"):
            return "consider"
        else:
            return "skip"


async def score_job_intelligently(profile: ParsedProfile, job_dict: dict) -> dict:
    """Convenience function"""
    scorer = IntelligentJobScorer()
    return await scorer.score_with_reasoning(profile, job_dict)


if __name__ == "__main__":

    async def test():
        from ..parsing.cv_parser import extract_sidoine_profile
        from ..scrapers.test_data import generate_test_jobs

        profile = extract_sidoine_profile()
        test_job = generate_test_jobs()[0]

        scorer = IntelligentJobScorer()
        result = await scorer.score_with_reasoning(profile, test_job.to_dict())

        print(f"Title: {result['title']}")
        print(f"Algorithm Score: {result['algorithm_score']}")
        print(f"Grade: {result['grade']}")
        print(f"Claude Analysis: {result['claude_analysis']}")
        print(f"Recommendation: {result['recommendation']}")

    asyncio.run(test())
