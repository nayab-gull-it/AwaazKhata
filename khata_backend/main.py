"""AwaazKhata Backend — voice command parser powered by Qwen via Groq.

The Flutter app sends a raw speech transcript to POST /parse-command.
This backend asks Qwen to extract a structured action (add inventory,
record or settle udhaar, create task, or navigate) and returns JSON that
the Flutter ParsedAction model can consume directly.
"""

from __future__ import annotations

import json
import logging
import re
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from groq import Groq
from pydantic import BaseModel
from pydantic_settings import BaseSettings

logger = logging.getLogger("khata_backend")

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

class Settings(BaseSettings):
    """Loaded from environment variables or a .env file."""

    groq_api_key: str = ""
    groq_model: str = "qwen/qwen3.8-27b"
    host: str = "0.0.0.0"
    port: int = 8000

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


settings = Settings()

# ---------------------------------------------------------------------------
# Groq client (created at startup, reused for all requests)
# ---------------------------------------------------------------------------

_groq_client: Groq | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global _groq_client
    if settings.groq_api_key and settings.groq_api_key != "gsk_your_key_here":
        _groq_client = Groq(api_key=settings.groq_api_key)
        logger.info("Groq client ready (model=%s)", settings.groq_model)
    else:
        logger.warning(
            "GROQ_API_KEY not set — /parse-command will use keyword fallback"
        )
    yield
    _groq_client = None


# ---------------------------------------------------------------------------
# FastAPI app
# ---------------------------------------------------------------------------

