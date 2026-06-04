import sys
import os

# ✅ Fix Windows CP1252 encoding crash from DeepFace emoji logs
sys.stdout.reconfigure(encoding='utf-8')
os.environ["PYTHONIOENCODING"] = "utf-8"

from fastapi import FastAPI, UploadFile, File, Form
from fastapi.responses import JSONResponse
from deepface import DeepFace
from scipy.spatial.distance import cosine
from PIL import Image
import numpy as np
import io
import json
import cv2
import mysql.connector
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()

def get_db():
    return mysql.connector.connect(
        host=os.getenv("DB_HOST", "localhost"),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASS", "2026"),
        database=os.getenv("DB_NAME", "global_app")
    )

def normalize(vec):
    arr = np.array(vec)
    norm = np.linalg.norm(arr)
    return arr if norm == 0 else arr / norm

def load_image(file_bytes):
    image = Image.open(io.BytesIO(file_bytes)).convert("RGB")
    w, h = image.size
    if max(w, h) > 640:
        scale = 640 / max(w, h)
        image = image.resize((int(w * scale), int(h * scale)), Image.LANCZOS)
    return np.array(image)

def enhance_for_detection(img_np):
    lab = cv2.cvtColor(img_np, cv2.COLOR_RGB2LAB)
    l, a, b = cv2.split(lab)
    mean_l = float(np.mean(l))
    print(f"[enhance] mean_brightness={mean_l:.1f}")

    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    l_eq = clahe.apply(l)

    if mean_l < 80:
        gamma = 1.8
        table = np.array([
            min(255, int((i / 255.0) ** (1.0 / gamma) * 255))
            for i in range(256)
        ], dtype=np.uint8)
        l_eq = cv2.LUT(l_eq, table)
        print("[enhance] Applied gamma boost")

    lab_eq = cv2.merge((l_eq, a, b))
    return cv2.cvtColor(lab_eq, cv2.COLOR_LAB2RGB)


# ✅ Only use detectors whose weights are already downloaded locally
# SSD requires deploy.prototxt from GitHub — skip it if not available
def get_available_detectors():
    """
    Check which detectors have their weights already on disk.
    Only use what's available — never try to download at runtime.
    """
    weights_dir = os.path.join(os.path.expanduser("~"), ".deepface", "weights")
    available = []

    # opencv — uses built-in haarcascade, always available
    available.append("opencv")

    # mtcnn — uses pip package, always available if installed
    try:
        import mtcnn
        available.append("mtcnn")
    except ImportError:
        print("[detectors] mtcnn not installed, skipping")

    # ssd — needs deploy.prototxt + res10 weights
    ssd_files = ["deploy.prototxt", "res10_300x300_ssd_iter_140000.caffemodel"]
    if all(os.path.exists(os.path.join(weights_dir, f)) for f in ssd_files):
        available.append("ssd")
    else:
        print(f"[detectors] SSD weights missing from {weights_dir}, skipping")

    # retinaface — needs retinaface weights
    retinaface_file = os.path.join(weights_dir, "retinaface.h5")
    if os.path.exists(retinaface_file):
        available.append("retinaface")
    else:
        print("[detectors] retinaface weights missing, skipping")

    print(f"[detectors] Available: {available}")
    return available


AVAILABLE_DETECTORS = []  # filled at startup


@app.on_event("startup")
async def warmup():
    global AVAILABLE_DETECTORS
    print("[startup] Warming up Facenet512...")
    try:
        dummy = np.zeros((160, 160, 3), dtype=np.uint8)
        DeepFace.represent(
            img_path=dummy,
            model_name="Facenet512",
            enforce_detection=False,
            align=False,
            detector_backend="opencv",
        )
        print("[startup] Model ready.")
    except Exception as e:
        print(f"[startup] Warmup error (non-fatal): {e}")

    AVAILABLE_DETECTORS = get_available_detectors()


# ════════════════════════════════════════════════════
# POST /embedding
# ════════════════════════════════════════════════════
@app.post("/embedding")
async def get_embedding(file: UploadFile = File(...)):
    try:
        contents = await file.read()
        img_np = load_image(contents)
        img_enhanced = enhance_for_detection(img_np)

        for attempt, image in enumerate([img_np, img_enhanced]):
            try:
                result = DeepFace.represent(
                    img_path=image,
                    model_name="Facenet512",
                    enforce_detection=True,
                    align=True,
                    detector_backend="opencv",
                )
                print(f"[embedding] Success on attempt {attempt + 1}")
                return {"success": True, "embedding": result[0]["embedding"]}
            except Exception as e:
                print(f"[embedding] attempt {attempt + 1} failed: {type(e).__name__}")
                continue

        return JSONResponse(
            status_code=400,
            content={"success": False, "error": "No face detected in photo"}
        )

    except Exception as e:
        print(f"[embedding] Error: {type(e).__name__}: {e}")
        return JSONResponse(
            status_code=400,
            content={"success": False, "error": str(e)}
        )


