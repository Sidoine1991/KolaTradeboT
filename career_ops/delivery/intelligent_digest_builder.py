"""
Intelligent Digest Builder with Claude via NVIDIA NIM
Enhances digest with Claude-generated insights and personalization
"""

import asyncio
from datetime import datetime
from typing import List, Dict

from ..ai.claude_nim_client import ClaudeNIMClient
from .digest_builder import DigestBuilder


class IntelligentDigestBuilder:
    """
    Build digest with Claude enhancements:
    - Personalized intro message
    - Context-aware job summaries
    - Actionable next steps
    - Weekly insights (on Sundays)
    """

    def __init__(self):
        self.digest_builder = DigestBuilder()
        self.claude_client = ClaudeNIMClient()

    async def build_intelligent_digest(self, profile_name: str, matches: List[Dict]) -> str:
        """
        Build digest with Claude enhancements
        """

        if not matches:
            return f"No matches found for {profile_name} today."

        # 1. Build base digest
        base_digest = self.digest_builder.build_digest(profile_name, matches)

        # 2. Generate Claude insights
        try:
            insights = await self._generate_insights(profile_name, matches)
        except:
            insights = None

        # 3. Combine
        if insights:
            return f"{base_digest}\n\n✨ *Insights*\n{insights}"
        else:
            return base_digest

    async def build_full_intelligent_digest(self, profile_name: str, matches: List[Dict]) -> Dict:
        """
        Build full digest with all metadata
        """

        text = await self.build_intelligent_digest(profile_name, matches)

        excellent = [m for m in matches if m['score'] >= 0.75]
        good = [m for m in matches if 0.55 <= m['score'] < 0.75]

        return {
            "message": text,
            "summary": {
                "total_matches": len(matches),
                "excellent": len(excellent),
                "good": len(good),
                "sent_at": datetime.now().isoformat(),
            },
            "matches": [
                {
                    "title": m['title'],
                    "company": m['company'],
                    "score": round(m['score'], 3),
                    "url": m.get('source_url'),
                }
                for m in matches[:10]
            ],
        }

    async def _generate_insights(self, profile_name: str, matches: List[Dict]) -> str:
        """
        Use Claude to generate context-aware insights
        """

        # Prepare context
        excellent = [m for m in matches if m['score'] >= 0.75]
        good = [m for m in matches if 0.55 <= m['score'] < 0.75]

        prompt = f"""Generate 2-3 brief insights for {profile_name} about these job opportunities:

Excellent matches: {len(excellent)}
- {', '.join([m['company'] for m in excellent[:3]])}

Good matches: {len(good)}

Keep it:
- 2-3 sentences max
- Actionable
- Mobile-friendly (short lines)
- Professional but friendly

Format: Plain text, no JSON"""

        try:
            result = await self.claude_client._call_claude(prompt, json_response=False)
            return result if result else ""
        except:
            return ""

    async def generate_weekly_report(self, profile_name: str, week_data: Dict) -> str:
        """
        Generate weekly summary with Claude insights
        """

        prompt = f"""Generate a weekly job search summary for {profile_name}:

This week:
- Total jobs found: {week_data.get('total_jobs', 0)}
- Excellent matches: {week_data.get('excellent', 0)}
- Good matches: {week_data.get('good', 0)}
- Applications: {week_data.get('applications', 0)}
- Companies: {', '.join(week_data.get('top_companies', []))}

Format as WhatsApp-friendly message:
- 100-150 words
- Include: summary + trend + next steps
- Professional
- No JSON"""

        try:
            result = await self.claude_client._call_claude(prompt, json_response=False)
            return result
        except:
            return f"Weekly Summary: Found {week_data.get('total_jobs', 0)} jobs, {week_data.get('excellent', 0)} excellent matches."


async def build_intelligent_whatsapp_digest(profile_name: str, matches: List[Dict]) -> str:
    """Convenience function"""
    builder = IntelligentDigestBuilder()
    return await builder.build_intelligent_digest(profile_name, matches)


async def generate_weekly_summary(profile_name: str, week_data: Dict) -> str:
    """Convenience function"""
    builder = IntelligentDigestBuilder()
    return await builder.generate_weekly_report(profile_name, week_data)


if __name__ == "__main__":

    async def test():
        test_matches = [
            {
                "title": "Senior Python Dev",
                "company": "TechCorp",
                "score": 0.78,
                "salary_min": 50,
                "salary_max": 70,
                "source_url": "https://...",
            },
            {
                "title": "Data Analyst",
                "company": "StartupXYZ",
                "score": 0.65,
                "salary_min": 45,
                "salary_max": 60,
                "source_url": "https://...",
            },
        ]

        builder = IntelligentDigestBuilder()
        digest = await builder.build_intelligent_digest("Sidoine", test_matches)
        print(digest)

    asyncio.run(test())
