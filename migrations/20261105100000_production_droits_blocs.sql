-- portee: production
-- ============================================================================
-- Plan de culture · Le droit d'écrire sur l'écran des blocs
--
-- Deuxième écriture de l'appli, après la pose. Ce que l'écran des blocs permet,
-- et rien de plus :
--
--   · déplacer une culture d'un bloc à l'autre
--   · changer les mètres d'une variété, ou la variété elle-même
--   · ajouter ou retirer une variété d'une culture
--   · renseigner le type d'une variété et son poids de mille graines
--   · créer une variété qui n'existe pas encore au catalogue
--
-- Les droits sont donnés COLONNE PAR COLONNE partout où c'est possible. Une
-- personne connectée peut changer la longueur d'une affectation ; elle ne peut
-- pas changer sa parcelle depuis cet écran-là, ni toucher aux dates d'une
-- culture, ni la supprimer. Chaque écran ouvre ce dont il a besoin, et on sait
-- lequel a ouvert quoi.
--
-- Pas de `drop policy` ici : une politique se crée si elle manque, à l'intérieur
-- d'un bloc qui vérifie. C'est ce qui permet à cette migration de passer toute
-- seule — la bascule en validation est réservée à ce qui peut détruire.
-- ============================================================================

-- ------------------------------------------- un code pour les variétés créées
--  variete.code est obligatoire et unique. L'appli ne peut pas l'inventer sans
--  risquer une collision quand deux personnes créent en même temps ; c'est donc
--  la base qui le donne, comme elle le fait déjà pour les identifiants.
create sequence if not exists production.variete_code_seq;

do $$
declare dernier integer;
begin
  --  On démarre la séquence au-dessus du plus grand code existant, pour ne
  --  jamais retomber sur un code déjà pris.
  select coalesce(max(substring(code from 2)::integer), 0) into dernier
    from production.variete where code ~ '^V[0-9]+$';
  perform setval('production.variete_code_seq', greatest(dernier, 1));
end $$;

alter table production.variete
  alter column code set default 'V' || lpad(nextval('production.variete_code_seq')::text, 4, '0');

grant usage on sequence production.variete_code_seq to authenticated;

-- ----------------------------------------------------------- déplacer une culture
--  Une culture change de bloc. Rien d'autre : ni ses dates, ni son légume, ni
--  son itinéraire ne se modifient depuis cet écran.
grant update (groupe_assolement_id) on production.culture to authenticated;

-- ------------------------------------------- les quantités et les variétés
--  parcelle_id et unite_debut_id restent hors de cette liste : ils appartiennent
--  à l'écran de pose, qui a déjà son droit à lui.
grant update (longueur_m, variete_id, ordre_plantation, note)
  on production.affectation to authenticated;
grant insert (culture_id, variete_id, longueur_m, ordre_plantation, note)
  on production.affectation to authenticated;
grant delete on production.affectation to authenticated;

-- ------------------------------------------------------- le catalogue variétal
--  note porte le type (« type : conservation ») — un reliquat FileMaker qu'on
--  redressera un jour en colonne propre ; d'ici là c'est bien là qu'on écrit.
--  graines_par_gramme est calculée à partir de pmg : elle ne s'accorde pas.
--  Pas de `delete` sur variete, et c'est voulu : une variété qu'on ne sème plus
--  reste au catalogue, sinon six ans de relevés d'assolement perdraient le nom
--  de ce qui y a poussé. On la retire en passant `actif` à faux.
grant update (nom, note, pmg, pmg_mis_a_jour_le, fournisseur_id, unite_vente, base, actif)
  on production.variete to authenticated;
grant insert (code, nom, legume_id, fournisseur_id, note, pmg, pmg_mis_a_jour_le,
              unite_vente, base, actif)
  on production.variete to authenticated;

-- ------------------------------------------------------------ les politiques
do $$
begin
  if not exists (select 1 from pg_policies
                  where schemaname = 'production' and tablename = 'culture'
                    and policyname = 'culture_changer_de_bloc') then
    create policy culture_changer_de_bloc on production.culture
      for update to authenticated using (true) with check (true);
  end if;

  if not exists (select 1 from pg_policies
                  where schemaname = 'production' and tablename = 'affectation'
                    and policyname = 'affectation_ajouter') then
    create policy affectation_ajouter on production.affectation
      for insert to authenticated with check (true);
  end if;

  if not exists (select 1 from pg_policies
                  where schemaname = 'production' and tablename = 'affectation'
                    and policyname = 'affectation_retirer') then
    create policy affectation_retirer on production.affectation
      for delete to authenticated using (true);
  end if;

  if not exists (select 1 from pg_policies
                  where schemaname = 'production' and tablename = 'variete'
                    and policyname = 'variete_modifier') then
    create policy variete_modifier on production.variete
      for update to authenticated using (true) with check (true);
  end if;

  if not exists (select 1 from pg_policies
                  where schemaname = 'production' and tablename = 'variete'
                    and policyname = 'variete_creer') then
    create policy variete_creer on production.variete
      for insert to authenticated with check (true);
  end if;
end $$;

-- ----------------------------------------------------------------- le contrôle
do $$
declare n integer;
begin
  --  On vérifie la LISTE, pas le compte : elle dit ce qui est ouvert, et elle
  --  se lit. ordre_plantation apparaît une seule fois alors que deux migrations
  --  l'ont accordée — la pose et celle-ci.
  declare ouvertes text;
  begin
    select string_agg(column_name, ', ' order by column_name) into ouvertes
      from information_schema.column_privileges
     where table_schema = 'production' and table_name = 'affectation'
       and grantee = 'authenticated' and privilege_type = 'UPDATE';
    if ouvertes <> 'longueur_m, note, ordre_plantation, parcelle_id, sens, unite_debut_id, variete_id' then
      raise exception 'affectation, colonnes modifiables inattendues : %', ouvertes;
    end if;
  end;

  select count(*) into n from information_schema.column_privileges
   where table_schema = 'production' and table_name = 'culture'
     and grantee = 'authenticated' and privilege_type = 'UPDATE';
  if n <> 1 then
    raise exception 'culture : % colonnes modifiables, 1 attendue', n;
  end if;

  --  Une variété créée doit recevoir son code toute seule.
  if (select column_default from information_schema.columns
       where table_schema = 'production' and table_name = 'variete'
         and column_name = 'code') is null then
    raise exception 'variete.code n''a pas de valeur par defaut';
  end if;

  select count(*) into n from pg_policies
   where schemaname = 'production'
     and policyname in ('culture_changer_de_bloc', 'affectation_ajouter',
                        'affectation_retirer', 'variete_modifier', 'variete_creer');
  if n <> 5 then raise exception '% politiques sur 5 en place', n; end if;

  raise notice 'Écriture ouverte pour l''écran des blocs · 5 politiques, droits colonne par colonne';
end $$;
