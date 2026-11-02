"""Carte des déserts psychiatriques : densité de psychiatres libéraux et mixtes par département.

Lit le mart dbt `mart_offre__departement_annee` dans Athena (profil AWS `sante-mentale`),
et produit dans docs/ :
  - la carte en PNG (affichée dans le README)
  - le tableau des valeurs en CSV (version accessible et vérifiable de la carte)

Usage (depuis la racine du projet, venv actif) :
    python analyses/carte_deserts_psychiatriques.py            # année 2024
    python analyses/carte_deserts_psychiatriques.py 2026
    python analyses/carte_deserts_psychiatriques.py --demo     # données fictives, pour tester la mise en page
"""
import json
import sys
import urllib.request
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd
from matplotlib.patches import Patch, Polygon

GEOJSON_URL = ("https://raw.githubusercontent.com/gregoiredavid/france-geojson/master/"
               "departements-version-simplifiee.geojson")
DOCS = Path("docs")
CACHE = DOCS / "departements.geojson"

# Classes de densité (pour 100 000 habitants), lues par rapport à la médiane départementale (~6) :
# échelle divergente, rouge en dessous, gris neutre autour de la médiane, bleu au-dessus
CLASSES = [(0, 3, "moins de 3 (désert)"), (3, 5, "3 à 5"), (5, 8, "5 à 8 (autour de la médiane)"),
           (8, 12, "8 à 12"), (12, 1e9, "12 et plus")]
COULEURS = ["#c43a39", "#f0a19b", "#e4e3df", "#86b6ef", "#1c5cab"]
SANS_DONNEE = "#ffffff"
CONTOUR = "#fcfcfb"
BORD_SANS_DONNEE = "#b9b8b3"
FOND = "#fcfcfb"
TEXTE = "#1f1f1d"
TEXTE_2 = "#5f5e5a"

DROM = {"971": "Guadeloupe", "972": "Martinique", "973": "Guyane", "974": "La Réunion", "976": "Mayotte"}


def charger_donnees(annee: int, demo: bool) -> pd.DataFrame:
    if demo:
        import random
        random.seed(1)
        geo = json.loads(CACHE.read_text())
        codes = [f["properties"]["code"] for f in geo["features"]] + list(DROM)
        return pd.DataFrame({
            "departement_code": codes,
            "departement_libelle": codes,
            "densite_psychiatres_liberaux_mixtes": [round(random.uniform(1, 20), 1) for _ in codes],
            "nb_psychiatres_liberaux_mixtes": [random.randint(1, 200) for _ in codes],
            "densite_psychiatres": [round(random.uniform(5, 40), 1) for _ in codes],
            "densite_psychologues": [round(random.uniform(60, 160), 1) for _ in codes],
        })
    from pyathena import connect
    conn = connect(
        s3_staging_dir="s3://alex-sante-mentale-620176731553/athena-results/",
        region_name="eu-west-3",
        profile_name="sante-mentale",
    )
    requete = f"""
        select departement_code, departement_libelle, region_insee_libelle, population,
               nb_psychiatres_liberaux_mixtes, densite_psychiatres_liberaux_mixtes,
               densite_psychiatres, densite_psychologues
        from sante_mentale_dev.mart_offre__departement_annee
        where annee = {annee}
        order by departement_code
    """
    with conn.cursor() as cur:
        cur.execute(requete)
        colonnes = [c[0] for c in cur.description]
        return pd.DataFrame(cur.fetchall(), columns=colonnes)


def couleur(valeur):
    if pd.isna(valeur):
        return SANS_DONNEE
    for (bas, haut, _), c in zip(CLASSES, COULEURS):
        if bas <= valeur < haut:
            return c
    return COULEURS[-1]


