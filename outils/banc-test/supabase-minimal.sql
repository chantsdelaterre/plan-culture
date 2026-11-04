--  Le strict minimum que Supabase fournit et qu'un PostgreSQL nu n'a pas :
--  les deux roles de l'API, le schema ou vivent les extensions, et pgcrypto
--  pour gen_random_uuid(). Rien d'autre : le plan de culture est autonome, il
--  ne lit aucune table du Suivi des temps.
create extension if not exists pgcrypto;
create schema if not exists extensions;
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin; end if;
end $$;

--  Un leurre qui tient la place de la paie du Suivi des temps, pour verifier
--  qu'une migration du plan de culture ne peut pas l'atteindre.
create table if not exists public.paie_leurre (id int primary key, montant numeric);
insert into public.paie_leurre values (1, 2500) on conflict do nothing;
revoke all on public.paie_leurre from public;
