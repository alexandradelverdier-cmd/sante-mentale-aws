-- Offre de soins en santé mentale au périmètre Open Medic (DROM regroupés, PACA + Corse)
-- Même hypothèse Mayotte que pour la population (inclus_denominateur)
-- Grain : région Open Medic x année (stocks au 1er janvier pour les professionnels, capacités de l'année pour la SAE)
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
),

capacites as (
    select
        r.region_code,
        s.annee,
        sum(s.nb_lits)   as nb_lits_psychiatrie,
        sum(s.nb_places) as nb_places_psychiatrie
    from {{ ref('stg_sae__capacites_psychiatrie') }} as s
    inner join {{ ref('ref_regions_insee') }} as r
        on s.region_insee_code = r.region_insee_code
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
    pl.nb_psychologues_liberaux_mixtes,
    c.nb_lits_psychiatrie,             -- null après 2024 (dernière SAE publiée)
    c.nb_places_psychiatrie
from psychiatres as ps
left join psychologues as pl
    on ps.region_code = pl.region_code and ps.annee = pl.annee
left join capacites as c
    on ps.region_code = c.region_code and ps.annee = c.annee