app = FastAPI(
    title="AwaazKhata Backend",
    description="Parses Urdu/English voice transcripts into structured shop actions",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# System prompt for Qwen
# ---------------------------------------------------------------------------

SYSTEM_PROMPT = """\
You are the backend parser for AwaazKhata, a voice-controlled shop management \
app for Pakistani retail shopkeepers. The user speaks in Urdu or English and \
you must decide what they intended.

Return ONLY a single JSON object (no markdown, no explanation) with these rules:

1. The "action" key must be exactly one of:
   - "query_balance"  — user is ASKING how much is owed/to-pay for a CUSTOMER (a QUESTION, not a write)
   - "query_item_stock" — user is ASKING whether a PRODUCT exists in stock / how much of it is in stock
   - "query_item_price" — user is ASKING the PRICE of a PRODUCT
   - "query_low_stock" — user is ASKING WHICH items/products are low on stock
   - "query_inventory_count" — user is ASKING HOW MANY items/products exist in total
   - "add_inventory"  — user wants to add/stock a product (no customer involved)
   - "add_udhaar"     — user wants to RECORD NEW credit for a customer (the amount they owe goes UP)
   - "reduce_udhaar"  — customer PAID BACK — user wants to REDUCE/settle an existing credit (the amount they owe goes DOWN)
   - "add_task"       — user wants to create a reminder or to-do
   - "navigate"       — user wants to switch to a tab (inventory, tasks, udhaar)

2. CLASSIFICATION RULES — follow these strictly, in this priority order:

   (a) navigate:
       Trigger ONLY when the user wants to OPEN/SHOW a tab — "inventory dikhao", \
       "tasks kholo", "udhaar tab le jao". No creation or query intent.

   (b) query_balance  — THIS IS A QUESTION, not an add:
       Trigger when the user ASKS about outstanding / remaining / balance / how much \
       for a customer. Look for question markers: "kitna", "kitne", "kya", "kaise", \
       question intonation, or words like "baaki", "baki", "outstanding", "balance", \
       "remaining", "lena hai", "dena hai", "hisab kya hai".
       Key phrases: "Ahmad ka kitna baaki hai", "Sara se kitna lena hai", \
       "Bashir ka balance batao", "Ali ke khate mein kitna hai", \
       "Rashid ko kitna dena hai".
       Output only the customer name — the app looks the balance up itself.
       This is NOT add_udhaar because no amount is being RECORDED; it is being ASKED.
       A question about a PRODUCT's price or stock is NOT query_balance — use \
       query_item_stock / query_item_price / query_low_stock / query_inventory_count \
       instead. A PERSON's name ("Ahmad", "Bashir bhai") means query_balance; a \
       PRODUCT name ("Tapal", "Shan biryani") means a query_item_* action.

   (c) query_item_stock — asking IF a product exists or HOW MANY are in stock:
       Trigger for questions about a product's availability or quantity: \
       "Tapal hai inventory mein?", "Nestle juice hai kya", "cheeni ka stock hai", \
       "do we have milk", "tel kitna stock hai". Look for "hai kya", "mujood", \
       "available", "stock hai", "inventory mein", "kitna stock".
       Output the product name in "name".

   (d) query_item_price — asking a PRODUCT's price:
       Trigger when the user asks what a product costs: "Shan biryani kitne ki hai", \
       "Tapal ka daam kya hai", "Nestle ka rate batao", "what's the price of sugar". \
       Look for "kitne ki", "kitne ka", "price", "daam", "qimat", "rate".
       Output the product name in "name".

   (e) query_low_stock — asking WHICH items are low on stock:
       Trigger for questions about items running low: "kaunse item ka stock kam hai", \
       "kitne items low stock mein hain", "kaun si cheez kam hai", \
       "which items are running low". Look for "kam"/"low" together with \
       item/stock words.
       No extra fields — the app lists its own low-stock items.

   (f) query_inventory_count — asking HOW MANY items exist in total:
       Trigger for total-count questions: "total kitne item hain", \
       "inventory mein kitne products hain", "how many items do I have". \
       Look for "total" or "kitne" together with item/product words.
       No extra fields — the app counts its own inventory.

   (g) add_task:
       Trigger when the transcript is about a REMINDER, TO-DO, or FUTURE ACTION.
       Look for words like "task", "reminder", "yaad", "banao/bana do", "karna hai", \
       "restock karne ka", "schedule", "subah/shaam ko", "roz/har roz", time \
       references, or any phrasing that asks someone to DO something later.
       The presence of a product name does NOT make it inventory — if the sentence \
       is about restocking, checking, or remembering, it is a task.

   (h) reduce_udhaar — customer PAID BACK / settled part of an existing credit:
       Trigger when the user wants an amount SUBTRACTED from a customer's \
       outstanding udhaar — the customer returned money. Look for words like \
       "kaat", "kaat do", "minus", "wapas", "jama", "chuka", "chukaya", \
       "clear", "settle", "paid", "payment", "return".
       Key phrases: "ka udhaar 500 kaat do", "ke hisab se 300 minus karo", \
       "ne 400 wapas kiye", "ka 1000 jama liya", "ka udhaar clear kar do".
       This is the OPPOSITE of add_udhaar — the outstanding amount goes DOWN. \
       If the customer is receiving NEW credit (amount goes up), use add_udhaar.

   (i) add_udhaar  — this is a WRITE/RECORD intent with a customer + money:
       Trigger ONLY when a CUSTOMER (person name, "khata/khate", "udhaar", "hisab", \
       "account", "credit") is explicitly involved AND an AMOUNT is being RECORDED \
       (mentioned or strongly implied) as NEW credit the customer now owes.
       Key phrases: "ke khate mein 500 add karo", "ka udhaar 500 likho", \
       "ko 1200 credit karo", "ke hisab mein 300 jor do", "itne rupaye daal do".
       If the sentence is a QUESTION about balance, prefer query_balance instead.
       If the user wants to REDUCE/settle an amount ("kaat", "minus", "wapas", \
       "jama", "chuka", "clear"), use reduce_udhaar instead.
       If there is no person/customer, it is NOT udhaar.

   (j) add_inventory:
       Trigger ONLY when the user wants to ADD/STOCK a physical product AND \
       NO customer is mentioned. Look for quantity + item + unit phrases like \
       "5 bottle tel", "do pack sabun add karo", "stock", "manga", "lao".
       If a person's name or "khata/udhaar/hisab" appears, prefer add_udhaar \
       or query_balance instead.

3. Additional keys depend on the action:

   query_balance:
     "customer_name" (string, required — transliterated to English), \
     "direction" (one of "outgoing" = customer owes the shop, \
     "incoming" = shop owes the customer; default "outgoing" if unclear)

   query_item_stock:
     "name" (string — the product the user is asking about)

   query_item_price:
     "name" (string — the product whose price is being asked)

   query_low_stock:
     (no extra fields)

   query_inventory_count:
     (no extra fields)

   add_inventory:
     "name" (string), "quantity" (integer), "unit" (string, e.g. "pcs", "kg", \
"bottle", "pack"), "category" (string), "purchase_price" (number), \
"sale_price" (number)

   add_udhaar:
     "customer_name" (string), "phone_number" (string or empty), \
"amount" (number — the NEW credit to add), "description" (string)

   reduce_udhaar:
     "customer_name" (string), "phone_number" (string or empty), \
"amount" (number — the amount to SUBTRACT), "description" (string)

   add_task:
     "title" (string), "description" (string)

   navigate:
     "target_tab" (one of "inventory", "tasks", "udhaar")

4. If you cannot determine the intent with confidence, return: \
   {"action": "unknown"}. Do NOT guess — returning unknown is preferred over a \
   wrong action.

5. Infer reasonable defaults when information is missing:
   - quantity defaults to 1
   - unit defaults to "pcs"
   - category defaults to "General"
   - prices default to 0 if not mentioned
   - direction defaults to "outgoing"

6. Respond in English for field values even if the transcript is in Urdu. \
   Transliterate Urdu names into English script.

FEW-SHOT EXAMPLES (study these carefully — they define the boundaries):

=== query_balance (QUESTION about outstanding; no amount is being recorded) ===

Transcript: "Ahmad ka kitna baaki hai"
{"action":"query_balance","customer_name":"Ahmad","direction":"outgoing"}

Transcript: "Sara se kitna lena hai"
{"action":"query_balance","customer_name":"Sara","direction":"incoming"}

Transcript: "Bashir bhai ka balance batao"
{"action":"query_balance","customer_name":"Bashir","direction":"outgoing"}

Transcript: "Ali ke khate mein kitna hai"
{"action":"query_balance","customer_name":"Ali","direction":"outgoing"}

Transcript: "Rashid ko kitna dena hai"
{"action":"query_balance","customer_name":"Rashid","direction":"incoming"}

Transcript: "Nadia ka udhaar kitna ho gaya"
{"action":"query_balance","customer_name":"Nadia","direction":"outgoing"}

Transcript: "Farhan bhai ke hisab ka status kya hai"
{"action":"query_balance","customer_name":"Farhan","direction":"outgoing"}

Transcript: "kitna outstanding hai Kamran ka"
{"action":"query_balance","customer_name":"Kamran","direction":"outgoing"}

Transcript: "what's Imran's balance"
{"action":"query_balance","customer_name":"Imran","direction":"outgoing"}

=== query_item_stock (asking IF a product exists / HOW MUCH is in stock) ===

Transcript: "Tapal hai inventory mein?"
{"action":"query_item_stock","name":"Tapal"}

Transcript: "Nestle juice hai kya"
{"action":"query_item_stock","name":"Nestle Juice"}

Transcript: "cheeni ka stock hai"
{"action":"query_item_stock","name":"Sugar"}

Transcript: "Surf Excel mujood hai"
{"action":"query_item_stock","name":"Surf Excel"}

Transcript: "tel kitna stock hai"
{"action":"query_item_stock","name":"Cooking Oil"}

Transcript: "do we have Shan biryani masala"
{"action":"query_item_stock","name":"Shan Biryani Masala"}

=== query_item_price (asking a PRODUCT's price) ===

Transcript: "Shan biryani kitne ki hai"
{"action":"query_item_price","name":"Shan Biryani"}

Transcript: "Tapal ka daam kya hai"
{"action":"query_item_price","name":"Tapal"}

Transcript: "cheeni kitne ki hai"
{"action":"query_item_price","name":"Sugar"}

Transcript: "Nestle Milkpak ka rate batao"
{"action":"query_item_price","name":"Nestle Milkpak"}

Transcript: "what's the price of Dalda oil"
{"action":"query_item_price","name":"Dalda Oil"}

=== query_low_stock (asking WHICH items are low on stock) ===

Transcript: "kaunse item ka stock kam hai"
{"action":"query_low_stock"}

Transcript: "kitne items low stock mein hain"
{"action":"query_low_stock"}

Transcript: "kaun si cheez kam hai"
{"action":"query_low_stock"}

Transcript: "which items are running low"
{"action":"query_low_stock"}

=== query_inventory_count (asking HOW MANY items exist in total) ===

Transcript: "total kitne item hain"
{"action":"query_inventory_count"}

Transcript: "inventory mein kitne products hain"
{"action":"query_inventory_count"}

Transcript: "kitne item total hain"
{"action":"query_inventory_count"}

Transcript: "how many items do I have"
{"action":"query_inventory_count"}

=== add_udhaar (RECORD credit/debt — customer + amount + write intent) ===

Transcript: "Ahmad ke khate mein 500 add karo"
{"action":"add_udhaar","customer_name":"Ahmad","phone_number":"","amount":500,"description":"Voice-recorded credit"}

Transcript: "Ahmed ka udhaar 500 rupaye likho"
{"action":"add_udhaar","customer_name":"Ahmed","phone_number":"","amount":500,"description":"Voice-recorded credit"}

Transcript: "Bashir bhai ko 1200 rupaye credit karo"
{"action":"add_udhaar","customer_name":"Bashir","phone_number":"","amount":1200,"description":"Voice-recorded credit"}

Transcript: "Ali ke hisab mein 300 jor do"
{"action":"add_udhaar","customer_name":"Ali","phone_number":"","amount":300,"description":"Voice-recorded credit"}

Transcript: "Nadia ko 250 dena hai likh do"
{"action":"add_udhaar","customer_name":"Nadia","phone_number":"","amount":250,"description":"Voice-recorded credit"}

Transcript: "Farhan se 800 udhaar liya note kar lo"
{"action":"add_udhaar","customer_name":"Farhan","phone_number":"","amount":800,"description":"Voice-recorded credit"}

Transcript: "Kamran ke account mein 1500 daal do"
{"action":"add_udhaar","customer_name":"Kamran","phone_number":"","amount":1500,"description":"Voice-recorded credit"}

Transcript: "record 2000 rupees owed by Imran"
{"action":"add_udhaar","customer_name":"Imran","phone_number":"","amount":2000,"description":"Voice-recorded credit"}

=== reduce_udhaar (customer PAID BACK — outstanding amount goes DOWN) ===

Transcript: "Ahmad Khan ka udhaar 500 kaat do"
{"action":"reduce_udhaar","customer_name":"Ahmad Khan","phone_number":"","amount":500,"description":"Voice-recorded payment"}

Transcript: "aaj Sara ne 400 wapas kiye hisab mein minus kar do"
{"action":"reduce_udhaar","customer_name":"Sara","phone_number":"","amount":400,"description":"Voice-recorded payment"}

Transcript: "Bilal ne 1000 rupaye jama kiye"
{"action":"reduce_udhaar","customer_name":"Bilal","phone_number":"","amount":1000,"description":"Voice-recorded payment"}

Transcript: "Ali ka udhaar clear kar do 700"
{"action":"reduce_udhaar","customer_name":"Ali","phone_number":"","amount":700,"description":"Voice-recorded payment"}

Transcript: "Kamran ka 300 udhaar minus karo"
{"action":"reduce_udhaar","customer_name":"Kamran","phone_number":"","amount":300,"description":"Voice-recorded payment"}

Transcript: "Imran ne 1500 chuka diye"
{"action":"reduce_udhaar","customer_name":"Imran","phone_number":"","amount":1500,"description":"Voice-recorded payment"}

=== add_inventory (product + quantity, no customer) ===

Transcript: "5 bottle tel add karo"
{"action":"add_inventory","name":"Cooking Oil","quantity":5,"unit":"bottle","category":"Grocery","purchase_price":0,"sale_price":0}

Transcript: "paanch bottle tel add karo"
{"action":"add_inventory","name":"Cooking Oil","quantity":5,"unit":"bottle","category":"Grocery","purchase_price":0,"sale_price":0}

Transcript: "do pack sabun stock karo"
{"action":"add_inventory","name":"Soap","quantity":2,"unit":"pack","category":"Grocery","purchase_price":0,"sale_price":0}

Transcript: "chini manga lao 10 kilo"
{"action":"add_inventory","name":"Sugar","quantity":10,"unit":"kg","category":"Grocery","purchase_price":0,"sale_price":0}

Transcript: "atta ka 20 kilo ka bag add karo"
{"action":"add_inventory","name":"Flour","quantity":20,"unit":"kg","category":"Grocery","purchase_price":0,"sale_price":0}

Transcript: "12 eggs ka carton le aao"
{"action":"add_inventory","name":"Eggs","quantity":12,"unit":"pcs","category":"Grocery","purchase_price":0,"sale_price":0}

Transcript: "naya stock daalo 3 dozen pepsi"
{"action":"add_inventory","name":"Pepsi","quantity":3,"unit":"dozen","category":"Beverages","purchase_price":0,"sale_price":0}

Transcript: "dal chana 5 kg mangwa lo"
{"action":"add_inventory","name":"Chana Dal","quantity":5,"unit":"kg","category":"Grocery","purchase_price":0,"sale_price":0}

Transcript: "add 2 packs of biscuits"
{"action":"add_inventory","name":"Biscuits","quantity":2,"unit":"pack","category":"Snacks","purchase_price":0,"sale_price":0}

Transcript: "doodh 6 litre include kar lo"
{"action":"add_inventory","name":"Milk","quantity":6,"unit":"liter","category":"Dairy","purchase_price":0,"sale_price":0}

=== add_task (reminder/to-do, even if it mentions a product) ===

Transcript: "chini restock karne ka task banao"
{"action":"add_task","title":"Restock sugar","description":"Voice reminder"}

Transcript: "kal subah 9 baje dukaan kholna hai"
{"action":"add_task","title":"Open shop at 9 AM","description":"Voice reminder"}

Transcript: "shaam ko supplier ko call karna yaad dilao"
{"action":"add_task","title":"Call supplier in the evening","description":"Voice reminder"}

Transcript: "har hafte stock check karna hai"
{"action":"add_task","title":"Weekly stock check","description":"Voice reminder"}

Transcript: "roz shaam 6 baje hisab band karna hai"
{"action":"add_task","title":"Close accounts daily at 6 PM","description":"Voice reminder"}

Transcript: "pehli tareekh ko rent dena yaad rakhna"
{"action":"add_task","title":"Pay rent on the 1st","description":"Voice reminder"}

Transcript: "agley hafte naya order place karna"
{"action":"add_task","title":"Place new order next week","description":"Voice reminder"}

Transcript: "reminder set karo bill pay karne ka"
{"action":"add_task","title":"Pay the bill","description":"Voice reminder"}

Transcript: "note kar lo customer ko discount dena hai"
{"action":"add_task","title":"Give discount to customer","description":"Voice reminder"}

Transcript: "tomorrow morning call the wholesaler"
{"action":"add_task","title":"Call the wholesaler tomorrow morning","description":"Voice reminder"}

=== navigate (open/show a tab, no creation or query) ===

Transcript: "inventory dikhao"
{"action":"navigate","target_tab":"inventory"}

Transcript: "udhaar tab kholo"
{"action":"navigate","target_tab":"udhaar"}

Transcript: "tasks dikha do"
{"action":"navigate","target_tab":"tasks"}

Transcript: "stock page pe le jao"
{"action":"navigate","target_tab":"inventory"}

Transcript: "mere kaam ki list kholo"
{"action":"navigate","target_tab":"tasks"}

Transcript: "udhaar ki list dikhao"
{"action":"navigate","target_tab":"udhaar"}

Transcript: "open the inventory tab"
{"action":"navigate","target_tab":"inventory"}

Transcript: "switch to tasks"
{"action":"navigate","target_tab":"tasks"}
"""

# ---------------------------------------------------------------------------
# Request / response models
# ---------------------------------------------------------------------------


class CommandRequest(BaseModel):
    transcript: str


# ---------------------------------------------------------------------------
# Endpoint
# ---------------------------------------------------------------------------


@app.post("/parse-command")
async def parse_command(req: CommandRequest):
    """Parse a voice transcript into a structured action via Qwen/Groq.

    Falls back to keyword matching when Groq is unavailable.
    """
    transcript = req.transcript.strip()
    if not transcript:
        raise HTTPException(status_code=400, detail="Transcript is empty")

    logger.info("Parsing transcript: %r", transcript)

    # Try Qwen via Groq first
    if _groq_client is not None:
        try:
            result = await _call_groq(transcript)
            logger.info("Groq result: %s", result)
            return result
        except Exception:
            logger.exception("Groq call failed, falling back to keywords")

    # Fallback: keyword-based parser
    result = _keyword_fallback(transcript)
    logger.info("Fallback result: %s", result)
    return result


# ---------------------------------------------------------------------------
# Groq call
# ---------------------------------------------------------------------------


async def _call_groq(transcript: str) -> dict:
    """Send the transcript to Qwen via Groq and parse the JSON response."""
    assert _groq_client is not None

    response = _groq_client.chat.completions.create(
        model=settings.groq_model,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": transcript},
        ],
        temperature=0.1,
        max_tokens=512,
        response_format={"type": "json_object"},
    )

    raw = response.choices[0].message.content or ""
    return _extract_json(raw)


