import torch
from transformers import AutoTokenizer, AutoModelForSequenceClassification

MODEL_PATH = "emotion_tr_bert"

tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH)
model = AutoModelForSequenceClassification.from_pretrained(MODEL_PATH)

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model.to(device)
model.eval()

print("\n🎯 Duygu Analizi Hazır")
print("Çıkmak için q yaz\n")

while True:
    text = input("Cümle gir: ")

    if text.lower() in ["q", "quit", "exit"]:
        print("👋 Çıkılıyor...")
        break

    inputs = tokenizer(
        text,
        return_tensors="pt",
        truncation=True,
        padding=True
    ).to(device)

    with torch.no_grad():
        outputs = model(**inputs)

    pred = torch.argmax(outputs.logits, dim=1).item()
    label = model.config.id2label[pred]

    print("➡️ Duygu:", label)
    print("-" * 30)

