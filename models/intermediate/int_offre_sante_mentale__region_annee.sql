-- Offre de soins en santé mentale au périmètre Open Medic (DROM regroupés, PACA + Corse)
-- Même hypothèse Mayotte que pour la population (inclus_denominateur)
-- Grain : région Open Medic x année (stocks au 1er janvier)
with psychiatres as (
    select
        r.region_code,
        p.annee,
        sum(case when p.exercice_code = '0' then p.nb_psychiatres else 0 end)         as nb_psychiatres,
        sum(case when p.exercice_code in ('1', '2') then p.nb_psychiatres else 0 end) as nb_psychiatres_liberaux_mixtes,
        sum(case when p.exercice_code = '3' then p.nb_psychiatres else 0 end)         as nb_psychiatres_hospitaliers
    from {{ ref('stg_drees__psychiatres') }} as p
    inner join {{ ref('ref_regions_insee') }} as r
        on p.region_insee_code = r.region_insee_code
       and r.inclus_denominateur
    group by 1, 2
),

psychologues as (
    select
        r.region_code,
        p.annee,
        sum(case when p.exercice_code = '0' then p.nb_psychologues else 0 end) as nb_psychologues,
        sum(case when p.exercice_code = '1' then p.nb_psychologues else 0 end) as nb_psychologues_liberaux_mixtes
    from {{ ref('stg_drees__psychologues') }} as p
    inner join {{ ref('ref_regions_insee') }} as r
        on p.region_insee_code = r.region_insee_code
       and r.inclus_denominateur
    group by 1, 2
)

select
    ps.region_code,
    ps.annee,
    ps.nb_psychiatres,
    ps.nb_psychiatres_liberaux_mixtes,
    ps.nb_psychiatres_hospitaliers,
    pl.nb_psychologues,                -- null après 2024 (fin de la série ADELI)
    pl.nb_psychologues_liberaux_mixtes
from psychiatres as ps
left join psychologues as pl
    on ps.region_code = pl.region_code and ps.annee = pl.annee
