from collections import defaultdict
import csv
from pathlib import Path
import sys
import json

emotion_to_genre_weight_mappings = {
    "Joy": {
        "Comedy": 1.0, "Animation": 0.9, "Musical": 0.9,
        "Adventure": 0.8, "Fantasy": 0.7, "Family": 0.7,
        "Romance": 0.6, "Sci-Fi": 0.5,
        "Horror": -0.7, "War": -0.8, "Film-Noir": -0.6, "Drama": -0.5
    },
    "Sadness": {
        "Animation": 1.0, "Comedy": 1.0, "Family": 0.8,
        "Musical": 0.7, "Adventure": 0.6, "Fantasy": 0.5,
        "Drama": 0.2, "Romance": 0.1,
        "Horror": -0.5, "Thriller": -0.4, "War": -0.6
    },
    "Fear": {
        "Family": 1.0, "Comedy": 0.9, "Animation": 0.8,
        "Musical": 0.8, "Romance": 0.7, "Horror": -1.0,
        "Thriller": -1.0, "Crime": -0.7,
        "Mystery": -0.5, "Film-Noir": -0.5
    },
    "Anger": {
        "Action": 1.0, "War": 0.8, "Comedy": 0.7,
        "Crime": 0.6, "Western": 0.5,
        "Romance": -0.8, "Drama": -0.6, "Musical": -0.5,
        "Family": -0.4
    },
    "Despondent": {
        "Fantasy": 0.9, "Sci-Fi": 0.8,
        "Animation": 0.7, "Adventure": 0.6,
        "Documentary": 0.5,
        "Film-Noir": -0.8, "War": -0.9, "Drama": -0.4
    },
    "Excitement": {
        "Action": 1.0, "Adventure": 0.9, "Sci-Fi": 0.8,
        "Thriller": 0.7, "Horror": 0.6, "Western": 0.6,
        "Documentary": -0.7, "Drama": -0.6, "Romance": -0.3
    },
    "Curiosity": {
        "Mystery": 1.0, "Documentary": 0.9, "Sci-Fi": 0.9,
        "Crime": 0.8, "Film-Noir": 0.7, "Thriller": 0.6,
        "Family": -0.8, "Romance": -0.5, "Musical": -0.4
    },
    "Anxious": {
        "Fantasy": 1.0, "Sci-Fi": 0.8, "Documentary": 0.7,
        "Animation": 0.6, "Musical": 0.5,
        "Thriller": -1.0, "Horror": -1.0, "War": -0.9,
        "Crime": -0.7, "Action": -0.4
    }
}

DATASET = Path(__file__).resolve().parent / "Dataset" / "movies_enriched.csv"
USER_FAVORITES = Path(__file__).resolve().parent / "user_favorite_movies.json"

def find_dataset(path: Path) -> Path:
    p = Path(path)
    if not p.exists():
        print(f"ERROR: Dataset file not found: {path}", file=sys.stderr)
        print("Expected: Dataset/movies_enriched.csv", file=sys.stderr)
        sys.exit(1)
    return p


def print_genres(path: Path) -> None:
    genres: set[str] = set()

    with path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)

        for row in reader:
            genres_value = (row.get("genres") or "").strip()
            if not genres_value:
                continue

            for genre in genres_value.split("|"):
                genre = genre.strip()
                if genre:
                    genres.add(genre)

    for genre in sorted(genres):
        print(genre)


def get_final_score(total_weight: float, rating_count: int, rating_mean: float) -> float:
  
    if rating_count < 2000:
        weight_factor = rating_count / 2000  # Scale down score for movies with less than 2000 ratings
    else:
        weight_factor = 1.0

    final_score = total_weight * (1 + rating_mean / 5.0) * weight_factor
    return final_score


def load_and_parse_movies(path: Path) -> list[dict]:
    movies_data = []
    with path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                row["rating_count"] = int(row.get("rating_count", "0").strip() or 0.0)
                row["rating_mean"] = float(row.get("rating_mean", "0.0").strip() or 0.0)
                movies_data.append(row)
            except (ValueError, TypeError):
                continue
    return movies_data

import json


def get_favorite_genre_weights(movies_data: list[dict], json_path: Path) -> dict[str, float]:
    
    with json_path.open(encoding="utf-8") as f:
        data = json.load(f)

    favorite_titles = set(data.get("user_favorite_movies", []))
    favorite_genre_weights = defaultdict(float)

    for row in movies_data:
        title = row.get("title", "").strip()
        if title in favorite_titles:
            genres_value = (row.get("genres") or "")
            for genre in genres_value.split("|"):
                favorite_genre_weights[genre.strip()] += 0.3  
    # print(favorite_genre_weights)


    return favorite_genre_weights

def get_movies_by_emotion(emotion: str, movies_data: list[dict], favorite_genre_weights: dict[str, float]) -> list[tuple[str, str, float]]:
    genre_weights = emotion_to_genre_weight_mappings[emotion]
    movies = []

    for row in movies_data:
        movieId = row.get("movieId", "").strip()
        title = row.get("title", "Unknown Title").strip()
        genres_value = (row.get("genres") or "").strip()
        rating_count = row.get("rating_count", 0)
        rating_mean = row.get("rating_mean", 0.0)

        if not movieId or not genres_value:
            continue

        total_weight = 0.0
        for genre in genres_value.split("|"):
            genre = genre.strip()
            total_weight += genre_weights.get(genre, 0.0)
            total_weight += favorite_genre_weights.get(genre, 0.0) 

        if total_weight > 0:
            final_score = get_final_score(total_weight, rating_count, rating_mean)
            movies.append((movieId, title, final_score))

    movies.sort(key=lambda x: x[2], reverse=True)
    return movies


def print_movies_by_emotion(emotion: str, movies_data: list[dict], favorite_genre_weights: dict[str, float]) -> None:
	count = 0
	movies = get_movies_by_emotion(emotion, movies_data, favorite_genre_weights)
	print(f"Here are the top 3 movies for when you are feeling '{emotion}':")
	for movieId, title, score in movies:
		print(f"{title} (Score: {score:.2f})")
		count += 1
		if count >= 3:
			break

# __main__

# To accept lowercase emotion names
emotion_lookup = {k.strip().lower(): k for k in emotion_to_genre_weight_mappings.keys()}

path = find_dataset(DATASET)
movies_data = load_and_parse_movies(path)

favorite_genre_weights = get_favorite_genre_weights(movies_data, USER_FAVORITES)

while True:
    choice = input(f"Enter an emotion (joy, sadness, fear, anger, despondent, excitement, curiosity, anxious): ").strip().lower()
    if choice in emotion_lookup:
        emotion_input = emotion_lookup[choice]
        break
    print(f"Invalid emotion '{choice}'. Please try again.")

print_movies_by_emotion(emotion_input, movies_data, favorite_genre_weights)