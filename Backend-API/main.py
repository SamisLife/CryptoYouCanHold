import json
import os
import time
from typing import Optional, Dict
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="Physical Crypto API", description="Hardware Wallet Backend")

DB_FILE = "db.json"

# data models
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
    destination_wallet: str 

# db helpers
def load_db() -> Dict[str, dict]:
    if not os.path.exists(DB_FILE):
        # new structure
        return {
            "coins": {},
            "wallets": {
                "wallet_person_1": {"BTC": 2.45, "ETH": 14.2},
                "wallet_person_2": {"BTC": 0.0, "ETH": 0.0}
            }
        }
    with open(DB_FILE, "r") as f:
        try:
            return json.load(f)
        except json.JSONDecodeError:
            return {"coins": {}, "wallets": {"wallet_person_1": {"BTC": 2.45, "ETH": 14.2}, "wallet_person_2": {"BTC": 0.0, "ETH": 0.0}}}

def save_db(data: Dict[str, dict]):
    with open(DB_FILE, "w") as f:
        json.dump(data, f, indent=4)

# --- API ENDPOINTS ---

@app.post("/coins/", status_code=201)
def create_coin(coin: PhysicalCoin):
    db = load_db()
    if coin.coin_id in db["coins"]:
        raise HTTPException(status_code=400, detail="Coin ID already exists.")
    
    # 1. Ensure wallet and symbol exist
    wallet_data = db["wallets"].get(coin.wallet_id, {})
    if coin.symbol not in wallet_data:
        wallet_data[coin.symbol] = 0.0
        
    # 2. Deduct the specific crypto amount from the sender
    wallet_data[coin.symbol] -= coin.amount
    db["wallets"][coin.wallet_id] = wallet_data

    # 3. Save the physical coin
    db["coins"][coin.coin_id] = coin.dict()
    save_db(db)
    return {"message": "Hardware coin initialized", "coin": db["coins"][coin.coin_id]}

@app.get("/coins/{coin_id}")
def get_coin(coin_id: str):
    db = load_db()
    if coin_id not in db["coins"]:
        raise HTTPException(status_code=404, detail="Coin not found.")
    return db["coins"][coin_id]

@app.delete("/coins/{coin_id}")
def delete_coin(coin_id: str):
    db = load_db()
    if coin_id not in db["coins"]:
        raise HTTPException(status_code=404, detail="Coin not found.")
    
    deleted_coin = db["coins"].pop(coin_id)
    
    # Reclaim: Refund the specific crypto symbol back to the sender
    wallet_data = db["wallets"].get(deleted_coin["wallet_id"], {})
    if deleted_coin["symbol"] not in wallet_data:
        wallet_data[deleted_coin["symbol"]] = 0.0
        
    wallet_data[deleted_coin["symbol"]] += deleted_coin["amount"]
    db["wallets"][deleted_coin["wallet_id"]] = wallet_data
    
    save_db(db)
    return {"message": "Coin deleted, funds refunded"}

@app.put("/coins/{coin_id}/status")
def toggle_status(coin_id: str, disabled: bool):
    db = load_db()
    if coin_id not in db["coins"]:
        raise HTTPException(status_code=404, detail="Coin not found.")
    
    db["coins"][coin_id]["disabled"] = disabled
    if disabled:
        db["coins"][coin_id]["transferrable"] = False
        db["coins"][coin_id]["transfer_start_timestamp"] = None
        
    save_db(db)
    state = "Disabled" if disabled else "Active"
    return {"message": f"Coin is now {state}"}

@app.put("/coins/{coin_id}/transfer_mode")
def unlock_transfer_mode(coin_id: str):
    db = load_db()
    if coin_id not in db["coins"]:
        raise HTTPException(status_code=404, detail="Coin not found.")
    if db["coins"][coin_id].get("disabled"):
        raise HTTPException(status_code=403, detail="Cannot unlock disabled coin.")
    
    db["coins"][coin_id]["transferrable"] = True
    db["coins"][coin_id]["transfer_start_timestamp"] = time.time()
    save_db(db)
    return {"message": "Transfer mode unlocked."}

@app.post("/coins/transfer")
def execute_transfer(request: TransferRequest):
    db = load_db()
    coin_id = request.coin_id
    
    if coin_id not in db["coins"]: raise HTTPException(status_code=404, detail="Invalid physical coin.")
    coin_data = db["coins"][coin_id]
    
    if coin_data.get("disabled"): raise HTTPException(status_code=403, detail="Coin is disabled.")
    if not coin_data.get("transferrable") or coin_data.get("transfer_start_timestamp") is None:
        raise HTTPException(status_code=403, detail="Transfer mode not active.")
    
    if time.time() - coin_data["transfer_start_timestamp"] > 120:
        coin_data["transferrable"] = False
        coin_data["transfer_start_timestamp"] = None
        save_db(db)
        raise HTTPException(status_code=403, detail="Transfer window expired.")
    
    transfer_amount = coin_data["amount"]
    symbol = coin_data["symbol"]
    dest_wallet = request.destination_wallet

    # Ensure destination wallet and symbol exist
    dest_data = db["wallets"].get(dest_wallet, {})
    if symbol not in dest_data:
        dest_data[symbol] = 0.0
        
    # Credit the receiver
    dest_data[symbol] += transfer_amount
    db["wallets"][dest_wallet] = dest_data
    
    # Destroy physical link
    db["coins"].pop(coin_id)
    save_db(db)
    
    return {
        "status": "SUCCESS",
        "message": f"Transferred {transfer_amount} {symbol} to {dest_wallet}"
    }

@app.get("/coins/wallet/{wallet_id}")
def get_wallet_coins(wallet_id: str):
    db = load_db()
    return [coin_data for coin_data in db["coins"].values() if coin_data.get("wallet_id") == wallet_id]

@app.get("/wallets/{wallet_id}")
def get_wallet_balances(wallet_id: str):
    """Fetches the digital balances for a specific wallet."""
    db = load_db()
    if wallet_id not in db["wallets"]:
        # If the wallet doesn't exist yet, return 0 balances
        return {"BTC": 0.0, "ETH": 0.0}
    
    return db["wallets"][wallet_id]