import csv
from pathlib import Path

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

print_genres()