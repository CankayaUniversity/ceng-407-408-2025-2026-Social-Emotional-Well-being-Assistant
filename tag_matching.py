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

emotion_to_category_weight_mappings = {
    "Joy": {
        "Arts & Culture": 1.0, "Fiction & Narrative": 0.9, "Children & Young Adult": 0.8,
        "Practical & How-To": 0.7, "Health & Wellness": 0.7, "Education & Learning": 0.6,
        "Science & Nature": 0.5,
        "True Crime & Mystery": -0.7, "History, Biography & Culture": -0.6, "Religion & Spirituality": -0.5
    },
    "Sadness": {
        "Children & Young Adult": 1.0, "Fiction & Narrative": 0.8, "Practical & How-To": 0.7,
        "Education & Learning": 0.6, "Self-Help & Personal Development": 0.5,
        "True Crime & Mystery": -0.5, "Business & Professional": -0.4, "Travel & Geography": -0.3
    },
    "Fear": {
        "Children & Young Adult": 1.0, "Arts & Culture": 0.9, "Fiction & Narrative": 0.8,
        "Practical & How-To": 0.7, "Science & Nature": 0.6,
        "True Crime & Mystery": -1.0, "Business & Professional": -1.0, "History, Biography & Culture": -0.6,
        "Religion & Spirituality": -0.5
    },
    "Anger": {
        "Business & Professional": 1.0, "Practical & How-To": 0.8, "Arts & Culture": 0.7,
        "Science & Nature": 0.6, "Travel & Geography": 0.5,
        "Education & Learning": -0.8, "Fiction & Narrative": -0.6, "Children & Young Adult": -0.5
    },
    "Despondent": {
        "Fiction & Narrative": 0.9, "Science & Nature": 0.8,
        "Practical & How-To": 0.7, "Self-Help & Personal Development": 0.6,
        "Arts & Culture": -0.8, "Education & Learning": -0.7, "Children & Young Adult": -0.6
    },
    "Excitement": {
        "Business & Professional": 1.0, "Practical & How-To": 0.9, "Science & Nature": 0.8,
        "Travel & Geography": 0.7, "History, Biography & Culture": 0.6,
        "Religion & Spirituality": -0.6, "Self-Help & Personal Development": -0.5, "Education & Learning": -0.3
    },
    "Curiosity": {
        "History, Biography & Culture": 1.0, "Travel & Geography": 0.9, "Science & Nature": 0.9,
        "True Crime & Mystery": 0.8, "Self-Help & Personal Development": 0.6,
        "Children & Young Adult": -0.8, "Education & Learning": -0.5, "Arts & Culture": -0.4
    },
    "Anxious": {
        "Fiction & Narrative": 1.0, "Science & Nature": 0.8, "Self-Help & Personal Development": 0.7,
        "Practical & How-To": 0.6, "Children & Young Adult": 0.5,
        "True Crime & Mystery": -1.0, "Business & Professional": -1.0, "Religion & Spirituality": -0.9,
        "Travel & Geography": -0.4
    }
}

DATASET = Path(__file__).resolve().parent / "Dataset" / "movies_enriched.csv"
BOOKS_DATASET = Path(__file__).resolve().parent / "Dataset" / "books_enriched_recategorized.csv"
USER_FAVORITES_MOVIES = Path(__file__).resolve().parent / "user_favorite_movies.json"
USER_FAVORITES_BOOKS = Path(__file__).resolve().parent / "user_favorite_books.json"

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
        weight_factor = rating_count / 2000
    else:
        weight_factor = 1.0

    final_score = total_weight * (1 + rating_mean / 5.0) * weight_factor
    return final_score


def load_and_parse_data(path: Path) -> list[dict]:
    data = []
    with path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                row["rating_count"] = int(row.get("rating_count", "0").strip() or 0.0)
                row["rating_mean"] = float(row.get("rating_mean", "0.0").strip() or 0.0)
                data.append(row)
            except (ValueError, TypeError):
                continue
    return data


