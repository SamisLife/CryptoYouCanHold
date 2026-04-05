import json;
import os;
import time;
import fastapi;
import uvicorn;

glob DB_FILE = "db.json";

# We define the FastAPI app directly in Jac!
glob app = fastapi.FastAPI(title="Physical Crypto API");

# --- DB HELPERS ---
def load_db() -> dict {
    if not os.path.exists(DB_FILE) {
        return {
            "coins": {},
            "wallets": {
                "wallet_person_1": {"BTC": 2.45, "ETH": 14.2},
                "wallet_person_2": {"BTC": 0.0, "ETH": 0.0}
            }
        };
    }
    with open(DB_FILE, "r") as f {
        try {
            return json.load(f);
        } except Exception as e {
            return {"coins": {}, "wallets": {"wallet_person_1": {"BTC": 2.45, "ETH": 14.2}, "wallet_person_2": {"BTC": 0.0, "ETH": 0.0}}};
        }
    }
}

def save_db(data: dict) {
    with open(DB_FILE, "w") as f {
        json.dump(data, f, indent=4);
    }
}

# --- NATIVE FASTAPI ENDPOINTS IN JAC ---

@app.post("/coins/", status_code=201)
def create_coin(payload: dict = fastapi.Body()) {
    db = load_db();
    coin_id = payload["coin_id"];
    wallet_id = payload["wallet_id"];
    symbol = payload["symbol"];
    amount = payload["amount"];
    
    if coin_id in db["coins"] {
        raise fastapi.HTTPException(status_code=400, detail="Coin ID already exists.");
    }
    
    wallet_data = db["wallets"].get(wallet_id, {});
    if symbol not in wallet_data {
        wallet_data[symbol] = 0.0;
    }
        
    wallet_data[symbol] -= amount;
    db["wallets"][wallet_id] = wallet_data;

    db["coins"][coin_id] = {
        "coin_id": coin_id,
        "wallet_id": wallet_id,
        "asset_name": payload["asset_name"],
        "symbol": symbol,
        "amount": amount,
        "disabled": False,
        "transferrable": False,
        "transfer_start_timestamp": None
    };
    save_db(db);
    return {"message": "Hardware coin initialized", "coin": db["coins"][coin_id]};
}

@app.get("/coins/{coin_id}")
def get_coin(coin_id: str) {
    db = load_db();
    if coin_id not in db["coins"] {
        raise fastapi.HTTPException(status_code=404, detail="Coin not found.");
    }
    return db["coins"][coin_id];
}

@app.delete("/coins/{coin_id}")
def delete_coin(coin_id: str) {
    db = load_db();
    if coin_id not in db["coins"] {
        raise fastapi.HTTPException(status_code=404, detail="Coin not found.");
    }
    
    deleted_coin = db["coins"].pop(coin_id);
    
    wallet_data = db["wallets"].get(deleted_coin["wallet_id"], {});
    if deleted_coin["symbol"] not in wallet_data {
        wallet_data[deleted_coin["symbol"]] = 0.0;
    }
        
    wallet_data[deleted_coin["symbol"]] += deleted_coin["amount"];
    db["wallets"][deleted_coin["wallet_id"]] = wallet_data;
    
    save_db(db);
    return {"message": "Coin deleted, funds refunded"};
}

@app.put("/coins/{coin_id}/status")
def toggle_status(coin_id: str, disabled: bool) {
    db = load_db();
    if coin_id not in db["coins"] {
        raise fastapi.HTTPException(status_code=404, detail="Coin not found.");
    }
    
    db["coins"][coin_id]["disabled"] = disabled;
    if disabled {
        db["coins"][coin_id]["transferrable"] = False;
        db["coins"][coin_id]["transfer_start_timestamp"] = None;
    }
        
    save_db(db);
    state = "Disabled" if disabled else "Active";
    return {"message": f"Coin is now {state}"};
}

@app.put("/coins/{coin_id}/transfer_mode")
def unlock_transfer_mode(coin_id: str) {
    db = load_db();
    if coin_id not in db["coins"] {
        raise fastapi.HTTPException(status_code=404, detail="Coin not found.");
    }
    if db["coins"][coin_id].get("disabled") {
        raise fastapi.HTTPException(status_code=403, detail="Cannot unlock disabled coin.");
    }
    
    db["coins"][coin_id]["transferrable"] = True;
    db["coins"][coin_id]["transfer_start_timestamp"] = time.time();
    save_db(db);
    return {"message": "Transfer mode unlocked."};
}

@app.post("/coins/transfer")
def execute_transfer(payload: dict = fastapi.Body()) {
    db = load_db();
    coin_id = payload["coin_id"];
    destination_wallet = payload["destination_wallet"];
    
    if coin_id not in db["coins"] {
        raise fastapi.HTTPException(status_code=404, detail="Invalid physical coin.");
    }
    coin_data = db["coins"][coin_id];
    
    if coin_data.get("disabled") {
        raise fastapi.HTTPException(status_code=403, detail="Coin is disabled.");
    }
    if not coin_data.get("transferrable") or coin_data.get("transfer_start_timestamp") is None {
        raise fastapi.HTTPException(status_code=403, detail="Transfer mode not active.");
    }
    
    if time.time() - coin_data["transfer_start_timestamp"] > 120 {
        coin_data["transferrable"] = False;
        coin_data["transfer_start_timestamp"] = None;
        save_db(db);
        raise fastapi.HTTPException(status_code=403, detail="Transfer window expired.");
    }
    
    # ===== TRANSFER OWNERSHIP =====
    coin_data["wallet_id"] = destination_wallet;
    
    # Lock the coin down so the new owner is secure
    coin_data["transferrable"] = False;
    coin_data["transfer_start_timestamp"] = None;
    
    # Save the updated coin
    db["coins"][coin_id] = coin_data;
    save_db(db);
    
    return {
        "status": "SUCCESS",
        "message": f"Ownership of {coin_data['symbol']} coin transferred to {destination_wallet}"
    };
}

@app.get("/coins/wallet/{wallet_id}")
def get_wallet_coins(wallet_id: str) {
    db = load_db();
    res = [];
    for coin_id in db["coins"] {
        coin_data = db["coins"][coin_id];
        if coin_data.get("wallet_id") == wallet_id {
            res.append(coin_data);
        }
    }
    return res;
}

@app.get("/wallets/{wallet_id}")
def get_wallet_balances(wallet_id: str) {
    db = load_db();
    if wallet_id not in db["wallets"] {
        return {"BTC": 0.0, "ETH": 0.0};
    }
    return db["wallets"][wallet_id];
}

# This tells Jac to boot up Uvicorn exactly like standard Python!
with entry {
    uvicorn.run(app, host="0.0.0.0", port=8000);
}