import os
import pandas as pd

# =========================
# AYARLAR
# =========================
INPUT_CSV  = r"data_processed/movies_enriched.csv"   # sende neredeyse onu yaz
OUTPUT_CSV = r"data_processed/balanced_multilabel.csv"

TARGET_PER_GENRE = 127         # 127 örnek (değişebilir)
GENRE_COL = "genres_norm"      # sende genre kolonu buysa böyle kalsın
INCLUDE_NO_GENRE_LABEL = False # (no genres listed) label olsun istiyorsan True


def parse_genres(s):
    if pd.isna(s) or str(s).strip() == "":
        return []
    return [g.strip() for g in str(s).split("|") if g.strip()]


def main():
    os.makedirs(os.path.dirname(OUTPUT_CSV), exist_ok=True)
    df = pd.read_csv(INPUT_CSV)

    # 1) Tüm genre setini çıkar
    all_genres = set()
    for x in df[GENRE_COL].fillna(""):
        for g in parse_genres(x):
            if g == "(no genres listed)" and not INCLUDE_NO_GENRE_LABEL:
                continue
            all_genres.add(g)

    all_genres = sorted(all_genres)

    # 2) Sayaçlar + iteration ile seçim
    counts = {g: 0 for g in all_genres}
    selected_idx = []

    for idx, row in df.iterrows():   # ✅ dataset'in mevcut sırası, hiçbir sorting yok
        gs = parse_genres(row[GENRE_COL])

        if not INCLUDE_NO_GENRE_LABEL:
            gs = [g for g in gs if g != "(no genres listed)"]

        if not gs:
            continue

        # Film, hedefe ulaşmamış en az 1 genre içeriyorsa -> seç
        if any(counts.get(g, 0) < TARGET_PER_GENRE for g in gs):
            selected_idx.append(idx)
            for g in gs:
                if g in counts:
                    counts[g] += 1

        # Tüm genre'lar hedefe ulaştıysa dur
        if all(counts[g] >= TARGET_PER_GENRE for g in counts):
            break

    out = df.loc[selected_idx].copy().reset_index(drop=True)

    # 3) Multi-hot label kolonları ekle: y_Action, y_Drama, ...
    for g in all_genres:
        out[f"y_{g}"] = 0

    for i, row in out.iterrows():
        gs = parse_genres(row[GENRE_COL])
        if not INCLUDE_NO_GENRE_LABEL:
            gs = [g for g in gs if g != "(no genres listed)"]
        for g in gs:
            col = f"y_{g}"
            if col in out.columns:
                out.at[i, col] = 1

    # (İsteğe bağlı) okuması kolay olsun diye list halinde de tut
    out["labels_list"] = out[GENRE_COL].fillna("").apply(parse_genres)
    if not INCLUDE_NO_GENRE_LABEL:
        out["labels_list"] = out["labels_list"].apply(lambda xs: [g for g in xs if g != "(no genres listed)"])

    # 4) Kaydet + raporla
    out.to_csv(OUTPUT_CSV, index=False)

    print(f"✅ Saved: {OUTPUT_CSV}")
    print(f"Rows selected: {len(out)}")
    print("\nGenre counts (selected set):")
    for g in all_genres:
        print(f"  {g:15s} -> {counts[g]} (target={TARGET_PER_GENRE})")


if __name__ == "__main__":
    main()
