-- portee: validation
-- ============================================================================
-- Plan de culture · Le proprietaire du schema, et le mecanisme de migration
--
-- Jusqu'ici les migrations arrivaient par copier-coller dans l'editeur SQL de
-- Supabase, sous le role postgres. Deux consequences qu'on a payees :
--
--   1. L'editeur valide instruction par instruction. Une migration qui echoue
--      au milieu laisse la base a moitie modifiee. Quatre allers-retours en
--      octobre sont partis de la.
--   2. postgres peut tout. Une erreur dans une migration du plan de culture
--      pouvait atteindre la paie des quarante personnes de la ferme, qui vit
--      dans le schema public.
--
-- Ce fichier installe le meme garde-fou que le planning : un role qui ne
-- possede que le plan de culture, sous lequel tourneront desormais toutes les
-- migrations automatiques. Une erreur de ce cote ne pourra plus toucher le
-- Suivi des temps, la cantine, ni les comptes.
--
-- C'est la DERNIERE migration a coller a la main. Les suivantes passeront par
-- GitHub, en une seule transaction : elles aboutiront ou ne laisseront rien.
-- ============================================================================

-- ------------------------------------------------------------------ le role
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'production_proprietaire') then
    create role production_proprietaire nologin;
  end if;
end $$;

--  postgres doit pouvoir prendre ce role pour lancer les migrations sous lui.
grant production_proprietaire to postgres with inherit true, set true;

-- ------------------------------------------------- il devient le proprietaire
--  Tout ce qui est dans production lui revient. tracer_historique() est en
--  SECURITY DEFINER : elle tournera donc sous ce role, qui possede aussi la
--  table historique et peut y ecrire malgre la RLS. Les deux changements vont
--  ensemble, c'est pour ca qu'ils sont dans la meme transaction.
alter schema production owner to production_proprietaire;

do $$
declare r record;
begin
  for r in
    select format('alter %s production.%I owner to production_proprietaire',
                  case c.relkind when 'v' then 'view'
                                 when 'm' then 'materialized view'
                                 when 'S' then 'sequence'
                                 else 'table' end,
                  c.relname) as q
      from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'production' and c.relkind in ('r','p','v','m','S')
       --  Une sequence attachee a une colonne suit sa table : Postgres refuse
       --  qu'on lui donne un proprietaire a elle. 'a' couvre les colonnes
       --  serial, 'i' les colonnes d'identite -- il faut les deux.
       and not exists (select 1 from pg_depend d
                        where d.classid = 'pg_class'::regclass and d.objid = c.oid
                          and d.refclassid = 'pg_class'::regclass and d.refobjsubid > 0
                          and d.deptype in ('a','i'))
    loop execute r.q; end loop;

  for r in
    select format('alter function production.%I(%s) owner to production_proprietaire',
                  p.proname, pg_get_function_identity_arguments(p.oid)) as q
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'production'
    loop execute r.q; end loop;

  for r in
    select format('alter type production.%I owner to production_proprietaire', t.typname) as q
      from pg_type t join pg_namespace n on n.oid = t.typnamespace
     where n.nspname = 'production' and t.typtype in ('e','d')
    loop execute r.q; end loop;
end $$;

-- -------------------------------------------------- le journal des migrations
create table if not exists production._migrations (
  nom          text primary key,
  classe       text not null check (classe in ('production', 'validation', 'historique')),
  empreinte    text not null,
  appliquee_le timestamptz not null default now()
);
alter table production._migrations owner to production_proprietaire;

--  Le schema production est publie par l'API. Ce journal n'a rien a y faire :
--  RLS active, aucune politique, aucun droit donne. Il reste invisible.
alter table production._migrations enable row level security;
revoke all on production._migrations from anon, authenticated;

--  Les migrations deja passees a la main sont inscrites comme faites, sinon le
--  mecanisme voudrait les rejouer sur une base qui les a deja.
insert into production._migrations (nom, classe, empreinte) values
  ('20261011090000_production_socle.sql', 'historique', 'avant-mecanisme'),
  ('20261011100000_production_referentiel.sql', 'historique', 'avant-mecanisme'),
  ('20261011110000_production_foncier.sql', 'historique', 'avant-mecanisme'),
  ('20261011120000_production_itineraires.sql', 'historique', 'avant-mecanisme'),
  ('20261011130000_production_plan.sql', 'historique', 'avant-mecanisme'),
  ('20261011140000_production_preaffectation.sql', 'historique', 'avant-mecanisme'),
  ('20261011150000_production_preaffectation_unicite_metrique.sql', 'historique', 'avant-mecanisme'),
  ('20261011160000_production_metrique_de_repli.sql', 'historique', 'avant-mecanisme'),
  ('20261011170000_production_achats.sql', 'historique', 'avant-mecanisme'),
  ('20261011180000_production_stock_conversion_unites.sql', 'historique', 'avant-mecanisme'),
  ('20261011190000_production_stock_valorisation.sql', 'historique', 'avant-mecanisme'),
  ('20261012080000_production_configuration_rangs.sql', 'historique', 'avant-mecanisme'),
  ('20261012090000_production_affectation_sans_parcelle.sql', 'historique', 'avant-mecanisme'),
  ('20261012100000_import_filemaker_2026.sql', 'historique', 'avant-mecanisme'),
  ('20261012110000_production_longueurs_f2.sql', 'historique', 'avant-mecanisme'),
  ('20261020100000_production_parcellaire_reel.sql', 'historique', 'avant-mecanisme'),
  ('20261020110000_production_assolement_releve.sql', 'historique', 'avant-mecanisme'),
  ('20261021100000_production_delai_retour.sql', 'historique', 'avant-mecanisme'),
  ('20261021110000_production_familles_manquantes.sql', 'historique', 'avant-mecanisme'),
  ('20261021120000_production_vue_parcelle_metrique.sql', 'historique', 'avant-mecanisme'),
  ('20261103090000_rattrapage_releve_2024.sql', 'historique', 'avant-mecanisme'),
  ('20261103100000_production_geometrie.sql', 'historique', 'avant-mecanisme'),
  ('20261104100000_production_campagne_2027.sql', 'historique', 'avant-mecanisme'),
  --  Et elle-meme : collee a la main, elle est faite des qu'elle a tourne. Sans
  --  cette ligne le mecanisme voudrait la rejouer a son premier passage.
  ('20261104110000_production_proprietaire.sql', 'historique', 'collee-a-la-main')
on conflict (nom) do nothing;

-- ------------------------------------------------------------ les sauvegardes
--  Une migration destructive copiera d'abord ici les tables qu'elle touche.
--  Schema non publie par l'API : ces copies ne sortent jamais.
create schema if not exists production_sauvegardes;
revoke all on schema production_sauvegardes from public;
alter schema production_sauvegardes owner to production_proprietaire;

-- ---------------------------------------------------------------- le controle
do $$
declare n integer; etrangers integer;
begin
  select count(*) into n from production._migrations;
  if n < 24 then raise exception 'Journal a % migrations, 24 attendues', n; end if;

  select count(*) into etrangers
    from pg_class c join pg_namespace n2 on n2.oid = c.relnamespace
   where n2.nspname = 'production' and c.relkind in ('r','p','v','m')
     and pg_get_userbyid(c.relowner) <> 'production_proprietaire';
  if etrangers > 0 then
    raise exception '% objets de production ont encore un autre proprietaire', etrangers;
  end if;

  raise notice 'production_proprietaire possede le schema · % migrations inscrites', n;
end $$;