def _extract_json(raw: str) -> dict:
    """Extract a JSON object from the model's response.

    Handles cases where the model wraps JSON in markdown code blocks.
    """
    # Strip markdown fences if present
    cleaned = raw.strip()
    if cleaned.startswith("```"):
        cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned)
        cleaned = re.sub(r"\s*```$", "", cleaned)

    parsed = json.loads(cleaned)
    if not isinstance(parsed, dict) or "action" not in parsed:
        raise ValueError(f"Invalid response shape: {parsed}")

    return parsed


# ---------------------------------------------------------------------------
# Keyword fallback (works without Groq for local testing)
# ---------------------------------------------------------------------------


def _keyword_fallback(transcript: str) -> dict:
    """Simple keyword-based intent detection for when Groq is unavailable.

    Priority: navigate > query_low_stock > query_inventory_count
    > query_item_price > query_item_stock > query_balance > add_task
    > reduce_udhaar > add_udhaar > add_inventory > unknown.
    The query_* branches come BEFORE query_balance because "kitne" questions
    about products ("total kitne item hain", "Shan biryani kitne ki hai")
    would otherwise be swallowed by query_balance's question markers, and
    before add_inventory because "kaunse item ka stock kam hai" mentions
    "stock" but is a question, not a restock. Query-balance still beats
    add_udhaar because "kitna/baki/balance" questions are distinct from
    recording entries. Task beats inventory because sentences like
    "chini restock karne ka task banao" mention a product but are still
    reminders. Reduce beats add because "kaat/minus/wapas/jama" sentences
    mention udhaar but must subtract, not record new credit. Udhaar beats
    inventory because the presence of a customer name or "khata/udhaar/hisab"
    flips the intent from stocking to credit.
    """
    t = transcript.lower()
    # Tokenize — split on whitespace + strip punctuation for stable word matches.
    tokens = [tok.strip(".,!?;:") for tok in re.findall(r"[\w']+", t, re.UNICODE)]
    tok_set = set(tokens)

    # Navigation (must come first — "inventory dikhao" should not become add_inventory)
    nav_verbs = {"dikhao", "dikha", "kholo", "open", "go", "jao", "show"}
    if nav_verbs & tok_set:
        if {"inventory", "stock", "samaan"} & tok_set:
            return {"action": "navigate", "target_tab": "inventory"}
        if {"task", "tasks", "reminder", "reminders", "kaam"} & tok_set:
            return {"action": "navigate", "target_tab": "tasks"}
        if {"udhaar", "credit", "khata", "khate", "hisab", "hisaab"} & tok_set:
            return {"action": "navigate", "target_tab": "udhaar"}

    item_words = {"item", "items", "product", "products", "cheez", "cheezein"}
    stock_words = {"stock", "inventory", "samaan"}

    # Low-stock question — "kaunse item ka stock kam hai" mentions "stock"
    # but is a question; must not fall through to add_inventory.
    if ({"kam", "low"} & tok_set) and (
        (item_words & tok_set) or (stock_words & tok_set)
    ):
        return {"action": "query_low_stock"}

    # Inventory total-count question — "total kitne item hain".
    if ({"total", "kitne", "kitna"} & tok_set) and (item_words & tok_set):
        return {"action": "query_inventory_count"}

    # Item price question — "Shan biryani kitne ki hai", "Tapal ka daam kya hai".
    price_words = {"price", "daam", "dam", "qimat", "kimat", "rate"}
    if (price_words & tok_set) or any(
        p in t for p in ("kitne ki", "kitne ka", "kitni ki", "kitni ka")
    ):
        return {
            "action": "query_item_price",
            "name": _extract_query_name(transcript) or "Unknown",
        }

    # Item existence/stock question — "Tapal hai inventory mein?", "juice hai kya".
    if (
        ("hai kya" in t)
        or ({"mujood", "maujood", "available"} & tok_set)
        or ((stock_words & tok_set) and ({"hai", "hain", "tha"} & tok_set))
    ):
        return {
            "action": "query_item_stock",
            "name": _extract_query_name(transcript) or "Unknown",
        }

    # Query balance — question about outstanding / remaining / balance.
    # Beats add_udhaar because "Ahmad ka kitna baaki hai" must NOT record a new entry.
    question_markers = {"kitna", "kitne", "kitni", "balance", "baki", "baaki",
                        "remaining", "outstanding", "pending", "status"}
    question_phrases = (
        "kitna baaki", "kitna baki", "kitna hai", "kitne hai", "kitne hain",
        "kitna dena", "kitna lena", "kitna udhaar", "kitna hisab",
        "ka balance", "ki balance", "ke balance",
        "what's", "whats", "how much",
    )
    if (question_markers & tok_set) or any(p in t for p in question_phrases):
        name = _extract_name(transcript)
        # "X se ... lena" -> shop collects from customer (incoming).
        # "X ko ... dena" / default -> customer owes shop (outgoing).
        direction = "incoming" if "se" in tok_set else "outgoing"
        return {
            "action": "query_balance",
            "customer_name": name or "Unknown",
            "direction": direction,
        }

    # Task — reminder / to-do intent. Includes multi-word phrases (kept as
    # substring checks) and single-word time markers (token checks).
    task_phrases = (
        "restock karne ka", "check karna", "karna hai", "bana do", "bana dena",
        "likh do", "note kar", "yaad dilao",
    )
    task_words = {
        "task", "tasks", "reminder", "reminders", "yaad", "schedule",
        "banao", "subah", "shaam", "sham", "baje", "kal", "hafte",
        "roz", "daily", "weekly",
    }
    if any(p in t for p in task_phrases) or (task_words & tok_set):
        return {
            "action": "add_task",
            "title": transcript[:60],
            "description": "Voice reminder",
        }

    # Reduce udhaar — customer paid back / settled part of an existing credit.
    # Checked BEFORE add_udhaar because "udhaar 500 kaat do" mentions udhaar
    # (an add signal) but the intent is to subtract, not record new credit.
    reduce_signals = {
        "kaat", "kaato", "minus", "wapas", "jama", "chuka", "chukao",
        "chukaya", "clear", "cleared", "settle", "settled", "paid",
        "payment", "return", "returned",
    }
    if reduce_signals & tok_set:
        name = _extract_name(transcript)
        amount = _extract_number(t) or 0.0
        return {
            "action": "reduce_udhaar",
            "customer_name": name or "Unknown",
            "phone_number": "",
            "amount": float(amount),
            "description": "Voice-recorded payment",
        }

    # Udhaar — customer/account + money. Check BEFORE inventory so
    # "Ahmad ke khate mein 500 add karo" doesn't become an inventory add.
    udhaar_signals = {
        "udhaar", "khata", "khate", "hisab", "hisaab", "credit", "dena", "owe",
    }
    if (udhaar_signals & tok_set) or ("khata mein" in t) or ("khate mein" in t):
        name = _extract_name(transcript)
        amount = _extract_number(t) or 0.0
        return {
            "action": "add_udhaar",
            "customer_name": name or "Unknown",
            "phone_number": "",
            "amount": float(amount),
            "description": "Voice-recorded credit",
        }

    # Inventory — product + quantity, no customer.
    inventory_words = {"add", "stock", "manga", "lao", "include", "restock"}
    if inventory_words & tok_set:
        name = _extract_name(transcript)
        quantity = _extract_number(t) or 1
        unit = _extract_unit(t)
        return {
            "action": "add_inventory",
            "name": name or "New Item",
            "quantity": quantity,
            "unit": unit,
            "category": "General",
            "purchase_price": 0,
            "sale_price": 0,
        }

    return {"action": "unknown"}


