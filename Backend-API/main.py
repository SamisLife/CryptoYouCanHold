import json
import os
import time
from typing import Optional, Dict
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="Physical Crypto API", description="Hardware Wallet Backend")

DB_FILE = "db.json"

# --- DATA MODELS ---
class PhysicalCoin(BaseModel):
    coin_id: str
    wallet_id: str
    asset_name: str
    symbol: str
    amount: float
    disabled: bool = False
    transferrable: bool = False
    transfer_start_timestamp: Optional[float] = None

class TransferRequest(BaseModel):
    coin_id: str
    destination_wallet: str # The digital wallet receiving the funds

# DB Helpers
def load_db() -> Dict[str, dict]:
    if not os.path.exists(DB_FILE):
        return {}
    with open(DB_FILE, "r") as f:
        try:
            return json.load(f)
        except json.JSONDecodeError:
            return {}

def save_db(data: Dict[str, dict]):
    with open(DB_FILE, "w") as f:
        json.dump(data, f, indent=4)

# API Endpoints

@app.post("/coins/", status_code=201)
def create_coin(coin: PhysicalCoin):
    """Initializes a new physical coin from the iOS app."""
    db = load_db()
    if coin.coin_id in db:
        raise HTTPException(status_code=400, detail="Coin ID already exists.")
    
    db[coin.coin_id] = coin.dict()
    save_db(db)
    return {"message": "Hardware coin initialized", "coin": db[coin.coin_id]}

@app.get("/coins/{coin_id}")
def get_coin(coin_id: str):
    """Fetches coin details and verifies if it exists."""
    db = load_db()
    if coin_id not in db:
        raise HTTPException(status_code=404, detail="Coin not found.")
    return db[coin_id]

@app.delete("/coins/{coin_id}")
def delete_coin(coin_id: str):
    """Deletes the coin (Reclaim Balance feature)."""
    db = load_db()
    if coin_id not in db:
        raise HTTPException(status_code=404, detail="Coin not found.")
    
    deleted_coin = db.pop(coin_id)
    save_db(db)
    return {
        "message": "Coin deleted, funds released", 
        "refund_amount": deleted_coin["amount"],
        "refund_to_wallet": deleted_coin["wallet_id"]
    }

@app.put("/coins/{coin_id}/status")
def toggle_status(coin_id: str, disabled: bool):
    """Enables or disables the physical coin."""
    db = load_db()
    if coin_id not in db:
        raise HTTPException(status_code=404, detail="Coin not found.")
    
    db[coin_id]["disabled"] = disabled
    if disabled:
        # If disabled, immediately revoke transfer privileges
        db[coin_id]["transferrable"] = False
        db[coin_id]["transfer_start_timestamp"] = None
        
    save_db(db)
    state = "Disabled" if disabled else "Active"
    return {"message": f"Coin is now {state}"}

@app.put("/coins/{coin_id}/transfer_mode")
def unlock_transfer_mode(coin_id: str):
    """Unlocks the coin for transfer for exactly 2 minutes."""
    db = load_db()
    if coin_id not in db:
        raise HTTPException(status_code=404, detail="Coin not found.")
    
    if db[coin_id].get("disabled"):
        raise HTTPException(status_code=403, detail="Cannot unlock a disabled coin.")
    
    db[coin_id]["transferrable"] = True
    db[coin_id]["transfer_start_timestamp"] = time.time()
    save_db(db)
    
    return {"message": "Transfer mode unlocked. Expires in 120 seconds."}

@app.post("/coins/transfer")
def execute_transfer(request: TransferRequest):
    """
    The ESP32/NFC scanner hits this endpoint to claim the coin.
    Verifies the 2-minute window before allowing the transfer.
    """
    db = load_db()
    coin_id = request.coin_id
    
    if coin_id not in db:
        raise HTTPException(status_code=404, detail="Invalid physical coin.")
    
    coin_data = db[coin_id]
    
    # 1. Check if disabled
    if coin_data.get("disabled"):
        raise HTTPException(status_code=403, detail="Coin is disabled for security reasons.")
    
    # 2. Check if transferrable mode was ever activated
    if not coin_data.get("transferrable") or coin_data.get("transfer_start_timestamp") is None:
        raise HTTPException(status_code=403, detail="Transfer mode is not active. Unlock via iOS app first.")
    
    # 3. Check the 2-minute (120 seconds) window
    elapsed_time = time.time() - coin_data["transfer_start_timestamp"]
    if elapsed_time > 120:
        # Automatically lock it back up
        coin_data["transferrable"] = False
        coin_data["transfer_start_timestamp"] = None
        save_db(db)
        raise HTTPException(status_code=403, detail="Transfer window expired. Please unlock again.")
    
    # 4. Execute transfer and destroy the physical link
    transfer_amount = coin_data["amount"]
    symbol = coin_data["symbol"]
    source_wallet = coin_data["wallet_id"]
    
    db.pop(coin_id)
    save_db(db)
    
    return {
        "status": "SUCCESS",
        "message": f"Successfully transferred {transfer_amount} {symbol} from {source_wallet} to {request.destination_wallet}",
        "amount": transfer_amount,
        "symbol": symbol,
        "source_wallet": source_wallet,
        "destination_wallet": request.destination_wallet
    }