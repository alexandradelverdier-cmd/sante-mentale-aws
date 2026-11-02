-- Mart central : offre de soins et consommation de psychotropes
-- Grain : région Open Medic x année, 2014-2025
with population as (
    select annee, region_code, sum(population_1er_janvier) as population_1er_janvier
    from {{ ref('int_insee__population_open_medic') }}
    group by 1, 2
),

conso as (
    select
        annee,
        region_code,
        max(case when classe_courte = 'antidepresseurs'  then taux_standardise_pour_1000 end) as taux_std_antidepresseurs,
        max(case when classe_courte = 'anxiolytiques'    then taux_standardise_pour_1000 end) as taux_std_anxiolytiques,
        max(case when classe_courte = 'hypnotiques'      then taux_standardise_pour_1000 end) as taux_std_hypnotiques,
        max(case when classe_courte = 'antipsychotiques' then taux_standardise_pour_1000 end) as taux_std_antipsychotiques,
        max(case when classe_courte = 'psychostimulants' then taux_standardise_pour_1000 end) as taux_std_psychostimulants
    from {{ ref('mart_psychotropes__taux_region_annee') }}
    group by 1, 2
)

select
    c.annee,
    c.region_code,
    r.region_libelle,
    p.population_1er_janvier,
    -- Offre de professionnels (stocks au 1er janvier, pour 100 000 habitants)
    o.nb_psychiatres,
    round(100000.0 * o.nb_psychiatres / p.population_1er_janvier, 1)                  as densite_psychiatres,
    round(100000.0 * o.nb_psychiatres_liberaux_mixtes / p.population_1er_janvier, 1)  as densite_psychiatres_liberaux_mixtes,
    round(100000.0 * o.nb_psychiatres_hospitaliers / p.population_1er_janvier, 1)     as densite_psychiatres_hospitaliers,
    o.nb_psychologues,
    round(100000.0 * o.nb_psychologues / p.population_1er_janvier, 1)                 as densite_psychologues,
    round(100000.0 * o.nb_psychologues_liberaux_mixtes / p.population_1er_janvier, 1) as densite_psychologues_liberaux_mixtes,
    -- Offre hospitalière (SAE, pour 100 000 habitants)
    o.nb_lits_psychiatrie,
    o.nb_places_psychiatrie,
    round(100000.0 * o.nb_lits_psychiatrie / p.population_1er_janvier, 1)             as densite_lits_psychiatrie,
    round(100000.0 * o.nb_places_psychiatrie / p.population_1er_janvier, 1)           as densite_places_psychiatrie,
    -- Consommation (taux standardisés âge x sexe, pour 1 000 habitants)
    c.taux_std_antidepresseurs,
    c.taux_std_anxiolytiques,
    c.taux_std_hypnotiques,
    c.taux_std_antipsychotiques,
    c.taux_std_psychostimulants
from conso as c
inner join population as p
    on c.annee = p.annee and c.region_code = p.region_code
inner join {{ ref('int_offre_sante_mentale__region_annee') }} as o
    on c.annee = o.annee and c.region_code = o.region_code
inner join {{ ref('ref_regions') }} as r
    on c.region_code = r.region_code
