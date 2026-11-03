-- ============================================================================
-- Plan de culture maraichere - Vue metrique par parcelle
--
-- L'API Supabase plafonne a 1 000 lignes par requete. Les planches sont 1 498 :
-- une page qui les demande toutes en recoit les deux tiers, et calcule des
-- metres faux sans le dire. Le plafond est une bonne chose -- on ne le leve
-- pas, on arrete de demander 1 498 lignes pour en additionner les longueurs.
--
-- Une ligne par parcelle, 31 en tout, et tout ce qu'un ecran demande d'elle.
-- ============================================================================

create or replace view production.v_parcelle_metrique as
select p.id   as parcelle_id,
       p.code,
       p.nom,
       p.ilot_id,
       i.nom  as ilot,
       p.type,
       p.hors_rotation,
       p.azimut_planches,
       p.planche_1_au,
       count(u.id)                                   as nb_planches,
       coalesce(sum(u.longueur_m), 0)::numeric(12,2) as longueur_totale_m,
       coalesce(sum(u.surface_occupee_m2), 0)::numeric(14,2)  as surface_occupee_m2,
       coalesce(sum(u.surface_cultivee_m2), 0)::numeric(14,2) as surface_cultivee_m2,
       coalesce(sum(u.equivalent_120), 0)::numeric(12,3)      as equivalent_120
  from production.parcelle p
  left join production.ilot i on i.id = p.ilot_id
  left join production.unite_culture u on u.parcelle_id = p.id and u.actif
 group by p.id, i.nom;

comment on view production.v_parcelle_metrique is
  'Une ligne par parcelle : ses planches, ses metres lineaires, ses surfaces. '
  'Evite aux ecrans de ramener les 1 498 planches pour en faire la somme, ce '
  'que le plafond de 1 000 lignes de l''API rendrait faux sans le signaler.';

grant select on production.v_parcelle_metrique to anon, authenticated;
