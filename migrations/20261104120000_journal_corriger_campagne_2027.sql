-- portee: validation
-- ============================================================================
-- Plan de culture · Corriger une erreur du journal des migrations
--
-- La migration qui installe le mecanisme a inscrit comme « deja faites » les
-- vingt-trois migrations passees a la main. L'une d'elles ne l'etait pas :
-- l'ouverture de la campagne 2027 avait ete preparee et envoyee, mais jamais
-- collee -- la conversation est partie sur l'architecture entre les deux.
--
-- Resultat : le journal affirmait une chose fausse, et le mecanisme aurait
-- saute cette migration pour toujours. La base n'avait que la campagne 2026.
--
-- On retire donc l'affirmation fausse. La migration 2027 revient en meme temps
-- sous un horodatage posterieur au mecanisme, et sera appliquee par lui.
--
-- La lecon, et elle vaut au-dela de ce fichier : un journal qui dit qu'une
-- chose est faite ne la rend pas faite. Ce qui a rattrape l'erreur n'est pas
-- le journal, c'est d'etre alle regarder la base.
-- ============================================================================

delete from production._migrations
 where nom = '20261104100000_production_campagne_2027.sql';

do $$
declare reste integer; campagnes integer;
begin
  select count(*) into reste from production._migrations
   where nom = '20261104100000_production_campagne_2027.sql';
  if reste > 0 then raise exception 'L''entree fausse est toujours la'; end if;

  --  Un garde-fou, pour le jour ou quelqu'un rejouerait ceci sur une base qui
  --  a deja 2027 : on veut le savoir, pas l'ecraser en silence.
  select count(*) into campagnes from production.campagne where libelle = '2027';
  raise notice 'Entree fausse retiree · campagnes 2027 en base : %', campagnes;
end $$;
