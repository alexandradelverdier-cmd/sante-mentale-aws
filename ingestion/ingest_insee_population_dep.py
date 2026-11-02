"""Population INSEE au 1er janvier par département, sexe et grande classe d'âge -> CSV long -> S3 raw.
Source : https://www.insee.fr/fr/statistiques/8721456 (une feuille par année)
Exécuté depuis AWS CloudShell : python3 ingest_insee_population_dep.py
"""
import re
import subprocess
import pandas as pd

URL = "https://www.insee.fr/fr/statistiques/fichier/8721456/estim-pop-dep-sexe-gca-1975-2026.xlsx"
SRC = "/tmp/insee/pop_dep.xlsx"
OUT = "/tmp/insee/population_departement_sexe_gca.csv"
S3 = ("s3://alex-sante-mentale-620176731553/raw/insee/population_departement_sexe_gca/"
      "population_departement_sexe_gca.csv")
CODE = re.compile(r"^(\d{2,3}|2A|2B)$")
SEXES = {"Hommes": "1", "Femmes": "2"}

subprocess.run(["mkdir", "-p", "/tmp/insee"], check=True)
subprocess.run(["curl", "-sfL", "-o", SRC, URL], check=True)
sheets = pd.read_excel(SRC, sheet_name=None, header=None)

rows, ignores = [], set()
for name, df in sheets.items():
    if not name.isdigit():
        continue
    annee = int(name)
    # Ligne des blocs Ensemble / Hommes / Femmes, puis ligne des classes d'âge juste en dessous
    hdr = next(i for i in range(15) if (df.iloc[i].astype(str).str.strip() == "Hommes").any())
    bloc, entetes = None, []
    for j in range(df.shape[1]):
        v = df.iat[hdr, j]
        if pd.notna(v) and str(v).strip() in ("Ensemble", "Hommes", "Femmes"):
            bloc = str(v).strip()
        entetes.append((j, bloc, str(df.iat[hdr + 1, j]).strip()))
    for i in range(hdr + 2, df.shape[0]):
        code = str(df.iat[i, 0]).strip()
        if code.endswith(".0"):
            code = code[:-2]
        if code.isdigit() and len(code) == 1:
            code = "0" + code
        if not CODE.match(code):
            if code != "nan":
                ignores.add(code[:60])
            continue
        lib = str(df.iat[i, 1]).strip()
        for j, bloc, age in entetes:
            if bloc in SEXES and age != "Total" and pd.notna(df.iat[i, j]):
                rows.append((annee, code, lib, SEXES[bloc], age, int(df.iat[i, j])))

out = pd.DataFrame(rows, columns=["annee", "departement_code", "departement_libelle",
                                  "sexe_code", "classe_age_insee", "population"])
out.to_csv(OUT, sep=";", index=False)
subprocess.run(["aws", "s3", "cp", OUT, S3, "--only-show-errors"], check=True)

print("Lignes :", len(out), "| années :", out.annee.min(), "-", out.annee.max())
print("Classes d'âge :", sorted(out.classe_age_insee.unique()))
print("Départements par année (dernières) :", out.groupby("annee").departement_code.nunique().tail(3).to_dict())
print("Population France 2025 :", out[out.annee == 2025].population.sum())
print("Exemples de codes :", sorted(out.departement_code.unique())[:3], "...", sorted(out.departement_code.unique())[-6:])
print("Premières colonnes ignorées :", sorted(ignores)[:12])
