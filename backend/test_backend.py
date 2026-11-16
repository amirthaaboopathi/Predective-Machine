"""
Automated validation script for MyAppliance AI FastAPI Backend
"""
import sys
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from backend.app.config import settings
from backend.app.prompts import build_system_instruction
from backend.app.gemini_service import gemini_service

def test_backend():
    print("1. Validating Backend Settings...", flush=True)
    assert settings.GEMINI_MODEL == "gemini-1.5-flash"
    assert len(settings.GEMINI_API_KEY) > 20
    print(f"   -> GEMINI_MODEL: {settings.GEMINI_MODEL} (OK)", flush=True)
    print("   -> GEMINI_API_KEY: Configured (OK)", flush=True)

    print("2. Validating System Prompt Context Generation...", flush=True)
    sample_apps = [
        {
            "name": "Smart Refrigerator",
            "type": "Refrigerator",
            "brand": "LG",
            "modelNumber": "GL-2026",
            "temperature": 32.5,
            "vibration": 0.18,
            "sound": 42.0,
            "health_score": 98,
            "health_status": "Good"
        }
    ]
    prompt = build_system_instruction(
        user_name="Test User",
        user_email="test@example.com",
        appliances=sample_apps
    )
    assert "MASTER PROMPT — BUILD MYAPPLIANCE AI" in prompt
    assert "Smart Refrigerator" in prompt
    print("   -> System instruction and telemetry context compiled successfully! (OK)", flush=True)

    print("3. Validating Edge Intelligence Fallback & General Conversational Reasoning...", flush=True)
    ai_res = gemini_service._edge_intelligence_engine(
        message="What is artificial intelligence?",
        focus_appliance=None,
        appliances=sample_apps
    )
    assert "Artificial Intelligence" in ai_res or "AI" in ai_res
    print("   -> General knowledge answering (AI): Verified (OK)", flush=True)

    smoke_res = gemini_service._edge_intelligence_engine(
        message="My microwave is smoking!",
        focus_appliance=None,
        appliances=sample_apps
    )
    assert "urgent" in smoke_res.lower()
    print("   -> Strict Safety Protocol: Verified (OK)", flush=True)

    py_res = gemini_service._edge_intelligence_engine(
        message="Explain Python programming",
        focus_appliance=None,
        appliances=sample_apps
    )
    assert "Python" in py_res
    print("   -> Educational coding explanation: Verified (OK)", flush=True)

    food_res = gemini_service._edge_intelligence_engine(
        message="What is the recommended refrigerator temperature for food safety?",
        focus_appliance=None,
        appliances=sample_apps
    )
    assert "3–5°C" in food_res or "3-5°C" in food_res
    print("   -> Food safety distinction: Verified (OK)", flush=True)

    print("\nAll Backend Unit & Intelligence Validations Passed Successfully!", flush=True)

if __name__ == "__main__":
    test_backend()