def _extract_number(text: str) -> int | float | None:
    """Pull the first number from the text."""
    match = re.search(r"\d+", text)
    if match:
        return int(match.group())

    # Urdu/Hindi number words
    word_map = {
        "ek": 1, "do": 2, "teen": 3, "char": 4, "panch": 5,
        "che": 6, "saat": 7, "aath": 8, "nau": 9, "das": 10,
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
    }
    for word, num in word_map.items():
        if word in text:
            return num
    return None


def _extract_unit(text: str) -> str:
    """Detect the unit of measurement from the text."""
    units = [
        "bottle", "bottles", "pack", "packs", "kg", "gram", "gram",
        "liter", "litre", "dozen", "piece", "pieces", "pcs", "box", "boxes",
        "carton", "cartons", "tin", "tins",
    ]
    for unit in units:
        if unit in text:
            return unit.rstrip("s") if unit.endswith("s") and unit != "pcs" else unit
    return "pcs"


def _extract_name(text: str) -> str | None:
    """Try to extract a product or person name (rough heuristic).

    Handles Urdu particles "ke/ka/ki/ko/se/ne" and honorifics like "bhai"
    that commonly follow a person's name in shopkeeper speech. Captures up
    to two words so full names like "Ahmad Khan" survive. Case-insensitive
    because ASR transcripts often come back lowercased.
    """
    name_word = r"[A-Za-z\u0600-\u06FF]+"
    particles = r"(?:ke|ka|ki|ko|se|ne|for|of)"
    patterns = [
        # Name (one or two words, optionally followed by an honorific) then a
        # particle — "Ahmad Khan ka ...", "Bashir bhai ko ...", "Sara ne ...".
        rf"\b({name_word}(?:\s+{name_word})?)"
        rf"(?:\s+(?:bhai|bibi|sahab|beta|uncle|aunty))?"
        rf"\s+{particles}\b",
        # Fallback: word(s) after a particle
        rf"{particles}\s+({name_word}(?:\s+{name_word})?)",
    ]
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            name = match.group(1).strip()
            # Drop leading time words — "aaj Sara ne ..." must yield "Sara".
            time_words = {"aaj", "kal", "subah", "shaam", "sham", "abhi", "phir"}
            words = [w for w in name.split()]
            while words and words[0].lower() in time_words:
                words = words[1:]
            name = " ".join(words)
            if not name:
                continue
            # Skip common Urdu function words that the regex may accidentally grab
            stopwords = {
                "ke", "ka", "ki", "ko", "se", "ne", "mein", "par", "pe", "tak",
                "aur", "ya", "magar", "lekin", "bhi", "hi", "nahi",
                "karo", "karna", "hai", "hain", "tha", "the", "thi",
                "for", "of", "the", "to", "in", "on", "at", "and", "or",
                "bhai", "bibi", "sahab", "beta", "uncle", "aunty",
            }
            if name.lower() in stopwords:
                continue
            return name.title()
    return None


