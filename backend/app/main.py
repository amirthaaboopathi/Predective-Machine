"""
FastAPI Server for MyAppliance AI
"""
from typing import List, Optional, Dict, Any
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import uvicorn

from .config import settings
from .gemini_service import gemini_service
from .supabase_service import supabase_service

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="Advanced Conversational Appliance Intelligence Assistant API Powered by Google Gemini"
)

# Enable CORS for Flutter Web, Android Emulator (10.0.2.2), iOS Simulator & Desktop
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class ChatHistoryTurn(BaseModel):
    role: str
    text: str

class ChatRequest(BaseModel):
    message: str = Field(..., description="User prompt or inquiry")
    user_id: Optional[str] = Field("local_user", description="Authenticated user ID")
    user_name: Optional[str] = Field(None, description="User display name")
    user_email: Optional[str] = Field(None, description="User email")
    appliance_id: Optional[str] = Field(None, description="Focused appliance ID if any")
    history: Optional[List[ChatHistoryTurn]] = Field(default=[], description="Multi-turn conversation history")

class ChatResponse(BaseModel):
    response: str
    source: str
    online: bool
    appliance_referenced: Optional[str] = None

@app.get("/")
@app.get("/health")
async def health_check():
    """Health check endpoint displaying system status and configured model."""
    return {
        "status": "healthy",
        "service": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "gemini_model": settings.GEMINI_MODEL,
        "supabase_connected": bool(settings.SUPABASE_URL and settings.SUPABASE_KEY)
    }

@app.post("/api/chat", response_model=ChatResponse)
async def chat_endpoint(payload: ChatRequest):
    """
    Main conversational endpoint:
    1. Authenticates & identifies relevant appliances from Supabase.
    2. Builds comprehensive context with Master System Prompt.
    3. Invokes Gemini API (or edge intelligence fallback).
    4. Saves conversation record and returns response.
    """
    if not payload.message.strip():
        raise HTTPException(status_code=400, detail="Message cannot be empty")

    # 1. Fetch user appliances context from Supabase
    appliances = await supabase_service.get_user_appliances(payload.user_id)
    focus_appliance = None
    if payload.appliance_id:
        for app in appliances:
            if app.get("id") == payload.appliance_id:
                focus_appliance = app
                break

    # 2. Convert history format
    history_dicts = [{"role": h.role, "text": h.text} for h in payload.history]

    # 3. Generate response via GeminiService
    result = await gemini_service.generate_response(
        message=payload.message,
        user_name=payload.user_name,
        user_email=payload.user_email,
        focus_appliance=focus_appliance,
        appliances=appliances,
        history=history_dicts
    )

    # 4. Save history in background
    await supabase_service.save_chat_message(
        user_id=payload.user_id,
        role="user",
        text=payload.message,
        appliance_id=payload.appliance_id
    )
    await supabase_service.save_chat_message(
        user_id=payload.user_id,
        role="assistant",
        text=result["response"],
        appliance_id=payload.appliance_id
    )

    return ChatResponse(
        response=result["response"],
        source=result["source"],
        online=result["online"],
        appliance_referenced=focus_appliance.get("name") if focus_appliance else None
    )

@app.get("/api/appliances/{user_id}")
async def list_user_appliances(user_id: str):
    """Retrieves all registered appliances with live telemetry for an authenticated user."""
    appliances = await supabase_service.get_user_appliances(user_id)
    return {"appliances": appliances}

if __name__ == "__main__":
    uvicorn.run("backend.app.main:app", host=settings.HOST, port=settings.PORT, reload=settings.DEBUG)
