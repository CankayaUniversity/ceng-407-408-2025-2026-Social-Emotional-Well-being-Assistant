import csv
from pathlib import Path
import sys

emotion_to_genre_weight_mappings = {
    "Joy": {
        "Comedy": 1.0, "Animation": 0.9, "Musical": 0.9,
        "Adventure": 0.8, "Fantasy": 0.7, "Children": 0.7,
        "Romance": 0.6, "Sci-Fi": 0.5,
        "Horror": -0.7, "War": -0.8, "Film-Noir": -0.6, "Drama": -0.5
    },
    "Sadness": {
        "Animation": 1.0, "Comedy": 1.0, "Children": 0.8,
        "Musical": 0.7, "Adventure": 0.6, "Fantasy": 0.5,
        "Drama": 0.2, "Romance": 0.1,
        "Horror": -0.5, "Thriller": -0.4, "War": -0.6
    },
    "Fear": {
        "Children": 1.0, "Comedy": 0.9, "Animation": 0.8,
        "Musical": 0.8, "Romance": 0.7, "Family": 0.7,
        "Horror": -1.0, "Thriller": -1.0, "Crime": -0.7,
        "Mystery": -0.5, "Film-Noir": -0.5
    },
    "Anger": {
        "Action": 1.0, "War": 0.8, "Comedy": 0.7,
        "Crime": 0.6, "Western": 0.5,
        "Romance": -0.8, "Drama": -0.6, "Musical": -0.5,
        "Children": -0.4
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
        "Children": -0.8, "Romance": -0.5, "Musical": -0.4
    },
    "Anxious": {
        "Fantasy": 1.0, "Sci-Fi": 0.8, "Documentary": 0.7,
        "Animation": 0.6, "Musical": 0.5,
        "Thriller": -1.0, "Horror": -1.0, "War": -0.9,
        "Crime": -0.7, "Action": -0.4
    }
}

DATASET = Path(__file__).resolve().parent / "Dataset" / "movies.csv"

def find_dataset(path: str | Path) -> Path:
    p = Path(path)
    if not p.exists():
        print(f"ERROR: Dataset file not found: {path}", file=sys.stderr)
        print("Expected: Dataset/movies.csv", file=sys.stderr)
        sys.exit(1)
    return p

def print_genres(path: str | Path = DATASET) -> None:
    genres: set[str] = set()

    path = find_dataset(path)

    with Path(path).open(newline="", encoding="utf-8") as f:
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

def get_movies_by_emotion(emotion: str, path: str | Path = DATASET) -> list[tuple[str, float]]:
    genre_weights = emotion_to_genre_weight_mappings[emotion]
    movies = []

    path = find_dataset(path)

    with Path(path).open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)

        for row in reader:
            title = row.get("title", "").strip()
            genres_value = (row.get("genres") or "").strip()

            if not title or not genres_value:
                continue

            total_weight = 0.0
            for genre in genres_value.split("|"):
                genre = genre.strip()
                total_weight += genre_weights.get(genre, 0.0)

            if total_weight > 0:
                movies.append((title, total_weight))

    movies.sort(key=lambda x: x[1], reverse=True)
    return movies


def print_movies_by_emotion(emotion: str, path: str | Path = DATASET) -> None:
	count = 0
	movies = get_movies_by_emotion(emotion, path)
	print(f"Movies matching emotion '{emotion}' (ranked):")
	for title, score in movies:
		print(f"{title} (Score: {score:.2f})")
		count += 1
		if count >= 30:
			break

# To accept lowercase emotion names
emotion_lookup = {k.strip().lower(): k for k in emotion_to_genre_weight_mappings.keys()}

find_dataset(DATASET)

while True:
	choice = input(f"Enter an emotion (joy, sadness, fear, anger, despondent, excitement, curiosity, anxious): ").strip().lower()
	if choice in emotion_lookup:
		emotion_input = emotion_lookup[choice] 
		break
	print(f"Invalid emotion '{choice}'.")

print_movies_by_emotion(emotion_input)