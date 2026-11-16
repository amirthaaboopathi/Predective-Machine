"""
Entry point to launch the MyAppliance AI FastAPI Backend Server.
Usage:
    python backend/run.py
"""
import sys
from pathlib import Path
import uvicorn

# Add backend directory to sys.path
backend_dir = Path(__file__).resolve().parent
sys.path.insert(0, str(backend_dir.parent))

from backend.app.config import settings

if __name__ == "__main__":
    print(f"🚀 Starting MyAppliance AI Backend Server on {settings.HOST}:{settings.PORT}")
    print(f"📡 Configured Gemini Model: {settings.GEMINI_MODEL}")
    print(f"🔗 Supabase URL: {settings.SUPABASE_URL}")
    uvicorn.run(
        "backend.app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG
    )