def get_favorite_genre_weights(data: list[dict], json_path: Path, is_movie: bool = True) -> dict[str, float]:
    
    if not json_path.exists():
        return {}
    
    with json_path.open(encoding="utf-8") as f:
        json_data = json.load(f)

    if is_movie:
        favorite_titles = set(json_data.get("user_favorite_movies", []))
    else:
        favorite_titles = set(json_data.get("user_favorite_books", []))
    
    favorite_genre_weights = defaultdict(float)

    for row in data:
        title = row.get("title", row.get("Title", "")).strip()
        if title in favorite_titles:
            genres_value = (row.get("genres", row.get("categories", "")) or "")
            for genre in genres_value.split("|"):
                favorite_genre_weights[genre.strip()] += 0.3  

    return favorite_genre_weights

def get_recommendations_by_emotion(emotion: str, data: list[dict], 
                                    favorite_genre_weights: dict[str, float],
                                    is_movie: bool = True) -> list[tuple[str, str, float]]:
    if is_movie:
        genre_weights = emotion_to_genre_weight_mappings[emotion]
        genre_col = "genres"
        id_col = "movieId"
        title_col = "title"
    else:
        genre_weights = emotion_to_category_weight_mappings[emotion]
        genre_col = "categories"
        id_col = "Title"
        title_col = "Title"
    
    recommendations = []

    for row in data:
        id_val = row.get(id_col, "").strip()
        title = row.get(title_col, "Unknown Title").strip()
        genres_value = (row.get(genre_col) or "").strip()
        rating_count = row.get("rating_count", 0)
        rating_mean = row.get("rating_mean", 0.0)

        if not id_val or not genres_value:
            continue

        total_weight = 0.0
        for genre in genres_value.split("|"):
            genre = genre.strip()
            total_weight += genre_weights.get(genre, 0.0)
            total_weight += favorite_genre_weights.get(genre, 0.0) 

        if total_weight > 0:
            final_score = get_final_score(total_weight, rating_count, rating_mean)
            recommendations.append((id_val, title, final_score))

    recommendations.sort(key=lambda x: x[2], reverse=True)
    return recommendations


def print_recommendations_by_emotion(emotion: str, data: list[dict], 
                                     favorite_genre_weights: dict[str, float],
                                     is_movie: bool = True, count: int = 3) -> None:
	media_type = "movies" if is_movie else "books"
	recommendations = get_recommendations_by_emotion(emotion, data, favorite_genre_weights, is_movie)
	print(f"\nHere are the top {count} {media_type} for when you are feeling '{emotion}':")
	for idx, (id_val, title, score) in enumerate(recommendations[:count], 1):
		print(f"{idx}. {title} (Score: {score:.2f})")

def run_cli() -> None:
    # To accept lowercase emotion names
    emotion_lookup = {k.strip().lower(): k for k in emotion_to_genre_weight_mappings.keys()}

    # Ask user to choose between movies or books
    while True:
        choice = input("Would you like recommendations for (m)ovies or (b)ooks? ").strip().lower()
        if choice in ["m", "movies"]:
            is_movie = True
            path = find_dataset(DATASET)
            data = load_and_parse_data(path)
            user_favorites_path = USER_FAVORITES_MOVIES
            break
        if choice in ["b", "books"]:
            is_movie = False
            path = find_dataset(BOOKS_DATASET)
            data = load_and_parse_data(path)
            user_favorites_path = USER_FAVORITES_BOOKS
            break
        print("Invalid choice. Please enter 'm' for movies or 'b' for books.")

    favorite_genre_weights = get_favorite_genre_weights(data, user_favorites_path, is_movie)

    while True:
        choice = input("Enter an emotion (joy, sadness, fear, anger, despondent, excitement, curiosity, anxious): ").strip().lower()
        if choice in emotion_lookup:
            emotion_input = emotion_lookup[choice]
            break
        print(f"Invalid emotion '{choice}'. Please try again.")

    print_recommendations_by_emotion(emotion_input, data, favorite_genre_weights, is_movie)


if __name__ == "__main__":
    run_cli()