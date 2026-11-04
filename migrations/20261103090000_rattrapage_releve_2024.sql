-- Rattrapage du relevé 2024 : scans de Forêt 13, Forêt 14 et Bruno Est.
-- 19 lignes à ajouter, 7 à corriger. Rejouable.

insert into production.assolement_releve
  (id, annee, parcelle_id, rang, planche_debut, planche_fin, nb_planches_ecrit, libelle, famille_botanique_id, est_engrais_vert, est_passage, est_sans_culture, feuille_nom, feuille_planche_1_au, feuille_nb_planches, feuille_planche_debut, feuille_planche_fin, note) values
  ('ab89b0cb-ac3d-599f-8561-bb26db499d20', 2024, '74468ac2-961d-5ddf-a64d-8a5192215b5a', 3, 12, 19, 8.0, 'Betteraves (S13)', 'bd88f9d5-b8da-5a5f-992f-1511fd931c7e', false, false, false, '13', 'ouest', 19, 12, 19, 'relevé 2024, scan'),
  ('dcdd2b57-73f4-5a9a-a746-0bcbea9ba3a7', 2024, '74468ac2-961d-5ddf-a64d-8a5192215b5a', 4, 1, 6, 6.0, 'Choux Plume Violet de Provence', 'a7818eca-d9ce-5f5b-9a64-60ed3a87cc0b', false, false, false, '13', 'ouest', 19, 1, 6, 'relevé 2024, scan'),
  ('ec848b9e-ff34-56f0-82d9-6c6c64dc7c2b', 2024, '74468ac2-961d-5ddf-a64d-8a5192215b5a', 5, 7, 10, 4.0, 'Rutabaga', 'a7818eca-d9ce-5f5b-9a64-60ed3a87cc0b', false, false, false, '13', 'ouest', 19, 7, 10, 'relevé 2024, scan'),
  ('eabbe96e-f512-5e77-9970-9584c7322ae4', 2024, '74468ac2-961d-5ddf-a64d-8a5192215b5a', 6, 11, 12, 2.0, 'Choux Rave', 'a7818eca-d9ce-5f5b-9a64-60ed3a87cc0b', false, false, false, '13', 'ouest', 19, 11, 12, 'relevé 2024, scan'),
  ('8562f7e5-2845-5946-9f2a-f57aad3e04b9', 2024, '74468ac2-961d-5ddf-a64d-8a5192215b5a', 7, 13, 16, 4.0, 'Navets de conserve ?', 'a7818eca-d9ce-5f5b-9a64-60ed3a87cc0b', false, false, false, '13', 'ouest', 19, 13, 16, 'relevé 2024, scan'),
  ('485105ab-d3ba-57c5-a785-ff83dec2a71f', 2024, '74468ac2-961d-5ddf-a64d-8a5192215b5a', 8, 17, 19, 3.0, 'Basilic', '79c9fe45-6222-538e-95a2-6e82c43f880f', false, false, false, '13', 'ouest', 19, 17, 19, 'relevé 2024, scan'),
  ('2e7ff927-b8d8-504e-ad21-f7b067891f3f', 2024, '8720497e-c1ef-57c0-93fa-678a6542b032', 2, 9, 10, 2.0, 'Poirée (S16)', 'bd88f9d5-b8da-5a5f-992f-1511fd931c7e', false, false, false, '14', 'ouest', 19, 9, 10, 'relevé 2024, scan'),
  ('99e295f5-43a3-5f95-a7de-02e7bbf8383e', 2024, '8720497e-c1ef-57c0-93fa-678a6542b032', 3, 11, 13, 3.0, 'Blette (S17)', 'bd88f9d5-b8da-5a5f-992f-1511fd931c7e', false, false, false, '14', 'ouest', 19, 11, 13, 'relevé 2024, scan'),
  ('946d1321-e003-5a1a-9824-0259ea3aefd3', 2024, '8720497e-c1ef-57c0-93fa-678a6542b032', 4, 14, 14, 1.0, 'Poirée (S19)', 'bd88f9d5-b8da-5a5f-992f-1511fd931c7e', false, false, false, '14', 'ouest', 19, 14, 14, 'relevé 2024, scan'),
  ('644ac803-ea93-51cf-95db-81a29ec976ea', 2024, '8720497e-c1ef-57c0-93fa-678a6542b032', 5, 15, 15, 1.0, 'Poirée (S22)', 'bd88f9d5-b8da-5a5f-992f-1511fd931c7e', false, false, false, '14', 'ouest', 19, 15, 15, 'relevé 2024, scan'),
  ('11f31552-9863-5461-aa6a-2ff84f84da5f', 2024, '8720497e-c1ef-57c0-93fa-678a6542b032', 6, 16, 16, 1.0, 'Blette (S24)', 'bd88f9d5-b8da-5a5f-992f-1511fd931c7e', false, false, false, '14', 'ouest', 19, 16, 16, 'relevé 2024, scan'),
  ('1fa5a397-a4c8-5c18-8ebf-eadcdbffdb14', 2024, '8720497e-c1ef-57c0-93fa-678a6542b032', 7, 17, 17, 1.0, 'Poirée (S25)', 'bd88f9d5-b8da-5a5f-992f-1511fd931c7e', false, false, false, '14', 'ouest', 19, 17, 17, 'relevé 2024, scan'),
  ('8bac90c5-4836-513d-8f3d-854189bcb0bd', 2024, '8720497e-c1ef-57c0-93fa-678a6542b032', 8, 18, 19, 2.0, 'Blette (S28)', 'bd88f9d5-b8da-5a5f-992f-1511fd931c7e', false, false, false, '14', 'ouest', 19, 18, 19, 'relevé 2024, scan'),
  ('840bc52f-e767-5fec-827e-c0c41d85f886', 2024, 'a0177846-728a-5e0f-a12d-1329c1dbf38d', 1, 34, 61, 28.0, 'Oignons de conservation', '5e29b689-7c20-519f-a030-bbd40101fd3d', false, false, false, 'Bruno Est 180m', 'nord', 61, 1, 28, 'relevé 2024, scan'),
  ('e27ea133-91b0-58f0-b215-700e30a80533', 2024, 'a0177846-728a-5e0f-a12d-1329c1dbf38d', 2, 32, 33, null, 'Passage 2,50 m', null, false, true, false, 'Bruno Est 180m', 'nord', 61, 29, 30, 'relevé 2024, scan'),
  ('6f4fcbbe-f813-5504-b030-5787b8b1d50a', 2024, 'a0177846-728a-5e0f-a12d-1329c1dbf38d', 3, 23, 24, null, 'Passage 2,50 m', null, false, true, false, 'Bruno Est 180m', 'nord', 61, 38, 39, 'relevé 2024, scan'),
  ('9b1df5d3-8740-5f5d-b6a4-b6873ab161d9', 2024, 'a0177846-728a-5e0f-a12d-1329c1dbf38d', 4, 13, 22, null, 'Salade', '4385f0f4-4e13-5ee6-8c23-9e5bea7e09b6', false, false, false, 'Bruno Est 180m', 'nord', 61, 40, 49, 'relevé 2024, scan'),
  ('05edce16-47d4-5776-8669-c79f347a5114', 2024, 'a0177846-728a-5e0f-a12d-1329c1dbf38d', 5, 11, 12, null, 'Passage 12,50 m', null, false, true, false, 'Bruno Est 180m', 'nord', 61, 50, 51, 'relevé 2024, scan'),
  ('d58224ce-e66e-5ac1-816d-bcb17e8b214c', 2024, 'a0177846-728a-5e0f-a12d-1329c1dbf38d', 6, 1, 33, null, 'Engrais Vert (Pois, Vesce, Blé, Féverole)', null, true, false, false, 'Bruno Est 180m', 'nord', 61, 29, 61, 'relevé 2024, scan'),
  ('127061a9-2c35-5d52-882a-876ae926d14e', 2024, '6ff3f24b-6143-56d9-9c3b-e7f1c86bb36d', 1, 1, 5, 5.0, 'Scaroles', '4385f0f4-4e13-5ee6-8c23-9e5bea7e09b6', false, false, false, '12', 'ouest', 5, 1, 5, 'relevé 2024, scan'),
  ('76fb2fc7-dd48-587e-91cc-2b043b372a12', 2024, '74468ac2-961d-5ddf-a64d-8a5192215b5a', 1, 1, 9, 9.0, 'Betteraves (S13)', 'bd88f9d5-b8da-5a5f-992f-1511fd931c7e', false, false, false, '13', 'ouest', 19, 1, 9, 'relevé 2024, scan'),
  ('2500c298-3d51-59cc-ae5d-daac917fbe68', 2024, '74468ac2-961d-5ddf-a64d-8a5192215b5a', 2, 10, 11, 2.0, 'Poirée (S13)', 'bd88f9d5-b8da-5a5f-992f-1511fd931c7e', false, false, false, '13', 'ouest', 19, 10, 11, 'relevé 2024, scan'),
  ('43f73f38-1369-5e1f-95b5-aa607e3ffa4a', 2024, '8720497e-c1ef-57c0-93fa-678a6542b032', 1, 1, 8, 8.0, 'Basilic (S16)', '79c9fe45-6222-538e-95a2-6e82c43f880f', false, false, false, '14', 'ouest', 19, 1, 8, 'relevé 2024, scan'),
  ('3c7fe463-4e24-52fe-8884-94535aa7ccad', 2024, '62c1b40d-14e4-5e08-a3c2-b1d39066c561', 1, 1, 62, 62.0, 'Choux de conservation (rouge, blanc, milan, bruxelles, kale)', 'a7818eca-d9ce-5f5b-9a64-60ed3a87cc0b', false, false, false, 'Matt 1', '?', 64, 1, 62, 'relevé 2024, scan · sens de numérotation inconnu'),
  ('7526b12d-e4a9-5a20-b96f-0c7e4b2b801d', 2024, '2aa84b86-1e67-5fc8-831a-18ae5796cf51', 1, 1, 38, 38.0, 'Betteraves de conservation (retournées)', 'bd88f9d5-b8da-5a5f-992f-1511fd931c7e', false, false, false, 'Matt 2', '?', 38, 1, 38, 'relevé 2024, scan · sens de numérotation inconnu'),
  ('4ccaeaee-b341-57fc-b01c-d7b49ef946c7', 2024, '2aa84b86-1e67-5fc8-831a-18ae5796cf51', 2, 1, 38, null, 'Blé d''hiver variété Alessio', 'd5ca3205-ac03-5230-9ffc-939675d594e5', false, false, false, 'Matt 2', '?', 38, 1, 38, 'relevé 2024, scan · sens de numérotation inconnu')
on conflict (id) do update set
  annee = excluded.annee,
  parcelle_id = excluded.parcelle_id,
  rang = excluded.rang,
  planche_debut = excluded.planche_debut,
  planche_fin = excluded.planche_fin,
  nb_planches_ecrit = excluded.nb_planches_ecrit,
  libelle = excluded.libelle,
  famille_botanique_id = excluded.famille_botanique_id,
  est_engrais_vert = excluded.est_engrais_vert,
  est_passage = excluded.est_passage,
  est_sans_culture = excluded.est_sans_culture,
  feuille_nom = excluded.feuille_nom,
  feuille_planche_1_au = excluded.feuille_planche_1_au,
  feuille_nb_planches = excluded.feuille_nb_planches,
  feuille_planche_debut = excluded.feuille_planche_debut,
  feuille_planche_fin = excluded.feuille_planche_fin,
  note = excluded.note;

do $$
declare n integer;
begin
  select count(*) into n from production.assolement_releve;
  if n <> 521 then raise exception 'Relevé à % lignes au lieu de 521', n; end if;
end $$;
