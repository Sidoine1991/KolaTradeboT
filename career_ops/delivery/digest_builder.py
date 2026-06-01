"""
WhatsApp Digest Formatter
Builds daily job digest message for WhatsApp delivery
"""

from typing import List, Dict
from datetime import datetime


class DigestBuilder:
    """Format job matches into WhatsApp digest"""

    @staticmethod
    def grade_emoji(score: float) -> str:
        """Get emoji for score grade"""
        if score >= 0.75:
            return "✨"  # EXCELLENT
        elif score >= 0.55:
            return "👍"  # GOOD
        else:
            return "❓"  # MARGINAL

    @staticmethod
    def build_digest(profile_name: str, matches: List[Dict]) -> str:
        """Build WhatsApp digest message"""

        if not matches:
            return f"No matches found for {profile_name} today."

        excellent = [m for m in matches if m['score'] >= 0.75]
        good = [m for m in matches if 0.55 <= m['score'] < 0.75]

        lines = []

        # Header
        date_str = datetime.now().strftime("%A, %B %d, %Y")
        lines.append(f"*Career-Ops Daily Digest*")
        lines.append(f"_{date_str}_")
        lines.append("")
        lines.append(f"Hi {profile_name.split()[0]}! Here are today's job matches:")
        lines.append("")

        # EXCELLENT section
        if excellent:
            lines.append("*✨ EXCELLENT MATCHES (Score >= 0.75)*")
            for i, match in enumerate(excellent[:5], 1):
                lines.append(f"\n{i}. *{match['title']}*")
                lines.append(f"   Company: {match['company']}")
                lines.append(f"   Score: {match['score']:.0%}")
                if match.get('salary_min') and match.get('salary_max'):
                    lines.append(f"   Salary: ${match['salary_min']}k - ${match['salary_max']}k")
                if match.get('source_url'):
                    lines.append(f"   Link: {match['source_url'][:50]}...")
            lines.append("")

        # GOOD section
        if good:
            lines.append("*👍 GOOD MATCHES (Score 0.55-0.74)*")
            for i, match in enumerate(good[:5], 1):
                lines.append(f"\n{i}. *{match['title']}*")
                lines.append(f"   Company: {match['company']}")
                lines.append(f"   Score: {match['score']:.0%}")
            lines.append("")

        # Summary
        lines.append("*Summary*")
        lines.append(f"• Excellent: {len(excellent)} matches")
        lines.append(f"• Good: {len(good)} matches")
        lines.append("")
        lines.append("Reply /jobs to see all matches or /apply [number] to apply!")

        return "\n".join(lines)

    @staticmethod
    def build_full_digest(profile_name: str, matches: List[Dict]) -> Dict:
        """Build full digest with text and metadata"""

        text = DigestBuilder.build_digest(profile_name, matches)

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


def format_match_for_whatsapp(match: Dict) -> str:
    """Format single match for WhatsApp"""

    score = match.get('score', 0)
    grade = "✨" if score >= 0.75 else "👍" if score >= 0.55 else "❓"

    lines = [
        f"{grade} *{match['title']}*",
        f"_{match['company']}_",
        f"Score: {score:.0%}",
    ]

    if match.get('salary_min'):
        lines.append(f"${match['salary_min']}k - ${match.get('salary_max', match['salary_min'])}k")

    if match.get('source_url'):
        lines.append(f"[Link]({match['source_url']})")

    return "\n".join(lines)
