"""
Flask API wrapper for tag_matching recommendations
Run with: python recommendation_api.py
"""

from flask import Flask, request, jsonify
from tag_matching import (
    get_recommendations_by_emotion,
    get_favorite_genre_weights,
    load_and_parse_data,
)
from pathlib import Path

app = Flask(__name__)

# Load both datasets at startup
print("\n" + "="*60)
print("RECOMMENDATION API STARTUP")
print("="*60)

print("[INIT] Loading movies dataset...")
movies_data = load_and_parse_data(
    Path(__file__).resolve().parent / "Dataset" / "movies_enriched.csv"
)
print(f"[INIT] Loaded {len(movies_data)} movies")

print("[INIT] Loading books dataset...")
books_data = load_and_parse_data(
    Path(__file__).resolve().parent / "Dataset" / "books_enriched.csv"
)
print(f"[INIT] Loaded {len(books_data)} books")

# Load favorite weights
movies_favorites_path = (
    Path(__file__).resolve().parent / "user_favorite_movies.json"
)
books_favorites_path = Path(__file__).resolve().parent / "user_favorite_books.json"

print("[INIT] Loading favorite weights...")
movies_favorite_weights = get_favorite_genre_weights(
    movies_data, movies_favorites_path, is_movie=True
)
print(f"[INIT] Loaded {len(movies_favorite_weights)} movie genre weights")

books_favorite_weights = get_favorite_genre_weights(
    books_data, books_favorites_path, is_movie=False
)
print(f"[INIT] Loaded {len(books_favorite_weights)} book category weights")

print("[SUCCESS] API Ready!")
print("="*60 + "\n")


@app.route("/recommend", methods=["POST"])
def get_recommendations():
    """
    Get recommendations based on emotion and media type.
    
    Expected JSON:
    {
        "emotion": "joy",
        "media_type": "books" or "movies",  # optional, defaults to "books"
        "count": 3  # optional, defaults to 3
    }
    """
    try:
        print("\n" + "="*60)
        print("RECOMMENDATION API CALLED")
        print("="*60)
        
        data = request.get_json()
        print(f"[DEBUG] Received request: {data}")
        
        emotion = data.get("emotion", "").strip().lower()
        media_type = data.get("media_type", "books").strip().lower()
        count = data.get("count", 3)
        
        print(f"[DEBUG] Parsed emotion: '{emotion}'")
        print(f"[DEBUG] Parsed media_type: '{media_type}'")
        print(f"[DEBUG] Count: {count}")

        # Normalize emotion names
        valid_emotions = [
            "joy",
            "sadness",
            "fear",
            "anger",
            "despondent",
            "excitement",
            "curiosity",
            "anxious",
        ]
        
        if emotion not in valid_emotions:
            print(f"[ERROR] Invalid emotion: {emotion}")
            return (
                jsonify({"error": f"Invalid emotion. Valid emotions: {valid_emotions}"}),
                400,
            )

        if media_type not in ["movies", "books"]:
            print(f"[ERROR] Invalid media_type: {media_type}")
            return jsonify({"error": "media_type must be 'movies' or 'books'"}), 400

        # Get recommendations
        if media_type == "movies":
            is_movie = True
            dataset = movies_data
            fav_weights = movies_favorite_weights
            print(f"[DEBUG] Using movies dataset with {len(dataset)} items")
        else:
            is_movie = False
            dataset = books_data
            fav_weights = books_favorite_weights
            print(f"[DEBUG] Using books dataset with {len(dataset)} items")

        # Capitalize emotion for lookup
        emotion_capitalized = emotion.capitalize()
        print(f"[DEBUG] Capitalized emotion: '{emotion_capitalized}'")

        recommendations = get_recommendations_by_emotion(
            emotion_capitalized, dataset, fav_weights, is_movie=is_movie
        )
        
        print(f"[DEBUG] Total recommendations found: {len(recommendations)}")

        # Format response
        result = [
            {"title": title, "score": float(score)}
            for _, title, score in recommendations[:count]
        ]
        
        print(f"[DEBUG] Returning top {len(result)} recommendations:")
        for i, rec in enumerate(result, 1):
            print(f"  {i}. {rec['title']} (Score: {rec['score']:.2f})")

        response_data = {
            "emotion": emotion,
            "media_type": media_type,
            "recommendations": result,
            "count": len(result),
        }
        
        print(f"[SUCCESS] Sending response with {len(result)} recommendations")
        print("="*60 + "\n")
        
        return jsonify(response_data)

    except Exception as e:
        print(f"[ERROR] Exception occurred: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@app.route("/health", methods=["GET"])
def health_check():
    """Health check endpoint"""
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    print("Starting recommendation API on http://127.0.0.1:5000")
    print("Available endpoints:")
    print("  POST /recommend - Get recommendations")
    print("  GET /health - Health check")
    app.run(debug=True, port=5000)
