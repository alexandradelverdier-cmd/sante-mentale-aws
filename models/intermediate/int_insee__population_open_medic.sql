-- Grain : région Open Medic x tranche d'âge Open Medic x sexe x année
-- DROM regroupés (code 5), PACA + Corse (code 93), comme dans Open Medic
with agregee as (
    select
        p.annee,
        r.region_code,
        a.tranche_age_code,
        p.sexe_code,
        sum(p.population) as population_1er_janvier
    from {{ ref('stg_insee__population') }} as p
    inner join {{ ref('ref_regions_insee') }} as r
        on p.region_insee_code = r.region_insee_code
    inner join {{ ref('ref_classes_age_insee') }} as a
        on p.classe_age_insee = a.classe_age_insee
    group by 1, 2, 3, 4
)

select
    annee,
    region_code,
    tranche_age_code,
    sexe_code,
    population_1er_janvier,
    -- Moyenne entre le 1er janvier N et le 1er janvier N+1 (à défaut, 1er janvier N)
    (population_1er_janvier + coalesce(
        lead(population_1er_janvier) over (
            partition by region_code, tranche_age_code, sexe_code order by annee
        ), population_1er_janvier)) / 2.0 as population_moyenne
from agregee
