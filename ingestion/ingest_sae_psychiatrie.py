"""Capacités en psychiatrie (SAE, DREES, série longue CAPACT_PM_PNM) -> CSV -> S3 raw.
Source : data.drees, "Bases statistiques SAE", fichier CAPACT_PM_PNM.7z (capact0024.csv)
Grain conservé : établissement (FINESS géographique) x année, discipline Psychiatrie (22000) uniquement.
Les codes département des DROM propres à la SAE (9A à 9F) sont convertis en codes INSEE (971 à 976).
Exécuté depuis AWS CloudShell : pip3 install py7zr pandas && python3 ingest_sae_psychiatrie.py
"""
import subprocess
import pandas as pd
import py7zr

URL = ("https://data.drees.solidarites-sante.gouv.fr/api/v2/catalog/datasets/"
       "708_bases-statistiques-sae/attachments/capact_pm_pnm_7z")
TMP = "/tmp/sae"
CSV_SOURCE = "CAPACT_PM_PNM/Bases CSV/capact0024.csv"
OUT = f"{TMP}/sae_capacites_psychiatrie.csv"
S3 = "s3://alex-sante-mentale-620176731553/raw/sae/capacites_psychiatrie/sae_capacites_psychiatrie.csv"
DROM = {"9A": "971", "9B": "972", "9C": "973", "9D": "974", "9F": "976"}

subprocess.run(["mkdir", "-p", TMP], check=True)
subprocess.run(["curl", "-sfL", "-o", f"{TMP}/capact.7z", URL], check=True)
with py7zr.SevenZipFile(f"{TMP}/capact.7z") as z:
    z.extract(targets=[CSV_SOURCE], path=TMP)

df = pd.read_csv(f"{TMP}/{CSV_SOURCE}", sep=";", encoding="latin1", dtype=str)
psy = df[df.DISCI == "22000"].copy()

sans_dep = psy[psy.dep.isna()]
print("Lignes sans département exclues :", len(sans_dep), "| lits :",
      int(pd.to_numeric(sans_dep.LIT, errors="coerce").sum()))
psy = psy[psy.dep.notna()]

psy["departement_code"] = psy.dep.str.strip().replace(DROM)
out = pd.DataFrame({
    "annee": psy.an.astype(int),
    "finess_etablissement": psy.fi,
    "finess_entite_juridique": psy.fi_ej,
    "raison_sociale": psy.rs,
    "categorie_etablissement": psy["cat"],
    "departement_code": psy.departement_code,
    "region_insee_code": psy.reg,
    "nb_lits": pd.to_numeric(psy.LIT, errors="coerce"),
    "nb_places": pd.to_numeric(psy.PLA, errors="coerce"),
    "nb_sejours_hc": pd.to_numeric(psy.SEJHC, errors="coerce"),
    "nb_journees_hc": pd.to_numeric(psy.JOU, errors="coerce"),
    "nb_venues_hp": pd.to_numeric(psy.PAS, errors="coerce"),
})
out.to_csv(OUT, sep=";", index=False, float_format="%.0f")
subprocess.run(["aws", "s3", "cp", OUT, S3, "--only-show-errors"], check=True)

print("Lignes :", len(out), "| années :", out.annee.min(), "-", out.annee.max())
print("Départements 2024 :", out[out.annee == 2024].departement_code.nunique(),
      "| exemples :", sorted(out.departement_code.unique())[-7:])
print("Lits / places 2024 :", int(out[out.annee == 2024].nb_lits.sum()), "/", int(out[out.annee == 2024].nb_places.sum()))
print("Doublons établissement x année :", int(out.duplicated(["finess_etablissement", "annee"]).sum()))