# ════════════════════════════════════════════════════
# POST /compare
# ════════════════════════════════════════════════════
@app.post("/compare")
async def compare_face(
    file: UploadFile = File(...),
    emp_id: int = Form(...)
):
    try:
        # ── Fetch stored embedding ──────────────────────────────────────────
        db = get_db()
        cursor = db.cursor(dictionary=True)
        cursor.execute(
            "SELECT first_name, last_name, face_embedding FROM employee_master WHERE emp_id = %s",
            (emp_id,)
        )
        row = cursor.fetchone()
        cursor.close()
        db.close()

        if not row or not row["face_embedding"]:
            return JSONResponse(status_code=404, content={
                "success": False,
                "error": f"No embedding for emp_id {emp_id}"
            })

        emp_name = f"{row['first_name']} {row['last_name']}".strip()
        stored_raw = row["face_embedding"]
        ref_vec = json.loads(stored_raw) if isinstance(stored_raw, str) else stored_raw
        ref_norm = normalize(ref_vec)

        print(f"[compare] emp_id={emp_id} name={emp_name} stored_dim={len(ref_vec)}")

        # ── Load + enhance live image ───────────────────────────────────────
        contents = await file.read()
        img_np = load_image(contents)
        img_enhanced = enhance_for_detection(img_np)

        print(f"[compare] shape={img_np.shape} brightness={img_np.mean():.1f}")

        # ── Try detectors — only ones with weights available ────────────────
        live_vec = None
        detectors = AVAILABLE_DETECTORS or ["opencv"]  # fallback if startup missed

        for detector in detectors:
            for img_variant, label in [(img_enhanced, "enhanced"), (img_np, "raw")]:
                try:
                    result = DeepFace.represent(
                        img_path=img_variant,
                        model_name="Facenet512",
                        enforce_detection=True,
                        align=True,
                        detector_backend=detector,
                    )
                    live_vec = result[0]["embedding"]
                    print(f"[compare] emp_id={emp_id} OK detector={detector} img={label}")
                    break
                except Exception as e:
                    # ✅ No emoji in print — safe on Windows CP1252
                    print(f"[compare] emp_id={emp_id} FAIL detector={detector} img={label} err={type(e).__name__}")
                    continue
            if live_vec is not None:
                break

        # ── Last resort: enforce_detection=False ────────────────────────────
        # If all detectors fail, try without strict detection
        # This almost always works but may use background as face region
        if live_vec is None:
            print(f"[compare] emp_id={emp_id} trying enforce_detection=False as last resort")
            try:
                result = DeepFace.represent(
                    img_path=img_enhanced,
                    model_name="Facenet512",
                    enforce_detection=False,
                    align=True,
                    detector_backend="opencv",
                )
                live_vec = result[0]["embedding"]
                print(f"[compare] emp_id={emp_id} got embedding via no-enforce fallback")
            except Exception as e:
                print(f"[compare] emp_id={emp_id} no-enforce fallback also failed: {type(e).__name__}")

        if live_vec is None:
            return JSONResponse(status_code=200, content={
                "success": True,
                "match": False,
                "confidence": 0,
                "distance": None,
                "emp_id": emp_id,
                "emp_name": emp_name,
                "reason": "No clear face detected. Ensure good lighting and look straight at camera."
            })

        # ── Compare ─────────────────────────────────────────────────────────
        live_norm = normalize(live_vec)
        distance = float(cosine(ref_norm, live_norm))
        confidence = max(0, min(100, int((1 - distance) * 100)))

        if distance < 0.30:
            match, reason = True, "Strong match"
        elif distance < 0.50:
            match, reason = True, "Acceptable match"
        else:
            match, reason = False, "Face not matched"

        print(f"[compare] emp_id={emp_id} dist={distance:.4f} conf={confidence}% match={match}")

        return {
            "success": True,
            "match": match,
            "distance": round(distance, 6),
            "confidence": confidence,
            "emp_id": emp_id,
            "emp_name": emp_name,
            "reason": reason,
        }

    except Exception as e:
        print(f"[compare] emp_id={emp_id} EXCEPTION: {type(e).__name__}: {e}")
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})


@app.get("/health")
async def health():
    return {
        "status": "ok",
        "model": "Facenet512",
        "available_detectors": AVAILABLE_DETECTORS
    }

# Run with:
# uvicorn face_service:app --host 0.0.0.0 --port 8000 --workers 1