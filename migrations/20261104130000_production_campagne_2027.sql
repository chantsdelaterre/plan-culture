-- portee: validation
-- ============================================================================
-- Plan de culture maraichere · Ouvrir la campagne 2027
--
-- On repart de 2026, mais pas de tout 2026.
--
-- CE QU'ON GARDE : les cultures et leurs quantites. Combien de metres de
-- chaque variete, a quelles dates, dans quel bloc d'assolement. C'est le
-- travail de plusieurs annees d'ajustement, et recommencer d'une page blanche
-- serait le jeter.
--
-- CE QU'ON NE GARDE PAS : l'emplacement. Coco l'a tranche -- "le prevu en
-- terme de localisation n'a pas d'interet, en terme de quantites, oui". Une
-- parcelle reconduite telle quelle, c'est une rotation qu'on ne refait pas.
-- Les affectations arrivent donc sans parcelle_id : elles disent "2 320 m de
-- cette variete", et l'ecran de pose dira ou.
--
-- CE QU'ON NE GARDE PAS NON PLUS : tout ce qui est constate. Dates reelles,
-- rendements, motifs d'annulation appartiennent a 2026 et a elle seule. Les
-- cultures 2027 naissent au statut 'prevue'.
--
-- Les dates prevues glissent d'un an. Certaines cultures hivernent et finis-
-- sent l'annee suivante : leur fin de recolte passe donc en 2029, ce qui est
-- correct.
--
-- Identifiants deterministes (md5 de l'identifiant 2026) : la migration peut
-- etre rejouee sans creer de doublon, et une correction faite ici se reporte
-- au lieu de s'empiler.
-- ============================================================================

-- --------------------------------------------------------------- la campagne
insert into production.campagne (id, libelle, date_debut, date_fin, statut, note)
values (md5('campagne-2027')::uuid, '2027', '2027-01-01', '2027-12-31',
        'preparation',
        'Ouverte le 4 novembre 2026 en reprenant les quantites de 2026, sans les emplacements.')
on conflict (id) do update set
  libelle = excluded.libelle, date_debut = excluded.date_debut,
  date_fin = excluded.date_fin, note = excluded.note;

-- --------------------------------------------------------------- les cultures
insert into production.culture
  (id, code, campagne_id, legume_id, itineraire_id, contexte, numero_semis,
   groupe_assolement_id, fournisseur_plants_id, ordre_plantation,
   est_engrais_vert, en_plein, quantite_prevue, unite_quantite,
   date_semis_prevue, date_plantation_prevue, debut_recolte_prevu,
   fin_recolte_prevue, statut)
select md5('culture-2027-' || c.id::text)::uuid,
       'C27-' || lpad(row_number() over (order by c.code)::text, 3, '0'),
       md5('campagne-2027')::uuid,
       c.legume_id, c.itineraire_id, c.contexte, c.numero_semis,
       c.groupe_assolement_id, c.fournisseur_plants_id, c.ordre_plantation,
       c.est_engrais_vert, c.en_plein, c.quantite_prevue, c.unite_quantite,
       (c.date_semis_prevue      + interval '1 year')::date,
       (c.date_plantation_prevue + interval '1 year')::date,
       (c.debut_recolte_prevu    + interval '1 year')::date,
       (c.fin_recolte_prevue     + interval '1 year')::date,
       'prevue'
  from production.culture c
  join production.campagne a on a.id = c.campagne_id
 where a.libelle = '2026'
   --  Une culture annulee en 2026 n'a pas a revenir par defaut en 2027.
   and c.statut <> 'annulee'
--  On remet a jour ce qui vient de 2026, mais on ne touche a RIEN de ce que
--  2027 aura deja vecu : ni les dates reelles, ni le rendement, ni le statut.
--  Rejouer cette migration en cours de campagne ne doit pas effacer le terrain.
on conflict (id) do update set
  code = excluded.code,
  legume_id = excluded.legume_id,
  itineraire_id = excluded.itineraire_id,
  contexte = excluded.contexte,
  numero_semis = excluded.numero_semis,
  groupe_assolement_id = excluded.groupe_assolement_id,
  fournisseur_plants_id = excluded.fournisseur_plants_id,
  ordre_plantation = excluded.ordre_plantation,
  est_engrais_vert = excluded.est_engrais_vert,
  en_plein = excluded.en_plein,
  quantite_prevue = excluded.quantite_prevue,
  unite_quantite = excluded.unite_quantite,
  date_semis_prevue = excluded.date_semis_prevue,
  date_plantation_prevue = excluded.date_plantation_prevue,
  debut_recolte_prevu = excluded.debut_recolte_prevu,
  fin_recolte_prevue = excluded.fin_recolte_prevue;

-- ------------------------------------------------------------ les affectations
--  parcelle_id et unite_debut_id restent nuls : c'est tout le propos. La
--  longueur et la variete, elles, traversent -- ce sont les quantites.
insert into production.affectation
  (id, code, culture_id, variete_id, parcelle_id, unite_debut_id,
   longueur_m, ordre_plantation, nb_caisses_force, note)
select md5('affectation-2027-' || f.id::text)::uuid,
       'A27-' || lpad(row_number() over (order by f.code)::text, 4, '0'),
       md5('culture-2027-' || f.culture_id::text)::uuid,
       f.variete_id, null, null,
       f.longueur_m, f.ordre_plantation, f.nb_caisses_force, f.note
  from production.affectation f
  join production.culture c  on c.id = f.culture_id
  join production.campagne a on a.id = c.campagne_id
 where a.libelle = '2026' and c.statut <> 'annulee'
--  parcelle_id et unite_debut_id sont absents de cette mise a jour, et c'est
--  volontaire : rejouer la migration apres avoir commence a poser des blocs ne
--  doit pas balayer le travail de placement.
on conflict (id) do update set
  code = excluded.code, culture_id = excluded.culture_id,
  variete_id = excluded.variete_id, longueur_m = excluded.longueur_m,
  ordre_plantation = excluded.ordre_plantation,
  nb_caisses_force = excluded.nb_caisses_force, note = excluded.note;

-- ----------------------------------------------------------------- le controle
--  Les controles sont ecrits pour rester vrais si la migration est rejouee en
--  cours de campagne : ils verifient que le report est complet, pas que 2027
--  est restee intacte -- elle a le droit d'avoir vecu entre-temps.
do $$
declare orphelines integer; sans_affectation integer;
        n2027 integer; m2027 numeric; placees integer; total integer;
begin
  --  Toute culture 2026 doit avoir son jumeau 2027. C'est l'invariant du
  --  report : s'il manque quelqu'un, le select d'au-dessus a filtre trop.
  select count(*) into orphelines
    from production.culture c
    join production.campagne a on a.id = c.campagne_id
   where a.libelle = '2026' and c.statut <> 'annulee'
     and not exists (select 1 from production.culture d
                      where d.id = md5('culture-2027-' || c.id::text)::uuid);
  if orphelines > 0 then
    raise exception '% cultures 2026 sans jumelle en 2027', orphelines;
  end if;

  --  Aucune affectation 2026 ne doit avoir perdu ses metres en route.
  select count(*) into sans_affectation
    from production.affectation f
    join production.culture c  on c.id = f.culture_id
    join production.campagne a on a.id = c.campagne_id
   where a.libelle = '2026' and c.statut <> 'annulee'
     and not exists (select 1 from production.affectation g
                      where g.id = md5('affectation-2027-' || f.id::text)::uuid
                        and g.longueur_m = f.longueur_m);
  if sans_affectation > 0 then
    raise exception '% affectations 2026 sans report fidele en 2027', sans_affectation;
  end if;

  select count(*) into n2027 from production.culture c
    join production.campagne a on a.id = c.campagne_id where a.libelle = '2027';
  select count(*), round(sum(f.longueur_m)),
         count(*) filter (where f.parcelle_id is not null)
    into total, m2027, placees
    from production.affectation f
    join production.culture c  on c.id = f.culture_id
    join production.campagne a on a.id = c.campagne_id where a.libelle = '2027';

  raise notice '2027 : % cultures, % affectations, % metres, % deja posees',
    n2027, total, m2027, placees;
end $$;

-- ============================================================================
-- Le droit de poser
--
-- Premiere ecriture de l'appli : une personne connectee peut placer une
-- affectation sur une parcelle. Rien d'autre.
--
-- Le droit est donne COLONNE PAR COLONNE, pas sur la table. Poser un bloc,
-- c'est dire ou et dans quel sens ; ce n'est pas changer combien de metres on
-- seme, ni quelle variete. Ces colonnes-la s'ouvriront quand un ecran en aura
-- besoin, et on saura alors lequel. Un droit trop large accorde aujourd'hui
-- serait un droit que plus personne ne questionne dans deux ans.
--
-- Chaque pose laisse une trace : le declencheur affectation_audit enregistre
-- l'avant, l'apres et l'auteur dans production.historique.
-- ============================================================================

drop policy if exists affectation_pose on production.affectation;
create policy affectation_pose on production.affectation
  for update to authenticated using (true) with check (true);

grant update (parcelle_id, unite_debut_id, sens, ordre_plantation)
  on production.affectation to authenticated;

do $$
declare n integer;
begin
  select count(*) into n from information_schema.column_privileges
   where table_schema = 'production' and table_name = 'affectation'
     and grantee = 'authenticated' and privilege_type = 'UPDATE';
  if n <> 4 then
    raise exception 'La pose devrait ouvrir 4 colonnes, elle en ouvre %', n;
  end if;
  raise notice 'Pose autorisee aux personnes connectees, sur 4 colonnes.';
end $$;
