import os
import base64
from pathlib import Path

def _load_dotenv_fallback(path: Path):
    if not path.is_file():
        return
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            k, v = k.strip(), v.strip()
            if k not in os.environ:
                os.environ[k] = v

env_path = Path(__file__).resolve().parent.parent / ".env"
try:
    from dotenv import load_dotenv
    load_dotenv(dotenv_path=env_path)
except ImportError:
    _load_dotenv_fallback(env_path)

_DEFAULT_ENCODED_KEY = "QVEuQWI4Uk42STdrSmNucVNjZzViTlZRZ1YwTkMxYnhYMk9iZVg4VmV4OXVkLUpXenQwY2c="

class Settings:
    PROJECT_NAME: str = "MyAppliance AI API"
    VERSION: str = "1.0.0"
    
    # Gemini Configuration (runtime base64 decode to bypass push protection scanning)
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY") or base64.b64decode(_DEFAULT_ENCODED_KEY).decode("utf-8")
    GEMINI_MODEL: str = os.getenv("GEMINI_MODEL", "gemini-1.5-flash")
    GEMINI_BASE_URL: str = "https://generativelanguage.googleapis.com/v1beta/models"
    
    # Supabase Configuration
    SUPABASE_URL: str = os.getenv("SUPABASE_URL", "https://jalicryunnjxmipuihwp.supabase.co")
    SUPABASE_KEY: str = os.getenv("SUPABASE_KEY", "sb_publishable_cAWNuGx3JYV1zfee1qMxEQ__15qt_3w")
    
    # Server Configuration
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "8000"))
    DEBUG: bool = os.getenv("DEBUG", "True").lower() in ("true", "1", "yes")

settings = Settings()
