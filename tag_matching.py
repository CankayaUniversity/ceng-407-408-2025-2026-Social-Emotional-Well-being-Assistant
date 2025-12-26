from collections import defaultdict
import csv
from pathlib import Path
import sys

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

def find_dataset(path: Path) -> Path:
    p = Path(path)
    if not p.exists():
        print(f"ERROR: Dataset file not found: {path}", file=sys.stderr)
        print("Expected: Dataset/movies_enriched.csv", file=sys.stderr)
        sys.exit(1)
    return p

# Deprecated function
def get_average_ratings(path: str | Path = Path("Dataset") / "ratings.csv") -> dict[str, float]:
    movie_ratings = defaultdict(list)
    average_ratings = {}

    # Matching movie IDs to their ratings
    try:
        with Path(path).open(newline="", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                movieId = row.get("movieId")
                rating = row.get("rating")
                if movieId and rating:
                    movie_ratings[movieId].append(float(rating))
        
        # Calculate rating averages
        for movieId, ratings in movie_ratings.items():
            if ratings:
                average_ratings[movieId] = sum(ratings) / len(ratings)
                
    except FileNotFoundError:
        print(f"Error! Movie ratings file is not found at {path}. Default rating is set to 0.0.")
    
    return average_ratings

def print_genres(path: str) -> None:
    genres: set[str] = set()

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

def get_movies_by_emotion(emotion: str, path: str) -> list[tuple[str, float]]:
    genre_weights = emotion_to_genre_weight_mappings[emotion]
    movies = []

    with Path(path).open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)

        for row in reader:
            movieId = row.get("movieId", "").strip()
            genres_value = (row.get("genres") or "").strip()

            if not movieId or not genres_value:
                continue

            total_weight = 0.0
            for genre in genres_value.split("|"):
                genre = genre.strip()
                total_weight += genre_weights.get(genre, 0.0)

            if total_weight > 0:
                #user_rating = avg_ratings.get(movieId, 0.0)   integrate this part in new function later !
                #final_score = total_weight * user_rating
                movies.append((movieId, total_weight))

    movies.sort(key=lambda x: x[1], reverse=True)
    return movies


def print_movies_by_emotion(emotion: str, path: str) -> None:
	count = 0
	movies = get_movies_by_emotion(emotion, path)
	print(f"Movies matching emotion '{emotion}' (ranked):")
	for movieId, score in movies:
		print(f"{movieId} (Score: {score:.2f})")
		count += 1
		if count >= 30:
			break

# __main__

# To accept lowercase emotion names
emotion_lookup = {k.strip().lower(): k for k in emotion_to_genre_weight_mappings.keys()}

path = find_dataset(DATASET)

# avg_ratings = get_average_ratings()
while True:
	choice = input(f"Enter an emotion (joy, sadness, fear, anger, despondent, excitement, curiosity, anxious): ").strip().lower()
	if choice in emotion_lookup:
		emotion_input = emotion_lookup[choice] 
		break
	print(f"Invalid emotion '{choice}'.")

print_movies_by_emotion(emotion_input, path)