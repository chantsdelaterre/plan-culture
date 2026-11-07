-- portee: production
-- ============================================================================
-- Plan de culture · Le référentiel agronomique : rendements, exportations,
-- unités commerciales, durées manquantes
--
-- D'OÙ VIENNENT CES CHIFFRES, ET CE QU'ILS VALENT
--
-- Ils ont été produits le 7 novembre 2026 par un modèle de langage, à la
-- demande de Coco, puis recoupés avant d'entrer ici. Ce ne sont PAS des
-- mesures : ce sont des estimations de départ, destinées à être corrigées
-- par l'expérience. C'est pourquoi chaque ligne porte sa fiabilité et sa
-- source, et c'est pourquoi tous les remplissages de cette migration sont
-- en `coalesce` : une valeur déjà présente n'est JAMAIS écrasée. Le jour où
-- Coco corrige un rendement depuis l'écran, un rejeu ne le défait pas.
--
-- CE QUI A ÉTÉ VÉRIFIÉ avant de les retenir :
--   · les 86 rendements sont cohérents avec le poids unitaire et le taux de
--     réussite que la source annonce elle-même — zéro écart ;
--   · pour les cultures à la pièce, pièces/are = plants/are x taux, exact ;
--   · les exportations N-P-K sont identiques entre itinéraires d'un même
--     légume, sauf la pomme de terre (primeur contre demi-primeur), ce qui
--     est normal ;
--   · à l'échelle de la ferme, cela donne 711 t et 545 000 pièces ou bottes
--     sur 3 008 ares — ordre de grandeur validé par Coco.
--
-- UN POINT FAIBLE CONNU, laissé tel quel faute de mieux : les aromatiques
-- coupées (persil, basilic, coriandre, aneth, livèche, ciboulette) totalisent
-- 205 000 bottes. La source a chiffré ce que la plante PEUT produire ; sur
-- une aromatique la limite est le marché, pas la plante. À corriger par les
-- volumes réellement écoulés.
--
-- DEUX DENSITÉS CORRIGÉES, valeurs données par Coco :
--   · ITK017 chou brocoli : 25 plants/m etait faux (4 rangs a 16 cm).
--     Passe en 2 rangs a 50 cm sur le rang, soit 4 plants/m, comme les deux
--     autres brocolis.
--   · ITK065 persil racine : 400 plants/m etait faux (4 rangs a 1 cm).
--     Passe a 4 cm sur le rang, soit 100 plants/m.
--
-- CONVENTION DE RENDEMENT : `rendement_attendu` est une quantité **par are**,
-- et `unite_rendement` dit laquelle — kg, u (pièce) ou botte. L'are, et pas
-- l'hectare ni le mètre : c'est l'unité dans laquelle Coco raisonne.
-- ============================================================================

-- ------------------------------------------------- une unité qui manquait
--  unite_rendement est une clé étrangère vers production.unite, qui ne
--  connaissait pas la botte. Un tiers des cultures se vend comme ça.
insert into production.unite (code, libelle, dimension)
select 'botte', 'botte', 'comptage'
where not exists (select 1 from production.unite where code = 'botte');

-- ------------------------------------------------------- les colonnes neuves
--  `fixation` existe déjà mais en texte : on ne touche pas, on ajoute une
--  colonne chiffrée à côté.
alter table production.itineraire
  add column if not exists export_n_kg_par_tonne     numeric(8,3) check (export_n_kg_par_tonne >= 0),
  add column if not exists export_p2o5_kg_par_tonne  numeric(8,3) check (export_p2o5_kg_par_tonne >= 0),
  add column if not exists export_k2o_kg_par_tonne   numeric(8,3) check (export_k2o_kg_par_tonne >= 0),
  add column if not exists fixation_n_kg_ha          numeric(8,2) check (fixation_n_kg_ha >= 0),
  add column if not exists taux_reussite_pct         numeric(5,2) check (taux_reussite_pct between 0 and 100),
  add column if not exists rendement_fiabilite       text,
  add column if not exists rendement_note            text,
  add column if not exists reference_source          text;

comment on column production.itineraire.rendement_attendu is
  'Quantité attendue PAR ARE. L''unité est dans unite_rendement : kg, u (pièce) ou botte.';
comment on column production.itineraire.rendement_fiabilite is
  'haute / moyenne / basse — telle que déclarée par la source. Aucune de ces valeurs n''est une mesure.';

alter table production.legume
  add column if not exists unite_commerciale    text,
  add column if not exists poids_moyen_piece_g  numeric(8,1) check (poids_moyen_piece_g > 0);

comment on column production.legume.unite_commerciale is
  'Comment le légume se vend : kg, piece ou botte. Décide de la lecture de itineraire.rendement_attendu.';

-- ------------------------------------------- les deux densités à corriger
--  La densité n'est pas une colonne : elle se déduit de la configuration de
--  rangs et de l'espacement sur le rang. C'est donc là qu'on corrige.
update production.itineraire i
   set configuration_rangs_id = cr.id,
       espacement_sur_rang_cm = 50.0
  from production.configuration_rangs cr
 where i.code = 'ITK017' and cr.code = 'R2'
   and i.espacement_sur_rang_cm is distinct from 50.0;

