 
from fastapi import FastAPI, UploadFile, File, Form
from fastapi.responses import JSONResponse
from deepface import DeepFace
from scipy.spatial.distance import cosine
from PIL import Image
import numpy as np
import io
import json
import mysql.connector
import os
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()

THRESHOLD = 0.30  # Facenet threshold

# ─── DB CONNECTION ───────────────────────────────────
def get_db():
    return mysql.connector.connect(
        host=os.getenv("DB_HOST", "localhost"),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASS", "2026"),
        database=os.getenv("DB_NAME", "global_app")
    )

# ─── LOAD IMAGE ─────────────────────────────────────
def load_image(file_bytes):
    image = Image.open(io.BytesIO(file_bytes)).convert("RGB")
    return np.array(image)

# ─── NORMALIZE ───────────────────────────────────────
def normalize(vec):
    arr = np.array(vec)
    norm = np.linalg.norm(arr)
    return arr if norm == 0 else arr / norm


# ════════════════════════════════════════════════════
# FUNCTION 1: IMAGE → VECTOR (called on employee photo upload)
# POST /embedding
# Returns 128-dim Facenet vector
# ════════════════════════════════════════════════════
@app.post("/embedding")
async def get_embedding(file: UploadFile = File(...)):
    try:
        contents = await file.read()
        image_np = load_image(contents)

        result = DeepFace.represent(
            img_path=image_np,
            model_name="Facenet",
            enforce_detection=False,
            align=True
        )

        embedding = result[0]["embedding"]
        return {"success": True, "embedding": embedding}

    except Exception as e:
        return JSONResponse(
            status_code=400,
            content={"success": False, "error": str(e)}
        )


# ════════════════════════════════════════════════════
# FUNCTION 2: COMPARE LIVE PHOTO vs STORED VECTOR
# POST /compare
# Body: multipart form
#   - file: live captured image
#   - emp_id: employee id to fetch their stored embedding from DB
# ════════════════════════════════════════════════════
@app.post("/compare")
async def compare_face(
    file: UploadFile = File(...),
    emp_id: int = Form(...)        # ✅ uses emp_id to fetch correct employee embedding
):
    try:
        # ── Step 1: Fetch stored embedding for this specific emp_id ──
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
            return JSONResponse(
                status_code=404,
                content={"success": False, "error": f"No embedding found for emp_id {emp_id}"}
            )

        emp_name = f"{row['first_name']} {row['last_name']}".strip()

        # Parse stored embedding
        stored_raw = row["face_embedding"]
        if isinstance(stored_raw, str):
            ref_vec = json.loads(stored_raw)
        else:
            ref_vec = stored_raw  # already list

        ref_norm = normalize(ref_vec)

        # ── Step 2: Generate embedding from live photo ──
        contents = await file.read()
        image_np = load_image(contents)

        try:
            # Strict detection for live capture
            result = DeepFace.represent(
                img_path=image_np,
                model_name="Facenet",          # ✅ same model as stored
                enforce_detection=True,
                align=True,
                detector_backend="retinaface"  # best accuracy
            )
            live_vec = result[0]["embedding"]
            live_norm = normalize(live_vec)

        except Exception:
            # Face not clearly detected
            return JSONResponse(
                status_code=200,
                content={
                    "success": True,
                    "match": False,
                    "confidence": 0,
                    "distance": None,
                    "emp_id": emp_id,
                    "emp_name": emp_name,
                    "reason": "No clear face detected. Look directly at camera."
                }
            )

        # ── Step 3: Compare ── 
        distance = float(cosine(ref_norm, live_norm))
        confidence = max(0, min(100, int((1 - distance) * 100)))

        # Two-level decision (production-safe)
        if distance < 0.30:
            match = True
            reason = "Face matched"
        elif distance < 0.45:
            match = True
            reason = "Face matched"
        else:
            match = False
            reason = "Face not matched"

        print(f"[emp_id={emp_id}] [{emp_name}] Distance: {distance:.4f} → {'✅ MATCH' if match else '❌ NO MATCH'} ({confidence}%)")

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
        return JSONResponse(
            status_code=500,
            content={"success": False, "error": str(e)}
        )
    


# uvicorn face_service:app --host 0.0.0.0 --port 8000