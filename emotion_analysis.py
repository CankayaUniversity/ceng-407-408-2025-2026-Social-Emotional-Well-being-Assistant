import torch
from transformers import pipeline

def analyze_emotion(text: str) -> str:
    try:
        emotion_classifier = pipeline(
            "text-classification",
            model="j-hartmann/emotion-english-distilroberta-base",
            return_all_scores=False
        )

        result = emotion_classifier(text)
        
        predicted_emotion = result[0]['label']
        
        return predicted_emotion

    except Exception as e:
        return f"Bir hata oluştu: {e}"

if __name__ == "__main__":
    while True:
        user_input = input("Lütfen bir cümle girin (çıkmak için 'q' tuşuna basın): ")
        if user_input.lower() == 'q':
            break
        
        emotion = analyze_emotion(user_input)
        print(f"Metin: '{user_input}'")
        print(f"Tahmin Edilen Duygu: {emotion}\n")
