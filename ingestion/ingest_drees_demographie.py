"""Démographie des professionnels de santé (DREES) -> CSV long -> S3 raw.
Source : data.gouv.fr, "La démographie des professionnels de santé depuis 2012"
  - Médecins RPPS 2012-2026 (feuille Effectifs)
  - Psychologues ADELI 2012-2024 (feuille Effectif)
Grain conservé : département x spécialité / secteur x mode d'exercice x année (tous âges, tous sexes).
Les lignes "Ensemble" géographiques sont exclues : les totaux sont recalculés dans dbt.
Exécuté depuis AWS CloudShell : python3 ingest_drees_demographie.py
"""
import subprocess
import pandas as pd

BASE = ("https://data.drees.solidarites-sante.gouv.fr/api/v2/catalog/datasets/"
        "la-demographie-des-professionnels-de-sante-depuis-2012/attachments")
BUCKET = "s3://alex-sante-mentale-620176731553/raw/drees"
TMP = "/tmp/drees"

def code(s):
    """'11-Ile de France' -> '11' ; '001 -Ain' -> '001'"""
    return str(s).split("-", 1)[0].strip()

def libelle(s):
    return str(s).split("-", 1)[1].strip() if "-" in str(s) else str(s).strip()

def to_long(df, dims, nom):
    annees = [c for c in df.columns if str(c).startswith("effectif_")]
    long = df.melt(id_vars=dims, value_vars=annees, var_name="annee", value_name="effectif")
    long["annee"] = long["annee"].str.replace("effectif_", "").astype(int)
    brut = long["effectif"]
    long["effectif"] = pd.to_numeric(brut, errors="coerce")
    print(f"[{nom}] valeurs non numériques (secret, vides) :", int(brut.notna().sum() - long.effectif.notna().sum()))
    return long

def depose(df, nom):
    chemin = f"{TMP}/{nom}.csv"
    df.to_csv(chemin, sep=";", index=False)
    subprocess.run(["aws", "s3", "cp", chemin, f"{BUCKET}/{nom}/{nom}.csv", "--only-show-errors"], check=True)

# ---------- Médecins ----------
subprocess.run(["curl", "-sfL", "-o", f"{TMP}/medecins.xlsx", f"{BASE}/medecins_rpps_2012_2026_xlsx"], check=True)
m = pd.read_excel(f"{TMP}/medecins.xlsx", sheet_name="Effectifs")
m = m[(~m.departement.str.startswith("000"))
      & (m.sexe == "0-Ensemble")
      & (m.tranche_age == "00-Ensemble")]
print("[medecins] lignes départementales dont la région vaut Ensemble :", int((m.region == "00-Ensemble").sum()))
m = to_long(m, ["region", "departement", "specialites_agregees", "specialites", "exercice"], "medecins")
m_out = pd.DataFrame({
    "annee": m.annee,
    "region_insee_code": m.region.map(code),
    "departement_code": m.departement.map(code),
    "departement_libelle": m.departement.map(libelle),
    "specialite_agregee": m.specialites_agregees.map(libelle),
    "specialite_code": m.specialites.map(code),
    "specialite_libelle": m.specialites.map(libelle),
    "exercice_code": m.exercice.map(code),
    "exercice_libelle": m.exercice.map(libelle),
    "effectif": m.effectif,
})
depose(m_out, "medecins_rpps")
psy = m_out[(m_out.specialite_code == "12") & (m_out.exercice_code == "0")]
print("[medecins] lignes :", len(m_out), "| années :", m_out.annee.min(), "-", m_out.annee.max())
print("[medecins] psychiatres France entière par année :", psy.groupby("annee").effectif.sum().astype(int).to_dict())

# ---------- Psychologues ----------
subprocess.run(["curl", "-sfL", "-o", f"{TMP}/psychologues.xlsx", f"{BASE}/psychologues_adeli_2012_2024_xlsx"], check=True)
p = pd.read_excel(f"{TMP}/psychologues.xlsx", sheet_name="Effectif")
p = p[(~p.departement.str.startswith("00"))
      & (p.sexe == "0-Ensemble")
      & (p.tranche_age == "0-Ensemble")]
p = to_long(p, ["region", "departement", "exercice", "secteur_activite"], "psychologues")
p_out = pd.DataFrame({
    "annee": p.annee,
    "region_insee_code": p.region.map(code),
    "departement_code": p.departement.map(code),
    "departement_libelle": p.departement.map(libelle),
    "exercice_code": p.exercice.map(code),
    "exercice_libelle": p.exercice.map(libelle),
    "secteur_code": p.secteur_activite.map(code),
    "secteur_libelle": p.secteur_activite.map(libelle),
    "effectif": p.effectif,
})
depose(p_out, "psychologues_adeli")
tot = p_out[(p_out.exercice_code == "0") & (p_out.secteur_code == "00")]
print("[psychologues] lignes :", len(p_out), "| années :", p_out.annee.min(), "-", p_out.annee.max())
print("[psychologues] total France par année :", tot.groupby("annee").effectif.sum().astype(int).to_dict())
print("[psychologues] régions :", sorted(p_out.region_insee_code.unique()))
