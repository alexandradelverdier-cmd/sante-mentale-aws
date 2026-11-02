-- Lits (hospitalisation complète) et places (hospitalisation partielle) de psychiatrie
-- Grain : établissement (FINESS géographique) x année, 2000-2024
select
    annee,
    finess_etablissement,
    finess_entite_juridique,
    raison_sociale,
    categorie_etablissement,
    departement_code,
    region_insee_code,
    coalesce(nb_lits, 0)   as nb_lits,
    coalesce(nb_places, 0) as nb_places,
    nb_sejours_hc,
    nb_journees_hc,
    nb_venues_hp
from {{ source('sae', 'sae_capacites_psychiatrie') }}
