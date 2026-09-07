# AwaazKhata — Agent Notes

Two-package repo. Keep changes scoped to the package you're touching.

- `khata_app/` — Flutter mobile app (voice-first shop ledger)
- `khata_backend/` — FastAPI service that parses Urdu/English voice transcripts into structured actions via Groq/Qwen

## Flutter app (`khata_app/`)

- Entry point: `lib/main.dart` → `AwaazKhataApp` → `SplashScreen` → `LoginScreen` / `HomeScreen`
- State management: `Provider`, global state is `lib/providers/app_state.dart`
- Architecture: `screens/` + `providers/` + `services/` + `models/` + `widgets/`
- Key dependencies: `speech_to_text`, `http`, `provider`, `intl`, `permission_handler`, `shared_preferences`, `url_launcher`, `hive`, `hive_flutter`

### Common commands
Run from `khata_app/`:

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

### Test coverage note
`test/widget_test.dart` is a minimal placeholder (only checks that `MaterialApp` renders). It is not meaningful coverage; real app logic is currently untested.

### Voice / backend integration gotchas
- The app never calls the AI directly. All transcripts go to the backend `POST /parse-command`.
- Backend URL defaults to `http://10.0.2.2:8000` (Android emulator localhost). Override at build time with `--dart-define=BACKEND_URL=http://...`.
- `lib/config/app_config.dart` currently sets `appLocale = 'en_US'` as a temporary test value; the intended locale for Urdu commands is `ur_PK`.
- `lib/services/speech_service.dart` currently uses `ListenMode.dictation` as a temporary test value; intended mode is `ListenMode.confirmation`.
- Local persistence uses Hive (`hive`, `hive_flutter`). `StorageService` stores JSON-encoded lists in boxes; `AppState` loads on startup and writes through on every mutation. Dummy data is seeded only when all three boxes are empty (first install / after "Clear old data").
- Models have `toJson()` / `fromJson()` factories for Hive serialization; add corresponding fields there if you extend a model.
- The settings dialog has a "Clear old data" button that wipes all Hive boxes and in-memory lists after confirmation.

### Lint / analysis
- Uses `package:flutter_lints/flutter.yaml`.
- Analyzer excludes generated platform directories (`android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`, `build/`).

## Backend (`khata_backend/`)

- Entry point: `main.py` — runs a FastAPI app on `0.0.0.0:8000` by default
- Main endpoint: `POST /parse-command`
- Health check: `GET /health`
- Model: exactly `qwen/qwen3.8-27b` via Groq (as declared in `main.py`)

### Setup
Run from `khata_backend/`:

```bash
python -m venv .venv
.venv\Scripts\activate        # Windows
# source .venv/bin/activate   # macOS/Linux
pip install -r requirements.txt
copy .env.example .env        # then add your real GROQ_API_KEY
python main.py
```

### Environment
- Reads `.env` via `pydantic-settings`. `GROQ_API_KEY` is required for the AI path.
- If `GROQ_API_KEY` is missing or still set to the placeholder `gsk_your_key_here`, `/parse-command` falls back to a local keyword parser.
- CORS is currently open (`allow_origins=["*"]`) — dev only; tighten before production.

### Testing classification
Run from `khata_backend/`:

```bash
# Keyword fallback only (no API key needed)
python test_classification.py

# Include Groq/Qwen path (slower, requires key)
python test_classification.py --groq-only
GROQ_API_KEY=gsk_... python test_classification.py

# Adjust timeout if Groq is slow
python test_classification.py --per-call-timeout 120
```

### Backend response contract
The backend returns JSON with an `action` key. Allowed actions are defined in `khata_app/lib/models/parsed_action.dart`:

`add_inventory`, `add_udhaar`, `reduce_udhaar`, `add_task`, `query_balance`, `query_item_stock`, `query_item_price`, `query_low_stock`, `query_inventory_count`, `navigate`, `unknown`

If you add a new action, update both the backend prompt/system in `main.py` and the Flutter `VoiceActionType` enum + handling in `HomeScreen`/`ParsedAction`.

## Repo conventions

- No real authentication; login is just a shop name + optional phone stored locally via `SharedPreferences`.
- Currency is Pakistani Rupees (Rs.).
- Name matching is fuzzy (Levenshtein + prefix + word-subset) because ASR transcripts vary in spelling (`Ahmad` vs `Ahmed`).
- No CI, no pre-commit hooks, no Makefile. Verify with `flutter analyze` + `python test_classification.py`.
