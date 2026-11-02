"""Population INSEE au 1er janvier par région, sexe et grande classe d'âge -> CSV long -> S3 raw.
Source : https://www.insee.fr/fr/statistiques/8721456 (une feuille par année, régions identifiées par leur nom)
Exécuté depuis AWS CloudShell : python3 ingest_insee_population.py
"""
import subprocess
import unicodedata
import pandas as pd

URL = "https://www.insee.fr/fr/statistiques/fichier/8721456/estim-pop-nreg-sexe-gca-1975-2026.xlsx"
SRC = "/tmp/insee/pop_reg.xlsx"
OUT = "/tmp/insee/population_region_sexe_gca.csv"
S3 = "s3://alex-sante-mentale-620176731553/raw/insee/population_region_sexe_gca/population_region_sexe_gca.csv"

def norm(s):
    s = unicodedata.normalize("NFKD", str(s)).encode("ascii", "ignore").decode()
    return " ".join(s.lower().replace("-", " ").replace("'", " ").split())

REGIONS = {
    "auvergne rhone alpes": "84", "bourgogne franche comte": "27", "bretagne": "53",
    "centre val de loire": "24", "corse": "94", "grand est": "44", "hauts de france": "32",
    "ile de france": "11", "normandie": "28", "nouvelle aquitaine": "75", "occitanie": "76",
    "pays de la loire": "52", "provence alpes cote d azur": "93",
    "guadeloupe": "01", "martinique": "02", "guyane": "03", "la reunion": "04", "mayotte": "06",
}
SEXES = {"Hommes": "1", "Femmes": "2"}

subprocess.run(["curl", "-sfL", "-o", SRC, URL], check=True)
sheets = pd.read_excel(SRC, sheet_name=None, header=None)

rows, inconnus = [], set()
for name, df in sheets.items():
    if not name.isdigit():
        continue
    annee = int(name)
    # Ligne 3 : blocs Ensemble / Hommes / Femmes ; ligne 4 : classes d'âge
    bloc, entetes = None, []
    for j in range(1, df.shape[1]):
        if pd.notna(df.iat[3, j]):
            bloc = str(df.iat[3, j]).strip()
        entetes.append((j, bloc, str(df.iat[4, j]).strip()))
    for i in range(5, df.shape[0]):
        libelle = df.iat[i, 0]
        if pd.isna(libelle):
            continue
        code = REGIONS.get(norm(libelle))
        if code is None:
            inconnus.add(str(libelle).strip())
            continue
        for j, bloc, age in entetes:
            if bloc in SEXES and age != "Total" and pd.notna(df.iat[i, j]):
                rows.append((annee, code, str(libelle).strip(), SEXES[bloc], age, int(df.iat[i, j])))

out = pd.DataFrame(rows, columns=["annee", "region_insee_code", "region_insee_libelle",
                                  "sexe_code", "classe_age_insee", "population"])
out.to_csv(OUT, sep=";", index=False)
subprocess.run(["aws", "s3", "cp", OUT, S3, "--only-show-errors"], check=True)

print("Lignes :", len(out), "| années :", out.annee.min(), "-", out.annee.max())
print("Classes d'âge :", sorted(out.classe_age_insee.unique()))
print("Régions par année (dernières) :", out.groupby("annee").region_insee_code.nunique().tail(4).to_dict())
print("Population France 2025 :", out[out.annee == 2025].population.sum())
print("Libellés ignorés :", sorted(inconnus))