def anneaux(geometrie):
    if geometrie["type"] == "Polygon":
        return [geometrie["coordinates"][0]]
    return [poly[0] for poly in geometrie["coordinates"]]


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    demo = "--demo" in sys.argv
    annee = int(args[0]) if args else 2024

    DOCS.mkdir(exist_ok=True)
    if not CACHE.exists():
        urllib.request.urlretrieve(GEOJSON_URL, CACHE)
    geo = json.loads(CACHE.read_text())

    df = charger_donnees(annee, demo)
    df["densite_psychiatres_liberaux_mixtes"] = pd.to_numeric(df["densite_psychiatres_liberaux_mixtes"])
    valeurs = df.set_index("departement_code")["densite_psychiatres_liberaux_mixtes"].to_dict()

    # Contrôle de raccordement : tout département de la carte doit avoir une valeur
    manquants = [f["properties"]["code"] for f in geo["features"] if f["properties"]["code"] not in valeurs]
    if manquants:
        print("Départements de la carte sans donnée :", manquants)

    fig = plt.figure(figsize=(10, 9.0), facecolor=FOND)
    ax = fig.add_axes([0.0, 0.08, 0.72, 0.80])
    ax.set_facecolor(FOND)
    for f in geo["features"]:
        c = couleur(valeurs.get(f["properties"]["code"]))
        bord = BORD_SANS_DONNEE if c == SANS_DONNEE else CONTOUR
        for anneau in anneaux(f["geometry"]):
            ax.add_patch(Polygon(anneau, closed=True, facecolor=c, edgecolor=bord, linewidth=0.6))
    ax.autoscale_view()
    ax.set_aspect(1 / 0.69)  # correction de la latitude (~46°N)
    ax.axis("off")

    # Titre et sous-titre
    fig.text(0.04, 0.945, "Les déserts psychiatriques en France", fontsize=19, fontweight="bold", color=TEXTE)
    fig.text(0.04, 0.91, f"Psychiatres libéraux et mixtes pour 100 000 habitants, par département, au 1er janvier {annee}",
             fontsize=11.5, color=TEXTE_2)

    # Légende
    elements = [Patch(facecolor=c, edgecolor="none", label=lib) for (_, _, lib), c in zip(CLASSES, COULEURS)]
    elements.append(Patch(facecolor=SANS_DONNEE, edgecolor=BORD_SANS_DONNEE, label="sans donnée"))
    fig.legend(handles=elements, loc="upper left", bbox_to_anchor=(0.73, 0.85), frameon=False,
               fontsize=10.5, labelcolor=TEXTE, title="Densité", title_fontsize=11, alignment="left")

    # Extrêmes de métropole et DROM, en texte (les DROM ne sont pas cartographiés)
    metro = df[~df.departement_code.isin(DROM)].dropna(subset=["densite_psychiatres_liberaux_mixtes"])
    bas = metro.nsmallest(5, "densite_psychiatres_liberaux_mixtes")
    haut = metro.nlargest(3, "densite_psychiatres_liberaux_mixtes")
    lignes = ["Les moins dotés"] + [f"  {r.departement_libelle}  {r.densite_psychiatres_liberaux_mixtes:.1f}"
                                    for r in bas.itertuples()]
    lignes += ["", "Les mieux dotés"] + [f"  {r.departement_libelle}  {r.densite_psychiatres_liberaux_mixtes:.1f}"
                                         for r in haut.itertuples()]
    drom = df[df.departement_code.isin(DROM)]
    lignes += ["", "Outre-mer (non cartographié)"] + [
        f"  {DROM[r.departement_code]}  "
        + ("n.d." if pd.isna(r.densite_psychiatres_liberaux_mixtes) else f"{r.densite_psychiatres_liberaux_mixtes:.1f}")
        for r in drom.sort_values("departement_code").itertuples()]
    fig.text(0.735, 0.555, "\n".join(lignes), fontsize=9.5, color=TEXTE, va="top", linespacing=1.55)

    # Source
    fig.text(0.04, 0.03,
             "Sources : DREES (RPPS), INSEE (estimations de population). Libéral et mixte regroupés.\n"
             "Fond de carte : france-geojson (G. David), d'après IGN. Réalisation : Alexandra Delverdier.",
             fontsize=8.5, color=TEXTE_2, linespacing=1.5)

    suffixe = "_demo" if demo else ""
    sortie_png = DOCS / f"carte_psychiatres_liberaux_{annee}{suffixe}.png"
    fig.savefig(sortie_png, dpi=160, facecolor=FOND)
    df.to_csv(DOCS / f"offre_departement_{annee}{suffixe}.csv", index=False, sep=";")
    print("Carte :", sortie_png, "| départements :", len(df))


if __name__ == "__main__":
    main()
