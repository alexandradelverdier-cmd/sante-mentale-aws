-- Offre de soins en santé mentale par département
-- Grain : département x année, 2012-2026 (psychologues jusqu'en 2024, lits et places jusqu'en 2024)
-- Mayotte incluse : pas de croisement avec Open Medic à ce niveau
with psychiatres as (
    select
        annee,
        {{ departement_insee('departement_code') }} as departement_code,
        max(region_insee_code) as region_insee_code,
        sum(case when exercice_code = '0' then nb_psychiatres else 0 end)         as nb_psychiatres,
        sum(case when exercice_code in ('1', '2') then nb_psychiatres else 0 end) as nb_psychiatres_liberaux_mixtes,
        sum(case when exercice_code = '3' then nb_psychiatres else 0 end)         as nb_psychiatres_hospitaliers
    from {{ ref('stg_drees__psychiatres') }}
    where region_insee_code <> '99'   -- COM et étranger
    group by 1, 2
),

psychologues as (
    select
        annee,
        {{ departement_insee('departement_code') }} as departement_code,
        sum(case when exercice_code = '0' then nb_psychologues end) as nb_psychologues,
        sum(case when exercice_code = '1' then nb_psychologues end) as nb_psychologues_liberaux_mixtes
    from {{ ref('stg_drees__psychologues') }}
    group by 1, 2
),

capacites as (
    select
        annee,
        departement_code,
        sum(nb_lits)   as nb_lits_psychiatrie,
        sum(nb_places) as nb_places_psychiatrie
    from {{ ref('stg_sae__capacites_psychiatrie') }}
    group by 1, 2
),

population as (
    select
        annee,
        departement_code,
        max(departement_libelle) as departement_libelle,
        sum(population)          as population
    from {{ ref('stg_insee__population_departement') }}
    group by 1, 2
),

regions as (
    select distinct region_insee_code, region_insee_libelle
    from {{ ref('ref_regions_insee') }}
),

final as (
    select
        ps.annee,
        ps.departement_code,
        p.departement_libelle,
        ps.region_insee_code,
        r.region_insee_libelle,
        p.population,
        ps.nb_psychiatres,
        ps.nb_psychiatres_liberaux_mixtes,
        ps.nb_psychiatres_hospitaliers,
        pl.nb_psychologues,
        pl.nb_psychologues_liberaux_mixtes,
        c.nb_lits_psychiatrie,
        c.nb_places_psychiatrie,
        round(100000.0 * ps.nb_psychiatres / p.population, 1)                  as densite_psychiatres,
        round(100000.0 * ps.nb_psychiatres_liberaux_mixtes / p.population, 1)  as densite_psychiatres_liberaux_mixtes,
        round(100000.0 * ps.nb_psychiatres_hospitaliers / p.population, 1)     as densite_psychiatres_hospitaliers,
        round(100000.0 * pl.nb_psychologues / p.population, 1)                 as densite_psychologues,
        round(100000.0 * pl.nb_psychologues_liberaux_mixtes / p.population, 1) as densite_psychologues_liberaux_mixtes,
        round(100000.0 * c.nb_lits_psychiatrie / p.population, 1)              as densite_lits_psychiatrie,
        round(100000.0 * c.nb_places_psychiatrie / p.population, 1)            as densite_places_psychiatrie
    from psychiatres as ps
    left join population as p
        on ps.annee = p.annee and ps.departement_code = p.departement_code
    left join psychologues as pl
        on ps.annee = pl.annee and ps.departement_code = pl.departement_code
    left join capacites as c
        on ps.annee = c.annee and ps.departement_code = c.departement_code
    left join regions as r
        on ps.region_insee_code = r.region_insee_code
)

select
    *,
    -- 1 = quart des départements les moins dotés, l'année considérée
    ntile(4) over (partition by annee order by densite_psychiatres_liberaux_mixtes) as quartile_psychiatres_liberaux,
    ntile(4) over (partition by annee order by densite_psychologues)                as quartile_psychologues
from final
