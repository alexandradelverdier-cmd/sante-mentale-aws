select
    annee,
    departement_code,
    departement_libelle,
    sexe_code,
    classe_age_insee,
    population
from {{ source('insee', 'insee_population_departement_sexe_gca') }}
