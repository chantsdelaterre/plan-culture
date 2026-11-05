-- portee: production
-- ============================================================================
-- Plan de culture · Créer, renommer et vider un bloc
--
-- Scinder un bloc et en fusionner deux ne sont pas deux fonctions : ce sont
-- deux usages d'un seul geste, déplacer des cultures d'un bloc vers un autre.
-- Déplacer, c'est déjà permis (culture.groupe_assolement_id). Ce qui manquait,
-- c'est de pouvoir créer le bloc d'arrivée quand on scinde.
--
-- On ne supprime pas un bloc, même vidé. Il garde son nom, son code et son
-- histoire : l'écran le montre en bas de liste avec zéro culture, pour qu'on
-- le retrouve et qu'on le re-remplisse. Une chose qui existe doit se voir.
-- ============================================================================

-- ------------------------------------------------- un code pour les nouveaux
--  Les codes vont de CA0001 à CA0033. L'appli ne peut pas en inventer un sans
--  risquer la collision : c'est la base qui le donne, comme pour les variétés.
create sequence if not exists production.groupe_assolement_code_seq;

do $$
declare dernier integer;
begin
  select coalesce(max(substring(code from 3)::integer), 0) into dernier
    from production.groupe_assolement where code ~ '^CA[0-9]+$';
  perform setval('production.groupe_assolement_code_seq', greatest(dernier, 1));
end $$;

alter table production.groupe_assolement
  alter column code set default 'CA' || lpad(nextval('production.groupe_assolement_code_seq')::text, 4, '0');

grant usage on sequence production.groupe_assolement_code_seq to authenticated;

-- ----------------------------------------------------------------- les droits
--  code reste ouvert à l'insertion pour le cas où l'on veuille le choisir,
--  mais pas à la modification : un code qui bouge, c'est une référence perdue.
grant insert (code, nom_court, description) on production.groupe_assolement to authenticated;
grant update (nom_court, description) on production.groupe_assolement to authenticated;

-- ------------------------------------------------------------- les politiques
do $$
begin
  if not exists (select 1 from pg_policies
                  where schemaname = 'production' and tablename = 'groupe_assolement'
                    and policyname = 'groupe_assolement_creer') then
    create policy groupe_assolement_creer on production.groupe_assolement
      for insert to authenticated with check (true);
  end if;

  if not exists (select 1 from pg_policies
                  where schemaname = 'production' and tablename = 'groupe_assolement'
                    and policyname = 'groupe_assolement_renommer') then
    create policy groupe_assolement_renommer on production.groupe_assolement
      for update to authenticated using (true) with check (true);
  end if;
end $$;

-- ----------------------------------------------------------------- le contrôle
do $$
declare ouvertes text; n integer;
begin
  select string_agg(column_name, ', ' order by column_name) into ouvertes
    from information_schema.column_privileges
   where table_schema = 'production' and table_name = 'groupe_assolement'
     and grantee = 'authenticated' and privilege_type = 'UPDATE';
  if ouvertes <> 'description, nom_court' then
    raise exception 'groupe_assolement, colonnes modifiables inattendues : %', ouvertes;
  end if;

  --  Pas de delete : un bloc vidé reste, il ne s'efface pas.
  if exists (select 1 from information_schema.table_privileges
              where table_schema = 'production' and table_name = 'groupe_assolement'
                and grantee = 'authenticated' and privilege_type = 'DELETE') then
    raise exception 'Le droit de supprimer un bloc a ete accorde, ce n''etait pas voulu';
  end if;

  if (select column_default from information_schema.columns
       where table_schema = 'production' and table_name = 'groupe_assolement'
         and column_name = 'code') is null then
    raise exception 'groupe_assolement.code n''a pas de valeur par defaut';
  end if;

  select count(*) into n from pg_policies
   where schemaname = 'production'
     and policyname in ('groupe_assolement_creer', 'groupe_assolement_renommer');
  if n <> 2 then raise exception '% politiques sur 2 en place', n; end if;

  raise notice 'Creer et renommer un bloc : ouvert. Supprimer : non, et c''est voulu.';
end $$;
