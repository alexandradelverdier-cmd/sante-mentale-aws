select
    annee,
    region_insee_code,
    region_insee_libelle,
    sexe_code,
    classe_age_insee,
    population
from {{ source('insee', 'insee_population_region_sexe_gca') }}
