from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import torch
from transformers import AutoTokenizer, AutoModelForSequenceClassification

# --------------------------------------------------
# Sabitler
# --------------------------------------------------
MODEL_PATH = "emotion_tr_bert"

# Duygu → Risk seviyesi eşlemesi
RISK_MAP = {
    "Mutluluk":        "low",
    "Arzu":            "low",
    "Nötr":            "low",
    "Korku":           "medium",
    "Şaşkınlık":       "medium",
    "Kafa Karışıklığı": "medium",
    "Öfke":            "medium",
    "Üzüntü":          "high",
    "İğrenme":         "high",
    "Tiksinme":        "high",
}

# --------------------------------------------------
# Model yükleme (uygulama başlarken bir kez)
# --------------------------------------------------
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

try:
    tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH)
    model = AutoModelForSequenceClassification.from_pretrained(MODEL_PATH)
    model.to(device)
    model.eval()
    print(f"Model '{MODEL_PATH}' başarıyla yüklendi. Cihaz: {device}")
except Exception as load_err:
    tokenizer = None
    model = None
    print(f"[UYARI] Model yüklenemedi: {load_err}")
    print("Lütfen önce train.py çalıştırarak modeli eğitin.")

# --------------------------------------------------
# FastAPI uygulaması
# --------------------------------------------------
app = FastAPI(title="Duygu Analizi API", version="1.0")

# --------------------------------------------------
# Veri modelleri
# --------------------------------------------------
class EmotionRequest(BaseModel):
    text: str

class EmotionResponse(BaseModel):
    emotion: str
    risk_level: str
    confidence: float

# --------------------------------------------------
# Yardımcı: tahmin
# --------------------------------------------------
def predict_emotion(text: str) -> dict:
    if model is None or tokenizer is None:
        raise RuntimeError(
            "Model yüklü değil. Önce 'train.py' çalıştırarak modeli eğitin."
        )

    inputs = tokenizer(
        text,
        return_tensors="pt",
        truncation=True,
        padding=True,
        max_length=128
    ).to(device)

    with torch.no_grad():
        outputs = model(**inputs)

    probs = torch.softmax(outputs.logits, dim=1)
    pred_id = torch.argmax(probs, dim=1).item()
    confidence = probs[0][pred_id].item()

    emotion = model.config.id2label[pred_id]
    risk_level = RISK_MAP.get(emotion, "medium")

    return {
        "emotion": emotion,
        "risk_level": risk_level,
        "confidence": round(confidence, 4)
    }

# --------------------------------------------------
# Endpoint'ler
# --------------------------------------------------

@app.get("/")
async def root():
    return {"status": "ok", "message": "Duygu Analizi API çalışıyor."}


@app.get("/health")
async def health():
    return {
        "model_loaded": model is not None,
        "device": str(device)
    }


@app.post("/analyze-emotion", response_model=EmotionResponse)
async def analyze_emotion(request: EmotionRequest):
    if not request.text.strip():
        raise HTTPException(status_code=400, detail="Metin boş olamaz.")
    try:
        result = predict_emotion(request.text)
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    return EmotionResponse(
        emotion=result["emotion"],
        risk_level=result["risk_level"],
        confidence=result["confidence"]
    )