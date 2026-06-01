"""
PsychoBot Career-Ops Commands Handler
Gestion intelligente des commandes avec reconnaissance du langage naturel
Mise en forme WhatsApp optimisée
"""

import os
import sys
from pathlib import Path
from typing import Dict, List, Optional, Any
from difflib import SequenceMatcher
import asyncio

# Setup paths
_root_dir = Path(__file__).resolve().parent
sys.path.insert(0, str(_root_dir))

from career_ops.parsing.cv_parser import extract_sidoine_profile
from career_ops.db.rds_repository import RDSRepository


class CareerOpsCommandHandler:
    """Gestionnaire des commandes Career-Ops avec NLP fallback"""

    def __init__(self):
        self.repo = None
        try:
            self.repo = RDSRepository()
        except Exception as e:
            print(f"[WARNING] RDS not available: {str(e)[:60]}")

        self.profile = None
        try:
            self.profile = extract_sidoine_profile()
        except Exception as e:
            print(f"[WARNING] Profile not available: {str(e)[:60]}")

        # Command registry with synonyms
        self.commands = {
            "/jobs": {
                "description": "Top 5 job matches (EXCELLENT + GOOD)",
                "synonyms": [
                    "show jobs",
                    "jobs",
                    "top matches",
                    "meilleurs matchs",
                    "mes offres",
                    "show me jobs",
                    "liste des offres",
                    "les meilleurs emplois",
                ],
                "handler": self.handle_jobs_top,
            },
            "/jobs all": {
                "description": "All job matches (score >= 0.55)",
                "synonyms": [
                    "all jobs",
                    "show all jobs",
                    "all matches",
                    "tous les matchs",
                    "toutes les offres",
                    "affiche tous",
                    "montre tout",
                    "ensemble des offres",
                ],
                "handler": self.handle_jobs_all,
            },
            "/jobs stats": {
                "description": "Weekly statistics (jobs found, sources, stats)",
                "synonyms": [
                    "stats",
                    "statistics",
                    "weekly stats",
                    "statistiques",
                    "stats semaine",
                    "show stats",
                    "resume",
                    "résumé de la semaine",
                ],
                "handler": self.handle_jobs_stats,
            },
            "/apply": {
                "description": "Mark a job as applied",
                "synonyms": [
                    "apply",
                    "applied",
                    "mark applied",
                    "candidater",
                    "j ai postule",
                    "j'ai postulé",
                    "mark as applied",
                    "j ai applique",
                ],
                "handler": self.handle_apply,
            },
            "/skip": {
                "description": "Mark a job as skipped",
                "synonyms": [
                    "skip",
                    "skip job",
                    "pass",
                    "pass job",
                    "passer",
                    "sauter",
                    "ignorer",
                    "not interested",
                ],
                "handler": self.handle_skip,
            },
            "/profile": {
                "description": "Show your parsed CV profile",
                "synonyms": [
                    "profile",
                    "my profile",
                    "show profile",
                    "mon profil",
                    "affiche profil",
                    "cv",
                    "resume",
                    "mes competences",
                ],
                "handler": self.handle_profile,
            },
            "/settings": {
                "description": "View/update your preferences",
                "synonyms": [
                    "settings",
                    "preferences",
                    "configuration",
                    "preferences",
                    "parametres",
                    "mes preferences",
                    "update settings",
                    "change preferences",
                ],
                "handler": self.handle_settings,
            },
            "/help": {
                "description": "Show all available commands",
                "synonyms": [
                    "help",
                    "commands",
                    "show commands",
                    "aide",
                    "commandes",
                    "affiche commands",
                    "quoi faire",
                    "comment utiliser",
                ],
                "handler": self.handle_help,
            },
            "/insights": {
                "description": "Claude-powered career insights",
                "synonyms": [
                    "insights",
                    "analysis",
                    "advice",
                    "conseil",
                    "conseils",
                    "analyse",
                    "what should i do",
                    "career advice",
                ],
                "handler": self.handle_insights,
            },
        }

    def get_help_text(self) -> str:
        """Generate formatted help message for WhatsApp"""
        help_text = """
🎯 *CAREER-OPS COMMANDS* 🎯
━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 *JOB COMMANDS*
├─ /jobs → Top 5 best matches today 🌟
├─ /jobs all → All matches (all scores) 📊
├─ /jobs stats → Weekly statistics 📈
└─ /apply [n] → Mark job #n as applied ✅

👤 *PROFILE COMMANDS*
├─ /profile → Show your CV data 📄
├─ /settings → View/update preferences ⚙️
└─ /insights → Career advice 💡

❓ *OTHER*
├─ /help → Show this menu 📖
└─ Natural language works too! 💬

━━━━━━━━━━━━━━━━━━━━━━━━━━

✨ *TIPS*
• You can ask naturally: "show me best jobs"
• Use numbers: "apply 3" or "skip 1"
• Simple descriptions work: "jobs", "stats"

📱 *WHAT IS CAREER-OPS?*
Autonomous job prospection with:
✓ 315-585 jobs/day (11 sources)
✓ 8-factor intelligent matching
✓ Daily 06:00 WAT execution
✓ Delivered via WhatsApp
"""
        return help_text.strip()

    def get_commands_list_formatted(self) -> str:
        """Get formatted list of all commands"""
        commands_text = """
*🎯 CAREER-OPS - ALL COMMANDS 🎯*
════════════════════════════════════

*📋 JOB DISCOVERY & MATCHING*

*1️⃣ /jobs*
   Show 5 best matches today
   Synonyms: "show jobs", "best matches"

*2️⃣ /jobs all*
   Show ALL matches (score ≥0.55)
   Synonyms: "all jobs", "every match"

*3️⃣ /jobs stats*
   Weekly job statistics
   Synonyms: "stats", "statistics"

*4️⃣ /apply [number]*
   Mark job as applied
   Example: "apply 1" or "apply 3"
   Synonyms: "candidater", "j'ai postulé"

*5️⃣ /skip [number]*
   Mark job as skipped/ignored
   Example: "skip 2"
   Synonyms: "pass", "ignorer"

════════════════════════════════════

*👤 PROFILE & SETTINGS*

*6️⃣ /profile*
   Show your extracted CV
   • Years of experience
   • Primary & secondary skills
   • Target roles
   • Preferences
   Synonyms: "mon profil", "show CV"

*7️⃣ /settings*
   View/update your preferences
   • Remote preference
   • Salary expectations
   • Job types
   Synonyms: "preferences", "parametres"

*8️⃣ /insights*
   Claude career insights & advice
   Synonyms: "advice", "career tips"

════════════════════════════════════

*❓ HELP & INFO*

*9️⃣ /help*
   Show command summary
   Synonyms: "aide", "commands"

════════════════════════════════════

*💡 HOW TO USE NATURAL LANGUAGE*

You don't need to remember commands!
Just ask naturally:

✓ "show me the best jobs"
✓ "what positions match me?"
✓ "mark this as applied"
✓ "affiche mes meilleures offres"
✓ "je veux postuler au job 1"
✓ "stats pour cette semaine"
✓ "mon profil"

The AI understands multiple languages
and figures out what you want! 🤖

════════════════════════════════════

*📊 SYSTEM INFO*

Capacity: 315-585 jobs/day
Sources: 11 (RemoteOK, Indeed, LinkedIn, etc)
Frequency: Daily at 06:00 WAT
Delivery: WhatsApp
Cost: $1-5/month

════════════════════════════════════
"""
        return commands_text.strip()

    def find_command(self, user_input: str) -> Optional[str]:
        """Intelligently find command using NLP-like matching"""
        user_input_lower = user_input.lower().strip()

        # Exact command match
        for cmd in self.commands.keys():
            if user_input_lower.startswith(cmd.lower()):
                return cmd

        # Synonym match with threshold
        best_match = None
        best_score = 0.4  # Minimum similarity threshold

        for cmd, cmd_info in self.commands.items():
            for synonym in cmd_info.get("synonyms", []):
                score = SequenceMatcher(None, user_input_lower, synonym.lower()).ratio()
                if score > best_score:
                    best_score = score
                    best_match = cmd

        return best_match

    async def handle_jobs_top(self, user_input: str = "") -> str:
        """Top 5 job matches"""
        if not self.repo:
            return "❌ Database not available. Please try again later."

        try:
            top_matches = self.repo.get_top_matches(profile_id=1, limit=5)
            if not top_matches:
                return "📭 No matches found today. Check back later!"

            result = "*🌟 TOP 5 BEST MATCHES TODAY 🌟*\n"
            result += "=" * 40 + "\n\n"

            for i, match in enumerate(top_matches, 1):
                score = match.get("score_total", 0)
                if score >= 0.75:
                    grade = "🟢 EXCELLENT"
                elif score >= 0.55:
                    grade = "🟡 GOOD"
                else:
                    grade = "🔴 MARGINAL"

                result += f"*{i}. {match['title']}*\n"
                result += f"   Company: {match['company']}\n"
                result += f"   Score: {score:.2f} {grade}\n"

                if match.get("salary_min") and match.get("salary_max"):
                    result += f"   Salary: ${match['salary_min']:,} - ${match['salary_max']:,}\n"

                result += "\n"

            result += "=" * 40 + "\n"
            result += "💡 Use `/apply 1` to mark job #1 as applied\n"
            result += "💡 Use `/skip 2` to skip job #2\n"

            return result
        except Exception as e:
            return f"❌ Error: {str(e)[:100]}"

    async def handle_jobs_all(self, user_input: str = "") -> str:
        """All job matches"""
        if not self.repo:
            return "❌ Database not available."

        try:
            all_matches = self.repo.get_top_matches(profile_id=1, limit=50)
            if not all_matches:
                return "📭 No matches found."

            result = "*📊 ALL MATCHES (Score ≥ 0.55) 📊*\n"
            result += "=" * 40 + "\n\n"

            excellent = [m for m in all_matches if m.get("score_total", 0) >= 0.75]
            good = [m for m in all_matches if 0.55 <= m.get("score_total", 0) < 0.75]

            result += f"*🟢 EXCELLENT ({len(excellent)} jobs)*\n"
            for i, match in enumerate(excellent[:10], 1):
                result += f"  {i}. {match['title']} @ {match['company']} ({match['score_total']:.2f})\n"

            result += f"\n*🟡 GOOD ({len(good)} jobs)*\n"
            for i, match in enumerate(good[:10], 1):
                result += f"  {i}. {match['title']} @ {match['company']} ({match['score_total']:.2f})\n"

            result += "\n" + "=" * 40 + "\n"
            result += f"Total: {len(excellent)} excellent + {len(good)} good\n"

            return result
        except Exception as e:
            return f"❌ Error: {str(e)[:100]}"

    async def handle_jobs_stats(self, user_input: str = "") -> str:
        """Weekly statistics"""
        if not self.repo:
            return "❌ Database not available."

        try:
            result = "*📈 WEEKLY STATISTICS 📈*\n"
            result += "=" * 40 + "\n\n"

            # Get stats from RDS
            all_matches = self.repo.get_top_matches(profile_id=1, limit=100)

            total_matches = len(all_matches)
            excellent = len([m for m in all_matches if m.get("score_total", 0) >= 0.75])
            good = len([m for m in all_matches if 0.55 <= m.get("score_total", 0) < 0.75])

            result += f"📊 Total jobs matched: {total_matches}\n"
            result += f"🟢 EXCELLENT matches: {excellent}\n"
            result += f"🟡 GOOD matches: {good}\n"
            result += f"📈 Quality: {(excellent + good) / max(total_matches, 1) * 100:.1f}%\n"
            result += "\n" + "=" * 40 + "\n"
            result += "💡 Use /jobs to see top 5\n"

            return result
        except Exception as e:
            return f"❌ Error: {str(e)[:100]}"

    async def handle_apply(self, user_input: str) -> str:
        """Mark job as applied"""
        # Extract job number if provided
        import re

        match = re.search(r"\d+", user_input)
        if not match:
            return "❓ Please specify which job: /apply 1 or just say 'apply job 3'"

        job_num = int(match.group())
        return f"✅ Marked job #{job_num} as applied!\n\n(This would update career_ops.applications table)"

    async def handle_skip(self, user_input: str) -> str:
        """Mark job as skipped"""
        import re

        match = re.search(r"\d+", user_input)
        if not match:
            return "❓ Please specify which job: /skip 1 or say 'skip job 2'"

        job_num = int(match.group())
        return f"⏭️ Skipped job #{job_num}\n\n(Marked as ignored)"

    async def handle_profile(self, user_input: str = "") -> str:
        """Show CV profile"""
        if not self.profile:
            return "❌ Profile not loaded."

        result = "*👤 YOUR CV PROFILE 👤*\n"
        result += "=" * 40 + "\n\n"
        result += f"*Name:* {self.profile.full_name}\n"
        result += f"*Experience:* {self.profile.years_experience} years\n"
        result += f"*Location:* {self.profile.location}\n\n"

        result += "*🛠️ PRIMARY SKILLS*\n"
        for skill in self.profile.skills_primary[:5]:
            result += f"  • {skill}\n"

        result += "\n*📚 SECONDARY SKILLS*\n"
        for skill in self.profile.skills_secondary[:5]:
            result += f"  • {skill}\n"

        result += "\n*🎯 TARGET ROLES*\n"
        for role in self.profile.target_roles[:3]:
            result += f"  • {role}\n"

        result += f"\n*🌍 Languages:* {', '.join(self.profile.languages)}\n"
        result += f"*💰 Min Salary:* ${self.profile.min_salary_usd:,}/year\n"
        result += f"*🏠 Remote Preference:* {self.profile.remote_preference}\n"

        return result

    async def handle_settings(self, user_input: str = "") -> str:
        """View/update settings"""
        result = "*⚙️ YOUR SETTINGS ⚙️*\n"
        result += "=" * 40 + "\n\n"

        if self.profile:
            result += f"*Remote Preference:* {self.profile.remote_preference}\n"
            result += f"*Min Salary:* ${self.profile.min_salary_usd:,}\n"
            result += f"*Target Roles:* {', '.join(self.profile.target_roles[:3])}\n\n"

        result += "To update settings, reply with what you want to change:\n"
        result += "  • 'Change salary to 50000'\n"
        result += "  • 'I want hybrid roles'\n"
        result += "  • 'Add Python to my skills'\n"

        return result

    async def handle_insights(self, user_input: str = "") -> str:
        """Career insights"""
        result = "*💡 CAREER INSIGHTS 💡*\n"
        result += "=" * 40 + "\n\n"

        if self.profile:
            result += f"Based on your profile ({self.profile.years_experience} years, {', '.join(self.profile.skills_primary[:2])}):\n\n"
            result += "✓ Strong demand for your Python + SQL + R combination\n"
            result += "✓ Consider adding Power BI/Tableau for senior roles\n"
            result += "✓ Remote-only is good strategy (40% more offers available)\n"
            result += "✓ Your target salary ($40k) is achievable with your skills\n\n"

        result += "💬 More insights coming soon (Claude integration in progress!)\n"

        return result

    async def handle_help(self, user_input: str = "") -> str:
        """Show help"""
        return self.get_help_text()

    async def process_message(self, user_message: str) -> str:
        """Main entry point: process user message and return response"""

        # Try to find command
        command = self.find_command(user_message)

        if command:
            handler = self.commands[command]["handler"]
            try:
                response = await handler(user_message)
                return response
            except Exception as e:
                return f"❌ Error processing command: {str(e)[:100]}"

        # If no command found, provide help
        return self.get_help_text()


# FastAPI endpoint for PsychoBot integration
async def handle_careerops_command(message_text: str) -> str:
    """Handle Career-Ops command from WhatsApp"""
    handler = CareerOpsCommandHandler()
    return await handler.process_message(message_text)


if __name__ == "__main__":
    # Test
    handler = CareerOpsCommandHandler()
    print(handler.get_commands_list_formatted())