def _extract_query_name(text: str) -> str | None:
    """Extract a product name from a QUESTION transcript.

    Question phrasing usually has no ownership particles ("Tapal hai inventory
    mein?"), so unlike [_extract_name] this takes the words BEFORE the first
    question/verb token ("hai", "kya", "kitne"...) and drops function words.
    """
    tokens = [
        tok.strip(".,!?;:")
        for tok in re.findall(r"[\w']+", text.lower(), re.UNICODE)
    ]
    # Cut at the first question/verb token — the product name precedes it.
    for i, tok in enumerate(tokens):
        if tok in {"hai", "hain", "tha", "kya", "kitna", "kitne", "kitni"}:
            tokens = tokens[:i]
            break
    stopwords = {
        "hai", "hain", "tha", "the", "thi", "kya", "kaun", "kaunse", "kaunsi",
        "si", "kitna", "kitne", "kitni", "mein", "par", "pe", "tak", "bhi",
        "ka", "ke", "ki", "ko", "se", "ne", "aur", "ya", "of", "the", "to",
        "in", "on", "at", "is", "are", "do", "does", "we", "have", "has",
        "what", "whats", "what's", "how", "many", "much", "any",
        "total", "item", "items", "product", "products", "cheez", "cheezein",
        "stock", "inventory", "samaan", "mujood", "maujood", "available",
        "low", "kam", "price", "daam", "dam", "qimat", "kimat", "rate",
        "batao", "bata", "karo", "kar", "karna", "karne", "dikha", "dikhao",
    }
    words = [w for w in tokens if w not in stopwords and not w.isdigit()]
    if not words:
        return None
    return " ".join(words[:3]).title()


# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------


@app.get("/health")
async def health():
    return {
        "status": "ok",
        "groq_connected": _groq_client is not None,
        "model": settings.groq_model,
    }


# ---------------------------------------------------------------------------
# Entry point (for `python main.py`)
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import uvicorn

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    uvicorn.run("main:app", host=settings.host, port=settings.port, reload=True)