update production.itineraire
   set espacement_sur_rang_cm = 4.0
 where code = 'ITK065'
   and espacement_sur_rang_cm is distinct from 4.0;

-- ------------------------------------------- le référentiel par itinéraire
--  coalesce partout : on remplit les trous, on n'écrase jamais.
update production.itineraire i set
  rendement_attendu        = coalesce(i.rendement_attendu, v.rendement),
  unite_rendement          = coalesce(i.unite_rendement, v.unite),
  taux_reussite_pct        = coalesce(i.taux_reussite_pct, v.taux),
  export_n_kg_par_tonne    = coalesce(i.export_n_kg_par_tonne, v.n),
  export_p2o5_kg_par_tonne = coalesce(i.export_p2o5_kg_par_tonne, v.p),
  export_k2o_kg_par_tonne  = coalesce(i.export_k2o_kg_par_tonne, v.k),
  fixation_n_kg_ha         = coalesce(i.fixation_n_kg_ha, v.fixation),
  rendement_fiabilite      = coalesce(i.rendement_fiabilite, v.fiabilite),
  rendement_note           = coalesce(i.rendement_note, v.note),
  reference_source         = coalesce(i.reference_source, v.source),
  duree_en_place_jours     = coalesce(i.duree_en_place_jours, v.duree_place::smallint),
  duree_recolte_jours      = coalesce(i.duree_recolte_jours, v.duree_recolte::smallint)
