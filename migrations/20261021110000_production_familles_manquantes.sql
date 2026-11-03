-- ============================================================================
-- Plan de culture maraichere - Deux legumes sortis du fourre-tout
--
-- La rotation se controle desormais par famille botanique. Un legume classe
-- 'autre' ne declenchera donc jamais d'alerte : c'est un angle mort, et il y
-- en avait deux parmi les cultures de 2026.
--
--   basilic    -> labiee
--   mais doux  -> graminee
--
-- Au passage, la famille creee sous le nom 'poacee' reprend le nom que Coco
-- emploie, 'graminee'. C'est la meme famille, Poaceae, et c'est son vocabulaire
-- qui doit etre en base.
-- ============================================================================

update production.famille_botanique
   set nom = 'graminée'
 where code = 'FAM13';

update production.legume
   set famille_botanique_id =
       (select id from production.famille_botanique where code = 'FAM12')
 where nom = 'basilic';

update production.legume
   set famille_botanique_id =
       (select id from production.famille_botanique where code = 'FAM13')
 where nom = 'Mais doux';

do $$
declare reste text;
begin
  select string_agg(l.nom, ', ') into reste
    from production.legume l
    join production.famille_botanique f on f.id = l.famille_botanique_id
   where f.code = 'FAM01'
     and exists (select 1 from production.culture c where c.legume_id = l.id);
  if reste is not null then
    raise exception 'Legumes cultives encore classes "autre" : %', reste;
  end if;
end $$;
