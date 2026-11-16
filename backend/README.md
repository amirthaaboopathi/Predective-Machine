# MyAppliance AI — FastAPI Backend Server

Advanced ChatGPT-Style Conversational Appliance Intelligence Assistant Backend powered by **Google Gemini API** and **Supabase**.

## Architecture

```
Flutter Application (Mobile, Web, Desktop)
        │
        ▼
Python FastAPI Backend (Port 8000)
        │
        ├──── Supabase Database
        │       ├─ Registered Appliances
        │       ├─ Sensor Telemetry (DS18B20, MPU6050, INMP441)
        │       ├─ Health Diagnostics & Scans
        │       └─ Persistent Conversation History
        │
        └──── Google Gemini API (gemini-1.5-flash)
                │
                ▼
        Intelligent Conversational AI Response
                │
                ▼
        Flutter Chat Interface
```

## Quick Start

### 1. Install Dependencies
```bash
cd backend
pip install -r requirements.txt
```

### 2. Configure Environment
Copy `.env.example` to `.env` and verify your credentials:
```env
GEMINI_API_KEY=your_gemini_api_key_here
GEMINI_MODEL=gemini-1.5-flash
SUPABASE_URL=https://jalicryunnjxmipuihwp.supabase.co
SUPABASE_KEY=sb_publishable_cAWNuGx3JYV1zfee1qMxEQ__15qt_3w
HOST=0.0.0.0
PORT=8000
```

### 3. Run Server
```bash
python backend/run.py
```
Or with Uvicorn directly:
```bash
uvicorn backend.app.main:app --host 0.0.0.0 --port 8000 --reload
```

Interactive API documentation will be available at:
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

## API Endpoints

- `GET /health`: Health status and Gemini model check.
- `POST /api/chat`: Primary conversational endpoint.
  ```json
  {
    "message": "Why is my washing machine vibrating?",
    "user_id": "user_123",
    "appliance_id": "app_456",
    "history": []
  }
  ```
- `GET /api/appliances/{user_id}`: Lists registered appliances and latest telemetry.