from (values
  ('ITK001', 85.0, 'kg', null, 11.3, 5.4, 7.1, null, 'moyenne', '85% commercialisables, bulbes secs moyens 51 g.', '[IRDA 2024 tableau 20](https://irda.qc.ca/media/p1ulsnms/irda-developpementstrategiesfertilisationailbio.pdf) pour NPK. Rendement BIO estimé', 225.0, 49.0),
  ('ITK002', 1200.0, 'botte', null, 4.0, 1.0, 5.0, null, 'basse', 'Cumul saison, 50 g/botte, 41 g/motte implantée.', 'Estimation agronomique BIO non mesurée pour rendement et durées. NPK estimés des tiges feuillées', 45.0, 14.0),
  ('ITK003', 3000.0, 'botte', null, 4.0, 1.0, 5.0, null, 'moyenne', 'Cumul saison, 50 g/botte, 192 g/motte implantée.', 'Estimation agronomique BIO non mesurée. NPK estimés des tiges feuillées', 49.0, 91.0),
  ('ITK004', 400.0, 'kg', null, 2.5, 0.8, 5.0, null, 'moyenne', 'Cumul saison, 907 g/pied implanté, côtes et feuilles.', 'Estimation agronomique BIO non mesurée. NPK estimés des feuilles avec côtes', 56.0, 77.0),
  ('ITK005', 330.0, 'kg', null, 2.5, 1.0, 4.0, null, 'moyenne', '80% commercialisables, racines moyennes 211 g.', 'Estimation agronomique BIO non mesurée. NPK estimés des racines seules', 84.0, 28.0),
  ('ITK006', 350.0, 'kg', null, 2.5, 1.0, 4.0, null, 'moyenne', '70% commercialisables, racines moyennes 191 g.', 'Estimation agronomique BIO non mesurée. NPK estimés des racines seules', 77.0, 42.0),
  ('ITK007', 500.0, 'kg', null, 1.56, 0.83, 4.3, null, 'basse', 'Après éclaircissage, 40% graines commercialisées, racines moyennes 96 g.', '[MAPAQ grilles carotte tableau 2](https://cdn-contenu.quebec.ca/cdn-contenu/adm/min/agriculture-pecheries-alimentation/agriculture/pratiques-agricoles-et-environnement/GR_fertilisation_carottes_pois_h', 98.0, 17.0),
  ('ITK008', 450.0, 'kg', null, 1.56, 0.83, 4.3, null, 'moyenne', '60% graines commercialisées, racines moyennes 89 g.', 'MAPAQ grilles carotte tableau 2 pour NPK. Rendement BIO estimé', 91.0, 49.0),
  ('ITK009', 500.0, 'kg', null, 1.56, 0.83, 4.3, null, 'moyenne', '60% graines commercialisées, racines moyennes 99 g.', 'MAPAQ grilles carotte tableau 2 pour NPK. Rendement BIO estimé', 98.0, 42.0),
  ('ITK010', 340.0, 'u', 85.0, 1.5, 0.7, 5.0, null, 'moyenne', '85% des plants, un pied commercial par plant réussi.', 'Estimation agronomique BIO non mesurée du taux. NPK estimés du pied paré avec feuilles', 126.0, 63.0),
  ('ITK011', 340.0, 'kg', null, 2.0, 1.0, 5.0, null, 'moyenne', '85% commercialisables, raves parées moyennes 1000 g.', '[COMIFER teneurs azote 2013 tableau légumes](https://comifer.asso.fr/wp-content/uploads/2015/03/Document-methodologique.pdf) pour N. Rendement BIO et PK estimés', 129.0, 45.0),
  ('ITK012', 665.0, 'u', 85.0, 2.2, 0.7, 4.0, null, 'moyenne', '85% des plants, une chicorée par plant réussi.', 'COMIFER teneurs azote 2013 pour N. [Bejo Indigo](https://www.bejo.fr/chicoree-rouge/indigo) pour identification. Taux BIO et PK estimés', 35.0, 21.0),
  ('ITK013', 400.0, 'kg', null, 2.5, 1.3, 4.3, null, 'moyenne', '85% commercialisables, pommes moyennes 1600 g.', '[COMIFER PKMg 2019 tableau légumes](https://comifer.asso.fr/wp-content/uploads/2015/03/COMIFER_RAPPORT_fertilisation_15102019.pdf) pour PK. Rendement BIO et N estimés', 70.0, 28.0),
  ('ITK014', 450.0, 'kg', null, 2.5, 1.3, 4.3, null, 'moyenne', '85% commercialisables, pommes moyennes 2250 g.', 'COMIFER PKMg 2019 tableau légumes pour PK. Rendement BIO et N estimés', 84.0, 63.0),
  ('ITK015', 100.0, 'kg', null, 4.5, 1.4, 3.95, null, 'moyenne', '85% commercialisables, têtes moyennes 500 g.', 'COMIFER teneurs azote 2013 et PKMg 2019 tableaux légumes. Rendement BIO estimé', 91.0, 28.0),
  ('ITK016', 90.0, 'kg', null, 4.5, 1.4, 3.95, null, 'moyenne', '80% commercialisables, têtes moyennes 480 g.', 'COMIFER teneurs azote 2013 et PKMg 2019 tableaux légumes. Rendement BIO estimé', 77.0, 28.0),
  ('ITK017', 100.0, 'kg', null, 4.5, 1.4, 3.95, null, 'moyenne', 'Deux rangs, 75 cm entre rangs, 85% commercialisables, 500 g/tête.', 'COMIFER teneurs azote 2013 et PKMg 2019 tableaux légumes. Rendement BIO provisoire par analogie ITK016', 70.0, 28.0),
  ('ITK018', 180.0, 'kg', null, 5.0, 1.5, 4.0, null, 'moyenne', 'Cumul saison, 766 g/pied implanté, bourgeons seuls.', 'Estimation agronomique BIO non mesurée. NPK estimés des bourgeons seuls et non de la plante entière', 91.0, 84.0),
  ('ITK019', 626.0, 'u', 80.0, 2.0, 0.7, 3.5, null, 'moyenne', '80% des plants, une pomme par plant réussi.', 'Estimation agronomique BIO non mesurée du taux. NPK estimés des pommes parées', 35.0, 42.0),
  ('ITK020', 188.0, 'u', 80.0, 2.5, 1.0, 4.0, null, 'moyenne', '80% des plants, une tête par plant réussi.', 'COMIFER teneurs azote 2013 et PKMg 2019 tableaux légumes été-automne. Taux BIO estimé', 91.0, 28.0),
  ('ITK021', 176.0, 'u', 75.0, 2.5, 1.0, 4.0, null, 'moyenne', '75% des plants, une tête par plant réussi.', 'COMIFER teneurs azote 2013 et PKMg 2019 tableaux légumes été-automne. Taux BIO estimé', 98.0, 14.0),
  ('ITK022', 600.0, 'botte', null, 4.0, 1.0, 4.5, null, 'moyenne', 'Cumul saison, 300 g/botte, 510 g/pied implanté.', 'Estimation agronomique BIO non mesurée. NPK estimés des feuilles avec pétioles', 84.0, 35.0),
  ('ITK023', 400.0, 'kg', null, 2.5, 1.3, 4.3, null, 'moyenne', '85% commercialisables, pommes moyennes 2000 g.', 'COMIFER PKMg 2019 chou pommé pour PK. Rendement BIO et N estimés', 98.0, 98.0),
  ('ITK024', 250.0, 'u', 85.0, 2.5, 1.3, 4.3, null, 'moyenne', '85% des plants, une pomme par plant réussi.', 'COMIFER PKMg 2019 chou pommé pour PK. Taux BIO et N estimés', 70.0, 28.0),
  ('ITK025', 665.0, 'u', 85.0, 2.0, 0.8, 3.5, null, 'moyenne', '85% des plants, une boule par plant réussi.', 'Estimation agronomique BIO non mesurée du taux. NPK estimés de la boule parée', 49.0, 28.0),
  ('ITK026', 665.0, 'u', 85.0, 2.0, 0.8, 3.5, null, 'moyenne', '85% des plants, une boule par plant réussi.', 'Estimation agronomique BIO non mesurée du taux. NPK estimés de la boule parée', 56.0, 21.0),
  ('ITK027', 188.0, 'u', 80.0, 2.5, 1.0, 4.0, null, 'moyenne', '80% des plants, une tête par plant réussi.', 'COMIFER tableaux légumes chou-fleur été-automne par analogie explicite. Taux BIO estimé', 80.0, 24.0),
  ('ITK028', 400.0, 'kg', null, 2.5, 1.3, 4.3, null, 'moyenne', '85% commercialisables, pommes moyennes 2000 g.', 'COMIFER PKMg 2019 chou pommé pour PK. Rendement BIO et N estimés', 84.0, 63.0),
  ('ITK029', 400.0, 'kg', null, 2.5, 1.3, 4.3, null, 'moyenne', '85% commercialisables, pommes moyennes 2000 g.', 'COMIFER PKMg 2019 chou pommé pour PK. Rendement BIO et N estimés', 91.0, 49.0),
  ('ITK030', 330.0, 'kg', null, 2.0, 0.8, 3.5, null, 'moyenne', '85% commercialisables, racines moyennes 500 g.', 'Estimation agronomique BIO non mesurée. NPK estimés des racines seules', 56.0, 35.0),
  ('ITK031', 2400.0, 'botte', null, 4.0, 1.0, 4.0, null, 'basse', 'Cumul saison, 30 g/botte, 37 g/motte implantée.', 'Estimation agronomique BIO non mesurée. NPK estimés des feuilles coupées', 35.0, 49.0),
  ('ITK032', 1200.0, 'botte', null, 4.0, 1.0, 5.0, null, 'basse', 'Cumul saison, 50 g/botte, 41 g/motte implantée.', 'Estimation agronomique BIO non mesurée. NPK estimés des tiges feuillées', 77.0, 14.0),
  ('ITK033', 300.0, 'kg', null, 2.0, 0.7, 3.5, null, 'basse', 'Petites courges supposées, densité élevée, 1890 g/plant implanté.', 'Estimation agronomique BIO non mesurée. NPK estimés des fruits entiers', 84.0, 35.0),
  ('ITK034', 280.0, 'kg', null, 2.0, 0.7, 3.5, null, 'basse', 'Petites courges supposées, densité élevée, 1760 g/graine semée.', 'Estimation agronomique BIO non mesurée. NPK estimés des fruits entiers', 91.0, 35.0),
  ('ITK035', 600.0, 'kg', null, 2.2, 0.65, 2.1, null, 'moyenne', 'Cumul saison, 6000 g/pied implanté, fruits triés.', 'COMIFER teneurs azote 2013 et PKMg 2019 tableaux légumes. Rendement BIO estimé', 49.0, 91.0),
  ('ITK036', 180.0, 'kg', null, 2.3, 1.0, 4.0, null, 'basse', '65% graines commercialisées, échalotes moyennes 28 g.', 'COMIFER teneurs azote 2013 pour N. [Agrosemens catalogue 2026 échalote](https://www.agrosemens.com/telechargement/AGROSEMENS-Catalogue-2026.pdf) pour rendement. PK et récolte estimés', 133.0, 14.0),
  ('ITK037', 220.0, 'kg', null, 2.3, 1.0, 4.0, null, 'basse', 'Cumul bulbes, 112 g/motte, plants/motte non renseignés.', 'COMIFER teneurs azote 2013 pour N. Rendement BIO et PK estimés. Durée récolte estimée', 140.0, 14.0),
  ('ITK038', 220.0, 'kg', null, 2.3, 1.0, 4.0, null, 'moyenne', 'Multiplication bulbilles, 187 g/bulbille implantée, après tri.', 'COMIFER teneurs azote 2013 pour N. Rendement BIO et PK estimés', 105.0, 28.0),
  ('ITK039', 180.0, 'kg', null, 3.7, 1.0, 5.0, null, 'moyenne', 'Cumul saison, 92 g/motte implantée, feuilles parées.', 'COMIFER teneurs azote 2013 pour N. Rendement BIO et PK estimés', 56.0, 35.0),
  ('ITK040', 200.0, 'kg', null, 3.7, 1.0, 5.0, null, 'moyenne', 'Cumul saison, 36 g/graine semée, coupes successives.', 'COMIFER teneurs azote 2013 pour N. Rendement BIO et PK estimés', 56.0, 70.0),
  ('ITK041', 240.0, 'kg', null, 3.7, 1.0, 5.0, null, 'basse', 'Cumul saison, 61 g/graine semée, longue fenêtre incertaine.', 'COMIFER teneurs azote 2013 pour N. Rendement BIO et PK estimés', 84.0, 169.0),
  ('ITK042', 250.0, 'kg', null, 1.8, 0.8, 4.0, null, 'moyenne', '85% commercialisables, bulbes parés moyens 376 g.', 'COMIFER teneurs azote 2013 pour N. Rendement BIO et PK estimés', 66.0, 14.0),
  ('ITK043', 250.0, 'kg', null, 1.8, 0.8, 4.0, null, 'moyenne', '85% commercialisables, bulbes parés moyens 376 g.', 'COMIFER teneurs azote 2013 pour N. Rendement BIO et PK estimés', 63.0, 14.0),
  ('ITK044', 200.0, 'kg', null, 1.8, 0.8, 4.0, null, 'moyenne', '80% commercialisables, bulbes parés moyens 320 g.', 'COMIFER teneurs azote 2013 pour N. Rendement BIO et PK estimés', 42.0, 14.0),
  ('ITK045', 150.0, 'kg', null, 5.0, 1.5, 5.0, 50.0, 'basse', 'Cumul saison, gousses fraîches pleines, 64 g/graine semée.', 'Estimation agronomique BIO non mesurée. NPK estimés des gousses fraîches pleines. Fixation totale estimée', 84.0, 17.0),
  ('ITK046', 120.0, 'kg', null, 3.4, 1.05, 3.65, 30.0, 'moyenne', 'Cumul saison, gousses vertes, 51 g/graine semée.', 'COMIFER teneurs azote 2013 et PKMg 2019 haricot vert. Rendement BIO et fixation estimés', 84.0, 14.0),
  ('ITK047', 1500.0, 'botte', null, 4.0, 1.0, 5.0, null, 'basse', 'Cumul première saison, 50 g/botte, 319 g/pied implanté.', 'Estimation agronomique BIO non mesurée pour première année. NPK estimés des tiges feuillées', 90.0, 120.0),
  ('ITK048', 457.0, 'u', 70.0, 3.0, 1.3, 3.5, null, 'moyenne', '70% des graines, un épi commercial par plant réussi.', 'Estimation agronomique BIO non mesurée du taux. NPK estimés des épis avec spathes', 112.0, 21.0),
  ('ITK049', 350.0, 'kg', null, 2.0, 0.7, 3.9, null, 'moyenne', '70% commercialisables, racines moyennes 170 g.', 'COMIFER PKMg 2019 navet racine pour PK. Rendement BIO et N estimés', 70.0, 24.0),
  ('ITK050', 300.0, 'kg', null, 2.0, 0.7, 3.9, null, 'moyenne', '70% commercialisables, racines moyennes 146 g.', 'COMIFER PKMg 2019 navet racine pour PK. Rendement BIO et N estimés', 63.0, 21.0),
  ('ITK051', 350.0, 'kg', null, 2.0, 0.7, 3.9, null, 'moyenne', '70% commercialisables, racines moyennes 127 g.', 'COMIFER PKMg 2019 navet racine pour PK. Rendement BIO et N estimés', 63.0, 21.0),
  ('ITK052', 250.0, 'botte', null, 2.0, 0.7, 3.0, null, 'basse', '85% commercialisables, cinq oignons/botte, 50 g/oignon feuillé.', 'Estimation agronomique BIO non mesurée. NPK estimés des bulbes avec feuilles', 204.0, 49.0),
  ('ITK053', 200.0, 'botte', null, 2.0, 0.7, 3.0, null, 'basse', '85% mottes productives, cinq mottes/botte, composition à valider.', 'Estimation agronomique BIO non mesurée. NPK estimés des bulbes avec feuilles', 91.0, 14.0),
  ('ITK054', 200.0, 'botte', null, 2.0, 0.7, 3.0, null, 'basse', '85% commercialisables, cinq oignons/botte, densité semée à vérifier.', 'Estimation agronomique BIO non mesurée. NPK estimés des bulbes avec feuilles', 267.0, 28.0),
  ('ITK055', 556.0, 'botte', null, 2.0, 0.7, 3.0, null, 'moyenne', '85% commercialisables, six oignons/botte, 42 g/oignon feuillé.', 'Estimation agronomique BIO non mesurée. NPK estimés des bulbes avec feuilles', 91.0, 21.0),
  ('ITK056', 350.0, 'kg', null, 1.8, 0.7, 2.0, null, 'moyenne', '75% commercialisables, bulbes secs moyens 101 g.', 'Estimation agronomique BIO non mesurée. NPK estimés des bulbes secs. Fenêtre d''arrachage estimée', 105.0, 14.0),
  ('ITK057', 250.0, 'kg', null, 1.8, 0.7, 2.0, null, 'moyenne', '90% commercialisables, bulbes secs moyens 236 g.', 'Estimation agronomique BIO non mesurée. NPK estimés des bulbes secs. Fenêtre d''arrachage estimée', 126.0, 14.0),
  ('ITK058', 250.0, 'kg', null, 1.8, 0.7, 2.0, null, 'basse', 'Cumul bulbes, 233 g/motte, plants/motte non renseignés.', 'Estimation agronomique BIO non mesurée. NPK estimés des bulbes secs', 140.0, 14.0),
  ('ITK059', 400.0, 'kg', null, 1.8, 0.7, 2.0, null, 'basse', '70% commercialisables, bulbes secs moyens 83 g, hivernage.', 'Estimation agronomique BIO non mesurée. NPK estimés des bulbes secs. Fenêtre d''arrachage estimée', 337.0, 14.0),
  ('ITK060', 665.0, 'u', 85.0, 2.2, 0.7, 4.0, null, 'moyenne', '85% des plants, une pomme par plant réussi.', 'Estimation agronomique BIO du taux. N par analogie COMIFER Chioggia. PK estimés', 77.0, 28.0),
  ('ITK061', 626.0, 'u', 80.0, 2.0, 0.7, 3.5, null, 'basse', '80% des plants, durée existante atypique non modifiée.', 'Estimation agronomique BIO non mesurée du taux. NPK estimés du pied paré', 284.0, 21.0),
  ('ITK062', 300.0, 'kg', null, 2.0, 1.0, 4.0, null, 'moyenne', '70% commercialisables, racines moyennes 182 g.', 'Estimation agronomique BIO non mesurée. NPK estimés des racines seules', 154.0, 49.0),
  ('ITK063', 500.0, 'kg', null, 1.2, 0.4, 2.0, null, 'basse', 'Toutes planches, 80% productifs, un fruit moyen 3200 g/pied réussi.', 'Estimation agronomique BIO non mesurée pour rendement et durées. NPK estimés des fruits entiers', 100.0, 35.0),
  ('ITK064', 300.0, 'kg', null, 2.5, 0.8, 4.0, null, 'basse', 'Cumul tubercules triés, 761 g/pied implanté, adaptation alsacienne incertaine.', 'Estimation agronomique BIO non mesurée pour rendement et durées. NPK estimés des tubercules', 140.0, 21.0),
  ('ITK065', 300.0, 'kg', null, 2.5, 1.0, 4.0, null, 'moyenne', 'Quatre rangs, semis 4 cm, 65% commercialisables, racines 78 g.', 'Estimation agronomique BIO non mesurée. NPK estimés des racines seules', 175.0, 35.0),
  ('ITK066', 1800.0, 'botte', null, 4.0, 1.0, 5.0, null, 'moyenne', 'Cumul saison, 100 g/botte, 92 g/motte implantée.', 'Estimation agronomique BIO non mesurée. NPK estimés des feuilles et tiges', 52.0, 80.0),
  ('ITK067', 100.0, 'kg', null, 5.0, 1.5, 4.0, 80.0, 'moyenne', 'Cumul saison, gousses non écossées, 20 g/graine semée.', 'Estimation agronomique BIO non mesurée. NPK estimés des gousses pleines. Fixation totale estimée', 77.0, 21.0),
  ('ITK068', 100.0, 'kg', null, 5.0, 1.5, 4.0, 80.0, 'moyenne', 'Cumul saison, gousses non écossées, 23 g/graine semée.', 'Estimation agronomique BIO non mesurée. NPK estimés des gousses pleines. Fixation totale estimée', 77.0, 21.0),
  ('ITK069', 100.0, 'kg', null, 2.0, 0.6, 3.0, null, 'basse', 'Cumul saison, fruits frais, 426 g/pied implanté.', 'Estimation agronomique BIO non mesurée pour rendement et récolte. NPK estimés des fruits frais', 119.0, 42.0),
  ('ITK070', 130.0, 'kg', null, 3.0, 0.8, 4.0, null, 'basse', 'Cumul saison, feuilles blanchies, 166 g/motte implantée.', 'Estimation agronomique BIO non mesurée. NPK estimés des feuilles parées', 296.0, 70.0),
  ('ITK071', 250.0, 'kg', null, 3.3, 0.8, 4.2, null, 'moyenne', '85% commercialisables, poireaux parés moyens 250 g.', 'COMIFER teneurs azote 2013 et PKMg 2019 poireau. Rendement BIO estimé', 112.0, 56.0),
  ('ITK072', 300.0, 'kg', null, 3.0, 0.8, 5.0, null, 'basse', 'Cumul saison, jeunes feuilles, 38 g/graine semée.', 'Estimation agronomique BIO non mesurée. NPK estimés des jeunes feuilles et pétioles', 63.0, 98.0),
  ('ITK073', 100.0, 'kg', null, 4.0, 1.0, 3.5, 60.0, 'moyenne', 'Cumul saison, gousses entières, 34 g/graine semée.', 'Estimation agronomique BIO non mesurée. NPK estimés des gousses entières. Fixation totale estimée', 77.0, 21.0),
  ('ITK074', 300.0, 'kg', null, 2.0, 0.6, 3.0, null, 'moyenne', 'Cumul saison, fruits frais, 1277 g/pied implanté.', '[Agrosemens poivrons BIO rendement théorique](https://www.agrosemens.com/blog/poivrons-bio-pratique-culturale/) adapté à l''Alsace. NPK et fenêtre récolte estimés', 119.0, 42.0),
  ('ITK075', 200.0, 'kg', null, 2.8, 0.75, 4.5, null, 'moyenne', 'Cumul tubercules primeurs, 508 g/tubercule planté.', 'COMIFER teneurs azote 2013 et PKMg 2019 pomme de terre primeur. Rendement BIO estimé', 63.0, 14.0),
  ('ITK076', 300.0, 'kg', null, 2.8, 1.0, 7.2, null, 'moyenne', 'Cumul tubercules triés, 761 g/tubercule planté.', 'COMIFER teneurs azote 2013 et PKMg 2019 pomme de terre demi-primeur. Rendement BIO estimé', 84.0, 14.0),
  ('ITK077', 250.0, 'kg', null, 2.0, 0.7, 3.5, null, 'basse', '70% commercialisables, racines moyennes 243 g, type hivernal supposé.', 'Estimation agronomique BIO non mesurée. NPK estimés des racines seules', 42.0, 70.0),
  ('ITK078', 350.0, 'kg', null, 2.0, 0.7, 3.5, null, 'moyenne', '70% commercialisables, racines moyennes 170 g.', 'Estimation agronomique BIO non mesurée. NPK estimés des racines seules', 91.0, 14.0),
  ('ITK079', 333.0, 'botte', null, 2.5, 0.8, 4.0, null, 'basse', '85% commercialisables, cinq racines/botte, 100 g/racine feuillée.', 'Estimation agronomique BIO non mesurée. NPK estimés des racines avec fanes', 52.0, 14.0),
  ('ITK080', 323.0, 'botte', null, 2.5, 0.8, 4.0, null, 'moyenne', '80% commercialisables, 35 radis/botte, 350 g/botte.', 'Estimation agronomique BIO non mesurée pour rendement et durées. NPK estimés des racines avec fanes', 35.0, 7.0),
  ('ITK081', 120.0, 'kg', null, 4.0, 1.0, 4.0, null, 'moyenne', 'Cumul saison, feuilles coupées, 82 g/motte implantée.', 'Estimation agronomique BIO non mesurée. NPK estimés des feuilles coupées', 63.0, 28.0),
  ('ITK082', 665.0, 'u', 85.0, 1.8, 0.55, 3.5, null, 'moyenne', '85% des plants, une salade par plant réussi.', 'COMIFER teneurs azote 2013 et PKMg 2019 laitue plein champ. Taux BIO estimé', 42.0, 14.0),
  ('ITK083', 665.0, 'u', 85.0, 3.3, 0.7, 4.0, null, 'moyenne', '85% des plants, une scarole par plant réussi.', 'COMIFER teneurs azote 2013 chicorées pour N. Taux BIO et PK estimés', 70.0, 17.0),
  ('ITK084', 440.0, 'kg', null, 2.0, 0.8, 3.5, null, 'basse', '85% commercialisables, boules géantes moyennes 2000 g.', 'Estimation agronomique BIO non mesurée. NPK estimés par analogie chou-rave paré', 84.0, 35.0),
  ('ITK085', 383.0, 'botte', null, 2.5, 0.8, 4.0, null, 'moyenne', '75% commercialisables, 35 radis/botte, 350 g/botte.', 'Estimation agronomique BIO non mesurée pour rendement et durée. NPK estimés des racines avec fanes', 42.0, 7.0),
  ('ITK086', 434.0, 'botte', null, 2.5, 0.8, 4.0, null, 'moyenne', '85% commercialisables, 35 radis/botte, 350 g/botte.', 'Estimation agronomique BIO non mesurée. NPK estimés des racines avec fanes', 28.0, 7.0)) as v(code, rendement, unite, taux, n, p, k, fixation, fiabilite, note, source, duree_place, duree_recolte)
