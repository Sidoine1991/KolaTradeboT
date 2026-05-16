#!/usr/bin/env python3
"""
Test script for Qwen model integration in AI server
"""
import requests
import json
import os

def test_ollama_connection():
    """Test basic Ollama connection with Qwen model"""
    print("=== Testing Ollama Connection ===")
    
    # Default configuration
    ollama_url = os.getenv("OLLAMA_URL", "http://localhost:11434/api/generate")
    model_name = os.getenv("OLLAMA_MODEL", "qwen3.5:4b")
    
    print(f"URL: {ollama_url}")
    print(f"Model: {model_name}")
    
    # Test prompt
    test_prompt = "Analyze this trading situation: EURUSD is showing bullish momentum with RSI at 65. What's your analysis?"
    
    payload = {
        "model": model_name,
        "prompt": test_prompt,
        "stream": False
    }
    
    try:
        print("\nSending request to Ollama...")
        response = requests.post(ollama_url, json=payload, timeout=30)
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Ollama connection successful!")
            print(f"Model response: {result.get('response', 'No response')[:200]}...")
            return True
        else:
            print(f"❌ Ollama connection failed: {response.status_code}")
            print(f"Error: {response.text}")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Connection error: {e}")
        return False

def test_ai_server_endpoint():
    """Test AI server Ollama endpoint"""
    print("\n=== Testing AI Server Ollama Endpoint ===")
    
    server_url = "http://localhost:8000/analyze/ollama"
    
    test_request = {
        "symbol": "EURUSD",
        "timeframe": "M1",
        "price_data": {
            "current_price": 1.0850,
            "rsi": 65,
            "macd": 0.002,
            "volume": 1000
        },
        "context": "Bullish momentum detected"
    }
    
    try:
        print("Sending request to AI server...")
        response = requests.post(server_url, json=test_request, timeout=60)
        
        if response.status_code == 200:
            result = response.json()
            print("✅ AI server endpoint successful!")
            print(f"Analysis: {result.get('analysis', 'No analysis')[:200]}...")
            return True
        else:
            print(f"❌ AI server endpoint failed: {response.status_code}")
            print(f"Error: {response.text}")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"❌ AI server connection error: {e}")
        print("Make sure AI server is running on localhost:8000")
        return False

def main():
    """Main test function"""
    print("🤖 Qwen Model Integration Test")
    print("=" * 50)
    
    # Test 1: Direct Ollama connection
    ollama_ok = test_ollama_connection()
    
    # Test 2: AI server endpoint (only if Ollama works)
    if ollama_ok:
        ai_server_ok = test_ai_server_endpoint()
    else:
        ai_server_ok = False
    
    # Summary
    print("\n" + "=" * 50)
    print("📊 TEST SUMMARY")
    print("=" * 50)
    print(f"Ollama Connection: {'✅ PASS' if ollama_ok else '❌ FAIL'}")
    print(f"AI Server Integration: {'✅ PASS' if ai_server_ok else '❌ FAIL'}")
    
    if ollama_ok and ai_server_ok:
        print("\n🎉 Qwen integration is working perfectly!")
    elif ollama_ok:
        print("\n⚠️ Ollama works but AI server integration needs attention")
    else:
        print("\n❌ Ollama connection failed - check if Ollama is running and Qwen model is installed")
        print("\n📝 Setup instructions:")
        print("1. Install Ollama: https://ollama.ai/")
        print("2. Pull Qwen model: ollama pull qwen3.5:4b")
        print("3. Start Ollama service")
        print("4. Set environment variables in .env file")

if __name__ == "__main__":
    main()
