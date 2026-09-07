# AwaazKhata (آواز کھاتہ)

**Voice-controlled inventory, task, and credit (udhaar) management for small Pakistani shopkeepers — built for the Bano Qabil x Alibaba Cloud AI Hackathon.**

AwaazKhata lets a shopkeeper manage their entire kiryana/wholesale shop — inventory, daily tasks, and customer credit — by simply speaking in Urdu or Roman Urdu. No typing, no forms, no literacy required. Built for shopkeepers who may have limited reading/writing ability but run their business from memory every single day.

---

## Why this exists

Millions of small shopkeepers across Pakistan track inventory and customer credit (udhaar) in paper registers or from memory. Existing POS/inventory apps assume comfort with typing, English UI, and structured data entry — a real barrier for many shop owners. AwaazKhata removes that barrier: you talk to it the way you'd talk to an employee.

---

## Core features

### Voice commands (Urdu / Roman Urdu)
- **Add inventory** — *"100 rupee ka 10 Nestle juice add karo"*
- **Update stock/price** — *"Shan biryani ab 100 ki karo"*
- **Add customer credit (udhaar)** — *"Ahmad ko 500 udhaar de diya"*
- **Record a payment** — *"Ahmad Khan ka udhaar 500 kaat do"*
- **Add a task/reminder** — *"Subah 9 baje jaldi uthna hai"* (urgency auto-detected → high priority)
- **Ask questions, get spoken answers** — *"Ahmad ka kitna baaki hai?"*, *"Kaunse item ka low stock hai?"*, *"Shan biryani kitne ki hai?"*, *"Tapal hai inventory mein?"*, *"Us din kitna bill bana tha?"*

Every voice action opens a **confirmation screen with editable fields** before anything is saved — so a misheard number or name can be corrected in one tap, never silently wrong.

### Smart matching (no duplicate records)
Voice input is fuzzy by nature ("Ahmad" vs "Ahmed" vs "Ahmad Khan"). AwaazKhata matches spoken names against existing customers/items (exact → prefix → fuzzy similarity) before deciding whether to update an existing record or create a new one — and asks the user to pick when it's ambiguous.

### Manual fallback
Every voice action also has a manual "+" button and edit/delete option, for when voice isn't practical or a correction is needed.

### Spoken answers (TTS)
Query answers are read aloud, not just shown as text — built for users who may not be comfortable reading the screen.

### Offline-first persistence
All data (inventory, tasks, udhaar) is stored locally on-device via **Hive**, and survives app restarts. Nothing requires an internet connection except the voice-parsing step itself.

### Dashboard & sharing
- Summary dashboard: total credit sales, amount received, amount pending, inventory value
- Pending-customers list, grouped view of who owes what
- Per-customer ledger screen with full transaction history
- One-tap bill sharing via WhatsApp (`url_launcher`)
- Direct call button on customer cards

---

## Tech stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Android) |
| Backend | Python 3.12 + FastAPI |
| Voice parsing / NLU | Qwen (via Groq's hosted endpoint during development; swaps to Alibaba Cloud Qwen via a single environment variable — no code changes) |
| Speech-to-text | Android's native speech recognizer (via `speech_to_text`) |
| Local storage | Hive |
| Text-to-speech | `flutter_tts` |
| Sharing | `url_launcher` (WhatsApp, phone dialer) |
| AI-assisted development | Qoder |

---

## Project structure

```
AwaazKhata/
├── khata_app/          # Flutter frontend
│   ├── lib/
│   │   ├── models/          # InventoryItem, Task, UdhaarEntry, ParsedAction
│   │   ├── providers/       # app_state.dart — shared state, Hive-backed
│   │   ├── screens/         # Splash, Login, Home, Inventory, Tasks, Udhaar, Ledger, Dashboard
│   │   ├── services/        # speech_service, backend_api_service, session_service, storage_service
│   │   ├── widgets/         # Reusable UI components, dialogs
│   │   └── theme/           # App-wide styling
│   └── android/
└── khata_backend/      # FastAPI backend
    ├── main.py              # /parse-command, /health endpoints, Qwen prompt, keyword fallback
    ├── test_classification.py
    ├── requirements.txt
    └── .env.example         # Template — copy to .env and fill in your own key
```

---

## Getting started

### Prerequisites
- Flutter SDK (stable channel)
- Python 3.12
- A Groq API key ([console.groq.com](https://console.groq.com)) — or an Alibaba Cloud Qwen API key for production
- An Android device or emulator

### 1. Backend setup

```bash
cd khata_backend
py -3.12 -m venv venv
.\venv\Scripts\activate        # Windows
# source venv/bin/activate     # macOS/Linux

pip install -r requirements.txt

# Copy the template and add your own key — never commit .env
copy .env.example .env         # Windows
# cp .env.example .env         # macOS/Linux
```

Fill in `.env`:
```
LLM_API_KEY=your_groq_or_alibaba_key_here
LLM_BASE_URL=https://api.groq.com/openai/v1   # swap to Alibaba Cloud's endpoint for production
```

Run it:
```bash
python main.py
```
Backend runs on `http://0.0.0.0:8000`. Confirm it's alive at `http://localhost:8000/health`.

### 2. Frontend setup

Find your machine's LAN IP (`ipconfig` on Windows / `ifconfig` on macOS/Linux) — your phone and computer must be on the same network.

```bash
cd khata_app
flutter pub get
flutter run --dart-define=BACKEND_URL=http://<your-lan-ip>:8000
```

---

## Known limitations

- **Compound Urdu numbers** ("do hazar nau sau ninety nine") are sometimes misheard by the speech recognizer — mitigated by an editable amount field in every confirmation dialog, rather than trying to perfect voice number parsing.
- **Voice answers are Roman Urdu/English text + TTS** — a full bilingual UI toggle (Urdu/English) is a stretch goal, not yet complete.
- **No cloud backup/sync** — data lives on-device only (by design, for offline-first reliability); there's a manual "Clear old data" option in Settings.

---

## Team

Built for the **Bano Qabil x Alibaba Cloud AI Hackathon (Pakistan)**.

---

## Acknowledgments

- Powered by Alibaba Cloud's Qwen model family
- Built with the assistance of [Qoder](https://qoder.com), an AI-assisted IDE