where i.code = v.code;

-- --------------------------------------------- l'unité commerciale du légume
update production.legume l set
  unite_commerciale   = coalesce(l.unite_commerciale, v.unite),
  poids_moyen_piece_g = coalesce(l.poids_moyen_piece_g, v.poids)
from (values
  ('carotte', 'kg', null),
  ('Salade', 'piece', 350.0),
  ('courge', 'kg', null),
  ('pomme de terre', 'kg', null),
  ('radis rose', 'botte', 350.0),
  ('oignon sec', 'kg', null),
  ('chou rouge', 'kg', null),
  ('betterave rouge', 'kg', null),
  ('poireau', 'kg', null),
  ('haricot nain', 'kg', null),
  ('chou fleur', 'piece', 1000.0),
  ('courgette', 'kg', null),
  ('epinard', 'kg', null),
  ('persil', 'botte', 100.0),
  ('patate douce', 'kg', null),
  ('navet', 'kg', null),
  ('celeri rave', 'kg', null),
  ('chou brocoli', 'kg', null),
  ('fenouil', 'kg', null),
  ('navet boule d’or', 'kg', null),
  ('chou blanc', 'kg', null),
  ('petits pois', 'kg', null),
  ('oignon botte', 'botte', 250.0),
  ('pastèque', 'kg', null),
  ('chou milan', 'kg', null),
  ('pois mange tout', 'kg', null),
  ('radis couleur', 'kg', null),
  ('bette', 'kg', null),
  ('pissenlit', 'kg', null),
  ('CORIANDRE', 'botte', 50.0),
  ('chou romanesco', 'piece', 800.0),
  ('radis ostergruss', 'botte', 500.0),
  ('chou chinois', 'piece', 800.0),
  ('haricot grain', 'kg', null),
  ('poirée', 'kg', null),
  ('chou bruxelles', 'kg', null),
  ('poivron', 'kg', null),
  ('Chou kale', 'botte', 300.0),
  ('Pak-Choï', 'piece', 400.0),
  ('Aneth', 'botte', 50.0),
  ('echalotte', 'kg', null),
  ('panais', 'kg', null),
  ('ail', 'kg', null),
  ('basilic', 'botte', 50.0),
  ('chou rave', 'piece', 350.0),
  ('liveche', 'botte', 50.0),
  ('pain de sucre', 'piece', 700.0),
  ('chou pointu', 'piece', 800.0),
  ('radis noir', 'kg', null),
  ('Scarole', 'piece', 600.0),
  ('chou rutabaga', 'kg', null),
  ('Mais doux', 'piece', 250.0),
  ('celeri branche', 'piece', 800.0),
  ('Roquette', 'kg', null),
  ('ciboulette', 'botte', 30.0),
  ('persil racine', 'kg', null),
  ('Choggia', 'piece', 350.0),
  ('superschmelz', 'kg', null),
  ('Piment', 'kg', null)) as v(nom, unite, poids)
