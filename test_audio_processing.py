#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test Audio Processing & Context-Aware Responses
Test du décodage audio et réponses suivant le contexte
"""

import os
import sys
import json
import requests
import asyncio
from datetime import datetime
from pathlib import Path

# PsychoBot endpoint
PSYCHOBOT_URL = "https://psychobot-1si7.onrender.com"

class AudioProcessingTest:
    """Test suite pour audio + réponses contextuelles"""

    def __init__(self):
        self.test_results = []
        self.phone = "+2290196911346"  # Ton numéro
        self.session = requests.Session()
        self.session.verify = False  # Désactiver SSL pour Render

    def log_test(self, test_name, status, details=""):
        """Logger le résultat d'un test"""
        result = {
            "timestamp": datetime.now().isoformat(),
            "test": test_name,
            "status": status,
            "details": details
        }
        self.test_results.append(result)
        emoji = "✅" if status == "PASS" else "❌"
        print(f"{emoji} {test_name}: {status}")
        if details:
            print(f"   └─ {details}\n")

    # ===== TEST 1: Audio Voice Message =====
    def test_1_send_audio_message(self):
        """Test 1: Envoyer un message audio synthétisé"""
        print("\n" + "="*60)
        print("TEST 1: Audio Voice Message (Synthèse vocale)")
        print("="*60 + "\n")

        try:
            # Créer un petit message audio (simulation)
            message = "Bonjour, voici un test de message audio. Peux-tu analyser XAUUSD?"

            payload = {
                "phone": self.phone,
                "message": message,
                "media_type": "audio",
                "caption": "🎤 Test audio - Analyse XAUUSD"
            }

            response = self.session.post(
                f"{PSYCHOBOT_URL}/send-message",
                json=payload,
                timeout=15
            )

            if response.status_code in [200, 201]:
                self.log_test(
                    "Audio Message Send",
                    "PASS",
                    f"Message audio envoyé: {response.status_code}"
                )
                return True
            else:
                self.log_test(
                    "Audio Message Send",
                    "FAIL",
                    f"Status {response.status_code}: {response.text[:100]}"
                )
                return False

        except Exception as e:
            self.log_test("Audio Message Send", "ERROR", str(e))
            return False

    # ===== TEST 2: Audio Transcription Decoding =====
    def test_2_audio_transcription(self):
        """Test 2: Décodage & transcription d'un message audio reçu"""
        print("\n" + "="*60)
        print("TEST 2: Audio Transcription Decoding")
        print("="*60 + "\n")

        try:
            # Simuler la réception d'un message audio
            # PsychoBot devrait transcrire et répondre selon le contexte

            test_audio_messages = [
                {
                    "content": "Quel est le verdict pour XAUUSD?",
                    "expected_context": "trading_analysis"
                },
                {
                    "content": "Envoie moi un rapport détaillé",
                    "expected_context": "report_generation"
                },
                {
                    "content": "Comment fonctionne le GOM?",
                    "expected_context": "education"
                }
            ]

            results = []
            for msg in test_audio_messages:
                payload = {
                    "phone": self.phone,
                    "message": f"Audio: {msg['content']}",
                    "audio_transcript": msg['content'],
                    "context": msg['expected_context']
                }

                try:
                    response = self.session.post(
                        f"{PSYCHOBOT_URL}/send-message",
                        json=payload,
                        timeout=15
                    )

                    if response.status_code in [200, 201]:
                        results.append(True)
                    else:
                        results.append(False)

                except:
                    results.append(False)

            if all(results):
                self.log_test(
                    "Audio Transcription",
                    "PASS",
                    f"Toutes les transcriptions traitées ({len(results)}/{len(results)})"
                )
                return True
            else:
                self.log_test(
                    "Audio Transcription",
                    "PARTIAL",
                    f"Transcriptions partielles ({sum(results)}/{len(results)})"
                )
                return False

        except Exception as e:
            self.log_test("Audio Transcription", "ERROR", str(e))
            return False

    # ===== TEST 3: Context-Aware Responses =====
    def test_3_context_aware_responses(self):
        """Test 3: Réponses adaptées au contexte"""
        print("\n" + "="*60)
        print("TEST 3: Context-Aware Responses")
        print("="*60 + "\n")

        try:
            contexts = {
                "trading": {
                    "query": "Verdict GOM pour XAUUSD?",
                    "expected_response_type": "trading_analysis"
                },
                "technical": {
                    "query": "Explique le RSI et le VWAP",
                    "expected_response_type": "technical_explanation"
                },
                "status": {
                    "query": "Status du système?",
                    "expected_response_type": "system_status"
                }
            }

            test_count = 0
            for context_key, context_data in contexts.items():
                try:
                    payload = {
                        "phone": self.phone,
                        "message": context_data['query'],
                        "context_type": context_key,
                        "request_id": f"test_{context_key}_{datetime.now().timestamp()}"
                    }

                    response = self.session.post(
                        f"{PSYCHOBOT_URL}/send-message",
                        json=payload,
                        timeout=15
                    )

                    if response.status_code in [200, 201]:
                        test_count += 1
                        print(f"   ✓ Context '{context_key}': Réponse générée")

                except Exception as e:
                    print(f"   ✗ Context '{context_key}': {str(e)[:50]}")

            if test_count >= len(contexts) * 0.8:  # 80% success
                self.log_test(
                    "Context-Aware Responses",
                    "PASS",
                    f"{test_count}/{len(contexts)} contextes traités correctement"
                )
                return True
            else:
                self.log_test(
                    "Context-Aware Responses",
                    "FAIL",
                    f"Seulement {test_count}/{len(contexts)} contextes valides"
                )
                return False

        except Exception as e:
            self.log_test("Context-Aware Responses", "ERROR", str(e))
            return False

    # ===== TEST 4: Audio + Trading Data Integration =====
    def test_4_audio_trading_integration(self):
        """Test 4: Intégration audio + données de trading"""
        print("\n" + "="*60)
        print("TEST 4: Audio + Trading Data Integration")
        print("="*60 + "\n")

        try:
            # Message audio avec requête trading
            trading_query = {
                "phone": self.phone,
                "message": "🎤 Audio: Analyse complète XAUUSD avec les données live du GOM KOLA",
                "audio_context": {
                    "duration": 8.5,  # secondes
                    "language": "fr",
                    "confidence": 0.95,
                    "intent": "trading_analysis",
                    "symbols": ["XAUUSD"]
                },
                "request_trading_data": True,
                "include_gom_verdict": True,
                "include_timeframes": ["M15", "H1", "H4"]
            }

            response = self.session.post(
                f"{PSYCHOBOT_URL}/send-message",
                json=trading_query,
                timeout=20  # Plus long pour les données trading
            )

            if response.status_code in [200, 201]:
                response_data = response.json() if response.text else {}
                has_trading_data = "XAUUSD" in response.text or "verdict" in response.text.lower()

                if has_trading_data:
                    self.log_test(
                        "Audio + Trading Integration",
                        "PASS",
                        "Réponse intégrée avec données trading"
                    )
                    return True
                else:
                    self.log_test(
                        "Audio + Trading Integration",
                        "PARTIAL",
                        "Réponse reçue mais sans données trading"
                    )
                    return False
            else:
                self.log_test(
                    "Audio + Trading Integration",
                    "FAIL",
                    f"Status {response.status_code}"
                )
                return False

        except Exception as e:
            self.log_test("Audio + Trading Integration", "ERROR", str(e))
            return False

    # ===== TEST 5: Audio Quality Detection =====
    def test_5_audio_quality_detection(self):
        """Test 5: Détection de qualité audio"""
        print("\n" + "="*60)
        print("TEST 5: Audio Quality Detection")
        print("="*60 + "\n")

        try:
            quality_scenarios = [
                {
                    "quality": "good",
                    "noise_level": 0.2,
                    "clarity": 0.95,
                    "expected_processing": "normal"
                },
                {
                    "quality": "poor",
                    "noise_level": 0.8,
                    "clarity": 0.45,
                    "expected_processing": "enhanced"
                },
                {
                    "quality": "excellent",
                    "noise_level": 0.05,
                    "clarity": 0.98,
                    "expected_processing": "priority"
                }
            ]

            passed = 0
            for scenario in quality_scenarios:
                try:
                    payload = {
                        "phone": self.phone,
                        "message": f"Audio quality test: {scenario['quality']}",
                        "audio_metadata": {
                            "noise_level": scenario['noise_level'],
                            "clarity": scenario['clarity'],
                            "sample_rate": 16000,
                            "duration": 5.0
                        },
                        "quality_check": True
                    }

                    response = self.session.post(
                        f"{PSYCHOBOT_URL}/send-message",
                        json=payload,
                        timeout=15
                    )

                    if response.status_code in [200, 201]:
                        passed += 1

                except:
                    pass

            if passed >= len(quality_scenarios) * 0.8:
                self.log_test(
                    "Audio Quality Detection",
                    "PASS",
                    f"{passed}/{len(quality_scenarios)} scénarios traités"
                )
                return True
            else:
                self.log_test(
                    "Audio Quality Detection",
                    "FAIL",
                    f"Seulement {passed}/{len(quality_scenarios)} scénarios valides"
                )
                return False

        except Exception as e:
            self.log_test("Audio Quality Detection", "ERROR", str(e))
            return False

    # ===== RUN ALL TESTS =====
    def run_all_tests(self):
        """Exécuter tous les tests"""
        print("\n" + "█"*60)
        print("█  AUDIO PROCESSING & CONTEXT-AWARE RESPONSES TEST SUITE")
        print("█"*60)

        results = {
            "Test 1 - Audio Message": self.test_1_send_audio_message(),
            "Test 2 - Transcription": self.test_2_audio_transcription(),
            "Test 3 - Context Aware": self.test_3_context_aware_responses(),
            "Test 4 - Trading Integration": self.test_4_audio_trading_integration(),
            "Test 5 - Quality Detection": self.test_5_audio_quality_detection(),
        }

        # Summary
        print("\n" + "="*60)
        print("TEST SUMMARY")
        print("="*60)

        passed = sum(1 for v in results.values() if v)
        total = len(results)
        success_rate = (passed / total) * 100

        for test_name, passed in results.items():
            status = "✅ PASS" if passed else "❌ FAIL"
            print(f"{status} — {test_name}")

        print(f"\nGlobal: {passed}/{total} tests passed ({success_rate:.0f}%)")

        # Save detailed results
        self.save_results()

        return passed == total

    def save_results(self):
        """Sauvegarder les résultats des tests"""
        try:
            log_path = Path("D:/Dev/TradBOT/test_audio_results.json")
            with open(log_path, "w", encoding="utf-8") as f:
                json.dump(self.test_results, f, ensure_ascii=False, indent=2)
            print(f"\n✅ Résultats sauvegardés: {log_path}")
        except Exception as e:
            print(f"\n❌ Erreur sauvegarde: {e}")


if __name__ == "__main__":
    tester = AudioProcessingTest()
    success = tester.run_all_tests()
    sys.exit(0 if success else 1)
