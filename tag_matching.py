import csv
from pathlib import Path

emotion_to_genre_weight_mappings = {
    "Joy": {
        "Comedy": 1.0, "Children": 0.9, "Animation": 0.9,
        "Musical": 0.9, "Romance": 0.7, "Adventure": 0.6,
        "Fantasy": 0.6, "Drama": 0.3, "Documentary": 0.3
    },
    "Sadness": {
        "Drama": 1.0, "War": 0.8, "Film-Noir": 0.7,
        "Romance": 0.7, "Documentary": 0.6, "Western": 0.4,
        "Animation": 0.3
    },
    "Fear": {
        "Horror": 1.0, "Thriller": 0.8, "Crime": 0.6,
        "Mystery": 0.6, "Sci-Fi": 0.5, "Fantasy": 0.3
    },
    "Anger": {
        "Action": 0.9, "War": 0.8, "Crime": 0.6,
        "Thriller": 0.5, "Western": 0.5, "Film-Noir": 0.4
    },
    "Despondent": {
        "Drama": 1.0, "Film-Noir": 0.8, "War": 0.7,
        "Romance": 0.6, "Documentary": 0.6, "Crime": 0.5
    },
    "Excitement": {
        "Action": 1.0, "Adventure": 0.9, "Sci-Fi": 0.8,
        "Thriller": 0.7, "Fantasy": 0.7, "Western": 0.6,
        "Animation": 0.6
    },
    "Curiosity": {
        "Mystery": 1.0, "Documentary": 0.9, "Sci-Fi": 0.9,
        "Crime": 0.8, "Adventure": 0.7, "Fantasy": 0.7,
        "Film-Noir": 0.6
    },
    "Anxious": {
        "Thriller": 1.0, "Horror": 0.9, "Crime": 0.8,
        "Mystery": 0.7, "Film-Noir": 0.7, "Drama": 0.6,
        "Sci-Fi": 0.6
    }
}

def print_genres(path: str | Path = Path("Dataset") / "movies.csv") -> None:
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

def get_movies_by_emotion(emotion: str, path: str | Path = Path("Dataset") / "movies.csv") -> list[tuple[str, float]]:
    genre_weights = emotion_to_genre_weight_mappings[emotion]
    movies = []

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


def print_movies_by_emotion(emotion: str, path: str | Path = Path("Dataset") / "movies.csv") -> None:
	movies = get_movies_by_emotion(emotion, path)
	print(f"Movies matching emotion '{emotion}' (ranked):")
	for title, score in movies:
		print(f"{title} (Score: {score:.2f})")


emotion_input = input("Enter an emotion(joy, sadness, fear, anger, despondent, excitement, curiosity, anxious): ").strip()
print_movies_by_emotion(emotion_input)