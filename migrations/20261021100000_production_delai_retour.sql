-- ============================================================================
-- Plan de culture maraichere - Delai de retour des familles botaniques
--
-- Quatre ans pour toutes les familles. C'est la regle que Coco applique en
-- bio, et elle a l'avantage de ne pas se discuter famille par famille : une
-- planche ne revoit pas la meme famille avant quatre ans, point.
--
-- 'autre' reste a null : ce n'est pas une famille botanique mais le fourre-tout
-- de l'import FileMaker, et lui donner un delai ferait crier l'outil sur des
-- cultures qu'on n'a pas encore classees.
-- ============================================================================

update production.famille_botanique
   set delai_retour_annees = 4
 where code <> 'FAM01';

do $$
declare n integer;
begin
  select count(*) into n from production.famille_botanique
   where delai_retour_annees is null and code <> 'FAM01';
  if n > 0 then
    raise exception '% familles sans delai de retour', n;
  end if;
end $$;
