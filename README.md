## Inspiration

"What if crypto transactions felt like handing someone a coin?"

Think about the last time you paid someone in cash. No app, no address, no confirmation screen. You handed it over, they took it, and done.
Crypto never got there. For all its power, it's still shackled to 42 character wallet strings, internet connections, and a public ledger that ties every transaction to your identity. That's why it never spread to daily life. Not because people don't trust it, but because it simply wasn't built for it.

We asked: what if it was? What if you had the frictionlessness of cash, the privacy of crypto, and a security layer that neither currently offers?

That question became Crypto You Can Hold!

## What it does

We turn your crypto balance into something you can physically hold, pass, and receive. Like cash, but smarter.

At the center of it is a 3D-printed coin (cardboard cut in the shape of a coin actually. I didn't have access to 3d printing) with an NFC tag inside. The tag stores nothing valuable, just a "coin_id". No money, no keys, no sensitive data. All the real logic happens in the backend, where ownership and value are tracked.

A transaction typically occurs like this:

You scan the coin with your phone (or type the coin_id manually) and assign a value to it from your balance. Then you "unlock" the coin and open a transfer window, a 2-minute, single-use authorization that only you can trigger. You hand the coin to someone. They tap it against their smart wallet (a small device with an NFC PN532 reader and a small OLED screen) and if the window is still active, ownership transfers instantly. No addresses needed, no app accounts shared. Just a handoff.

And because nothing of value lives on the coin itself, stealing the coin or cloning the NFC tag gets an attacker exactly nowhere. The window is tied to the real owner's session, not the physical object.
On top of all that, there's an AI layer quietly watching every transaction, analyzing how often coins change hands, how fast, and whether anything looks off. It classifies each transfer in real time: safe, suspicious, or flagged for fraud.

The user is presented with an AI insight of how trustworthy the other user is depending on their transaction history. This offers safety to both users while keeping their identity and privacy secure.

The result? The speed and feel of cash. The privacy of crypto. And a security layer neither one has ever had.

## How we built it

We built CryptoCoin across four interconnected pieces: a physical coin, a smart wallet, a mobile app, and a backend that ties them all together.

The coin: a piece of cardboard cut into a coin shape, with an NFC 215 tag glued onto it. That's it. It carries a single JSON payload with a coin_id, no balance, nothing worth stealing. The value of the object is entirely in what the backend says it represents.

The smart wallet is the receiving end of every trade. It's built around an ESP32 microcontroller, an NFC PN532 reader, and a small 0.92" OLED screen. When a coin is tapped, the firmware reads the coin_id from the JSON payload and immediately queries the backend. If the transfer window isn't open, the API returns a 403 and the screen simply reads "Coin Locked." If the window is active, something more interesting happens, before the transfer goes through, the wallet fetches an AI-generated risk assessment of the coin's transaction history. The recipient sees a Risk Score and an English explanation of whether the trade looks clean or suspicious. They then make the call: authorize the transfer, or cancel it. The ESP32 connects to the internet through an iPhone hotspot, keeping it minimal for the demo.

The mobile app is built in Swift with Xcode. It's the coin owner's control center: managing their digital wallet, assigning value to a physical coin, and opening the 2-minute transfer window that arms the handoff.

## How was Jac used

The backend is written entirely in Jac and exposes the endpoints that coordinate all three devices. It maintains a db.json file tracking wallets, coins, and transaction history. The single source of truth for ownership and transfer state. The risk assessment itself is powered by "by llm()" calling Gemini 2.5 Flash, which processes transaction history and returns a scored judgment in real time. 

The whole backend is served via ngrok for better demo access.
