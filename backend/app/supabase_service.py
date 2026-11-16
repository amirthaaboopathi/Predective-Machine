"""
Supabase Database Service for MyAppliance AI Backend
"""
from typing import List, Dict, Any, Optional
import httpx
from .config import settings

class SupabaseService:
    def __init__(self):
        self.url = settings.SUPABASE_URL.rstrip('/')
        self.key = settings.SUPABASE_KEY
        self.headers = {
            "apikey": self.key,
            "Authorization": f"Bearer {self.key}",
            "Content-Type": "application/json"
        }
        
    async def get_user_appliances(self, user_id: str) -> List[Dict[str, Any]]:
        """Retrieves registered appliances and their latest telemetry."""
        try:
            async with httpx.AsyncClient(timeout=4.0) as client:
                resp = await client.get(
                    f"{self.url}/rest/v1/appliances?user_id=eq.{user_id}&order=created_at.desc",
                    headers=self.headers
                )
                if resp.status_code == 200:
                    appliances = resp.json()
                    # Enrich with latest readings
                    for app in appliances:
                        readings = await self.get_latest_readings(app.get("id"))
                        if readings:
                            latest = readings[0]
                            app["temperature"] = latest.get("temperature")
                            app["vibration"] = latest.get("vibration")
                            app["sound"] = latest.get("sound")
                    return appliances
        except Exception as e:
            # Fallback gracefully
            pass
        return []

    async def get_latest_readings(self, appliance_id: str) -> List[Dict[str, Any]]:
        """Retrieves newest telemetry sensor records for an appliance."""
        try:
            async with httpx.AsyncClient(timeout=3.0) as client:
                resp = await client.get(
                    f"{self.url}/rest/v1/sensor_readings?appliance_id=eq.{appliance_id}&order=recorded_at.desc&limit=5",
                    headers=self.headers
                )
                if resp.status_code == 200:
                    return resp.json()
        except Exception:
            pass
        return []

    async def save_chat_message(self, user_id: str, role: str, text: str, appliance_id: Optional[str] = None) -> bool:
        """Stores chat message in persistent history if available."""
        try:
            async with httpx.AsyncClient(timeout=3.0) as client:
                payload = {
                    "user_id": user_id,
                    "role": role,
                    "content": text,
                    "appliance_id": appliance_id
                }
                resp = await client.post(
                    f"{self.url}/rest/v1/chat_history",
                    headers=self.headers,
                    json=payload
                )
                return resp.status_code in (200, 201)
        except Exception:
            return False

supabase_service = SupabaseService()