where l.nom = v.nom;

-- ------------------------------- les fenêtres de récolte qui se déduisent
--  Dix-huit cultures de 2027 n'avaient pas de fenêtre de récolte. Ce n'était
--  pas dix-huit trous mais treize itinéraires sans durée : maintenant qu'ils
--  en ont une, les dates se calculent. On ne touche QUE celles qui sont
--  vides — une date saisie à la main reste la vérité.
update production.culture c set
  debut_recolte_prevu = coalesce(c.debut_recolte_prevu,
                                 (coalesce(c.date_plantation_prevue, c.date_semis_prevue)
                                  + (i.duree_en_place_jours || ' days')::interval)::date),
  fin_recolte_prevue  = coalesce(c.fin_recolte_prevue,
                                 (coalesce(c.date_plantation_prevue, c.date_semis_prevue)
                                  + ((i.duree_en_place_jours + i.duree_recolte_jours) || ' days')::interval)::date)
from production.itineraire i
where i.id = c.itineraire_id
  and (c.debut_recolte_prevu is null or c.fin_recolte_prevue is null)
  and coalesce(c.date_plantation_prevue, c.date_semis_prevue) is not null
  and i.duree_en_place_jours is not null
  and i.duree_recolte_jours is not null;

-- ----------------------------------------------------------------- le contrôle
--  On compte le REPORT, pas la cible intacte : ces chiffres sont faits pour
--  être corrigés, et un rejeu en cours de campagne doit rester vrai.
do $$
declare n integer; m integer;
begin
  if not exists (select 1 from production.unite where code = 'botte') then
    raise exception 'L''unité botte est absente';
  end if;

  select count(*) into n from production.itineraire where rendement_attendu is not null;
  if n < 86 then raise exception 'Rendements renseignés : % sur 86 attendus', n; end if;

  select count(*) into n from production.itineraire
   where unite_rendement is not null and unite_rendement not in ('kg','u','botte');
  if n > 0 then raise exception '% itinéraires ont une unité de rendement inattendue', n; end if;

  select count(*) into n from production.itineraire where export_n_kg_par_tonne is not null;
  if n < 86 then raise exception 'Exportations d''azote : % sur 86', n; end if;

  select count(*) into n from production.legume where unite_commerciale is not null;
  if n < 59 then raise exception 'Unités commerciales : % sur 59 attendues', n; end if;

  --  Les deux densités corrigées. On vérifie le résultat, pas le chemin.
  select count(*) into n from production.itineraire i
    join production.configuration_rangs cr on cr.id = i.configuration_rangs_id
   where i.code = 'ITK017' and cr.nb_rangs = 2 and i.espacement_sur_rang_cm = 50.0;
  if n <> 1 then raise exception 'ITK017 n''est pas à 2 rangs x 50 cm'; end if;

  if (select espacement_sur_rang_cm from production.itineraire where code = 'ITK065') <> 4.0 then
    raise exception 'ITK065 n''est pas à 4 cm sur le rang';
  end if;

  --  Plus aucune culture ne doit manquer de fenêtre de récolte DÈS LORS
  --  qu'elle a une date de départ et que son itinéraire porte ses durées.
  --  C'est le report qu'on vérifie, pas un compte figé.
  select count(*) into n from production.culture c
    join production.itineraire i on i.id = c.itineraire_id
   where (c.debut_recolte_prevu is null or c.fin_recolte_prevue is null)
     and coalesce(c.date_plantation_prevue, c.date_semis_prevue) is not null
     and i.duree_en_place_jours is not null and i.duree_recolte_jours is not null;
  if n > 0 then raise exception '% cultures calculables n''ont toujours pas de fenêtre de récolte', n; end if;

  select count(*) into m from production.culture
   where debut_recolte_prevu is null or fin_recolte_prevue is null;
  raise notice 'Référentiel en place · 86 rendements, 59 unités commerciales. Cultures sans fenêtre de récolte, toutes campagnes : %', m;
end $$;
