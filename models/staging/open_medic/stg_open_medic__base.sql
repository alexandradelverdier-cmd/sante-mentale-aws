with

v2016 as (
    select
        annee,
        trim(atc1) as atc1_code, trim(l_atc1) as atc1_libelle,
        trim(atc2) as atc2_code, trim(l_atc2) as atc2_libelle,
        trim(atc3) as atc3_code, trim(l_atc3) as atc3_libelle,
        trim(atc4) as atc4_code, trim(l_atc4) as atc4_libelle,
        trim(atc5) as atc5_code, trim(l_atc5) as atc5_libelle,
        trim(cip13) as cip13_code, trim(l_cip13) as cip13_libelle,
        trim(top_gen) as top_generique,
        trim(gen_num) as groupe_generique_num,
        trim(age) as tranche_age_code,
        trim(sexe) as sexe_code,
        trim(ben_reg) as region_code,
        trim(psp_spe) as prescripteur_specialite_code,
        boites, rem, bse
    from {{ source('open_medic', 'open_medic_base') }}
),

v2014 as (
    select
        annee,
        trim(atc1) as atc1_code, cast(null as varchar) as atc1_libelle,
        trim(atc2) as atc2_code, cast(null as varchar) as atc2_libelle,
        trim(atc3) as atc3_code, cast(null as varchar) as atc3_libelle,
        trim(atc4) as atc4_code, cast(null as varchar) as atc4_libelle,
        trim(atc5) as atc5_code, cast(null as varchar) as atc5_libelle,
        trim(cip13) as cip13_code, cast(null as varchar) as cip13_libelle,
        trim(top_gen) as top_generique,
        trim(gen_num) as groupe_generique_num,
        trim(age) as tranche_age_code,
        trim(sexe) as sexe_code,
        trim(ben_reg) as region_code,
        trim(psp_spe) as prescripteur_specialite_code,
        boites, rem, bse
    from {{ source('open_medic', 'open_medic_base_v2014') }}
),

unioned as (
    select * from v2016
    union all
    select * from v2014
)

select
    annee,
    atc1_code, atc1_libelle,
    atc2_code, atc2_libelle,
    atc3_code, atc3_libelle,
    atc4_code, atc4_libelle,
    atc5_code, atc5_libelle,
    cip13_code, cip13_libelle,
    top_generique,
    groupe_generique_num,
    tranche_age_code,
    sexe_code,
    region_code,
    prescripteur_specialite_code,
    cast({{ parse_fr_number('boites') }} as bigint) as nb_boites,
    {{ parse_fr_number('rem') }}                    as montant_rembourse,
    {{ parse_fr_number('bse') }}                    as base_remboursement
from unioned
