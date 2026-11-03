-- ==========================================================================
-- Plan de culture maraichere - 012 · Le parcellaire reel
-- Cale l'import FileMaker sur le releve GPS et sur six ans de feuilles
-- d'assolement, 2021 a 2026.
-- ==========================================================================

-- --------------------------------------------------------------------------
-- La convention de numerotation, arretee le 20 octobre 2026.
-- On numerote vers l'est et vers le nord, comme des coordonnees : la
-- planche 1 est a l'ouest quand les planches sont nord-sud, au sud quand
-- elles sont est-ouest. Jamais au nord, jamais a l'est. Pour une parcelle
-- en biais, c'est le cap releve qui tranche, sans discussion possible.
-- --------------------------------------------------------------------------

create type production.bout_planche_1 as enum ('sud', 'ouest');

alter table production.parcelle
  add column azimut_planches numeric(5,1)
    check (azimut_planches >= 0 and azimut_planches < 180),
  add column planche_1_au production.bout_planche_1,
  add column hors_rotation boolean not null default false;

comment on column production.parcelle.azimut_planches is
  'Cap de la longueur des planches, en degres depuis le nord, ramene a [0, 180[. Releve au GPS sur le contour. Null tant que la parcelle n''a pas ete relevee : le sens de numerotation est alors connu par la feuille manuscrite, mais pas l''angle.';

comment on column production.parcelle.planche_1_au is
  'Bout de la parcelle ou se trouve la planche 1. Se deduit du cap quand il existe : plus proche du nord-sud, planche 1 a l''ouest ; plus proche de l''est-ouest, planche 1 au sud.';

comment on column production.parcelle.hors_rotation is
  'Parcelle qui ne suit pas l''assolement : vivaces, fleurs, jacheres longues. Elle apparait sur le plan mais ne compte pas dans la rotation.';


-- --------------------------------------------------------------------------
-- F1 et F4 : la planche du sud a disparu
-- Haie plantee et chemin elargi. Les feuilles 2021 et 2022 portent 112
-- planches, celles de 2023 a 2026 en portent 111.
-- La base numerote F1 et F4 depuis le nord : la planche perdue est donc
-- la derniere, la 112.
-- --------------------------------------------------------------------------

--  Une affectation qui demarrait sur cette planche perd son point de
--  depart, pas sa parcelle : elle redevient une quantite a poser.
update production.affectation set unite_debut_id = null
 where unite_debut_id in (
   select id from production.unite_culture
    where parcelle_id in ('de71d335-10fa-5bc5-9e4f-89e893eee1e6', '9026dc3d-77d4-536d-8c6d-8d518b7cf11a') and ordre = 112);

delete from production.unite_culture
 where parcelle_id = 'de71d335-10fa-5bc5-9e4f-89e893eee1e6' and ordre = 112;
delete from production.unite_culture
 where parcelle_id = '9026dc3d-77d4-536d-8c6d-8d518b7cf11a' and ordre = 112;


-- --------------------------------------------------------------------------
-- Bruno Ouest : une parcelle, pas deux
-- Il n'y a pas de chemin entre la partie 180 m et la partie 90 m, et les
-- feuilles numerotent 1 a 61 d'un bout a l'autre. On fond les deux.
-- Du nord vers le sud, comme la base : 28 planches de 180 m, puis 33 de
-- 90 m. La limite bouge d'un rang par rapport a l'import (28 + 33, et
-- non 29 + 32).
-- --------------------------------------------------------------------------

update production.unite_culture set parcelle_id = '45749dc2-0931-5826-81fd-7c56e8539bb6'
 where parcelle_id = '19ebfe0e-9f44-5c54-ac04-8daa4e4a4b73';

update production.unite_culture set code = code || '~'
 where parcelle_id = '45749dc2-0931-5826-81fd-7c56e8539bb6';   -- le code est unique : on degage la place

with ordonne as (
  select id, row_number() over (order by longueur_m desc, x_debut_m) as rang
    from production.unite_culture where parcelle_id = '45749dc2-0931-5826-81fd-7c56e8539bb6')
update production.unite_culture u
   set ordre = o.rang,
       x_debut_m = (o.rang - 1) * 1.700,
       longueur_m = case when o.rang <= 28 then 180.0 else 90.0 end,
       code = 'P0013-' || lpad(o.rang::text, 3, '0')
  from ordonne o where u.id = o.id;

update production.parcelle set nom = 'Bruno Ouest' where id = '45749dc2-0931-5826-81fd-7c56e8539bb6';

--  Tout ce qui pointait sur la moitie nord pointe desormais sur l'ensemble.
update production.affectation set parcelle_id = '45749dc2-0931-5826-81fd-7c56e8539bb6'
 where parcelle_id = '19ebfe0e-9f44-5c54-ac04-8daa4e4a4b73';
update production.preaffectation set parcelle_id = '45749dc2-0931-5826-81fd-7c56e8539bb6'
 where parcelle_id = '19ebfe0e-9f44-5c54-ac04-8daa4e4a4b73';
delete from production.parcelle_equipement pe
 where pe.parcelle_id = '19ebfe0e-9f44-5c54-ac04-8daa4e4a4b73'
   and exists (select 1 from production.parcelle_equipement q
                where q.parcelle_id = '45749dc2-0931-5826-81fd-7c56e8539bb6'
                  and q.equipement_id = pe.equipement_id);
update production.parcelle_equipement set parcelle_id = '45749dc2-0931-5826-81fd-7c56e8539bb6'
 where parcelle_id = '19ebfe0e-9f44-5c54-ac04-8daa4e4a4b73';

delete from production.parcelle where id = '19ebfe0e-9f44-5c54-ac04-8daa4e4a4b73';


-- --------------------------------------------------------------------------
-- Lauch 1 : 50 planches par parcelle
-- Le releve en comptait 49, Coco en compte 50 sur le terrain.
-- --------------------------------------------------------------------------

insert into production.unite_culture
  (id, code, parcelle_id, ordre, x_debut_m, longueur_m, largeur_m,
   largeur_utile_m, permanente) values
  ('77df8e3c-2c58-5e33-b8cb-0ce8ffbeb116', 'P0029-050', 'fea61b5d-c8ae-5697-bbc0-af184888ce53', 50, 83.3, 130.0, 1.700, 1.400, true),
  ('c4a8b2c7-b376-5834-8d3b-a8414f1d5167', 'P0030-050', '3ea034d2-05ea-53b1-86f6-17401d29d8df', 50, 83.3, 130.0, 1.700, 1.400, true);


-- --------------------------------------------------------------------------
-- Robert : quatre parcelles a la place de deux fourre-tout
-- Six parcelles de 120 m jusqu'en 2023, puis trois a quatre ans de
-- luzerne et une rangee d'arbres au milieu. Depuis le printemps 2026 :
-- R1 et R2 au nord, implantees et en legumes ; R3 et R4 au sud, encore
-- en luzerne, en legumes en 2027. L'ancien decoupage ne porte plus rien.
-- Numerotees depuis le sud des le depart : rien a retourner ensuite.
-- --------------------------------------------------------------------------

--  Ces deux fourre-tout n'ont jamais designe un morceau de terrain. Ce qui
--  pointait dessus redevient ce qu'il a toujours ete : une quantite sans
--  lieu, que le modele sait porter depuis la migration 014.
update production.affectation set unite_debut_id = null
 where unite_debut_id in (select id from production.unite_culture
    where parcelle_id in ('c8c11224-d364-5bf7-bbe4-82c356d34b9d', 'edfa7bb6-4e74-54a3-8e41-23ddda6bc6ff'));
update production.affectation set parcelle_id = null
 where parcelle_id in ('c8c11224-d364-5bf7-bbe4-82c356d34b9d', 'edfa7bb6-4e74-54a3-8e41-23ddda6bc6ff');
update production.preaffectation set parcelle_id = null
 where parcelle_id in ('c8c11224-d364-5bf7-bbe4-82c356d34b9d', 'edfa7bb6-4e74-54a3-8e41-23ddda6bc6ff');

delete from production.parcelle where id in ('c8c11224-d364-5bf7-bbe4-82c356d34b9d', 'edfa7bb6-4e74-54a3-8e41-23ddda6bc6ff');

insert into production.parcelle
  (id, code, nom, ilot_id, type, planche_1_au) values
  ('99c0be4c-572f-5185-a7b1-d8c2622a0a47', 'P0033', 'R1', '48c01aaa-cbff-596c-ada0-84b2b5ebbd11', 'plein_champ', 'sud'),
  ('b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 'P0034', 'R2', '48c01aaa-cbff-596c-ada0-84b2b5ebbd11', 'plein_champ', 'sud'),
  ('667a1213-c337-5706-8c79-45ac5e928274', 'P0035', 'R3', '48c01aaa-cbff-596c-ada0-84b2b5ebbd11', 'plein_champ', 'sud'),
  ('14193989-9230-582f-a6d9-722e745aee8f', 'P0036', 'R4', '48c01aaa-cbff-596c-ada0-84b2b5ebbd11', 'plein_champ', 'sud');

insert into production.unite_culture
  (id, code, parcelle_id, ordre, x_debut_m, longueur_m, largeur_m,
   largeur_utile_m, permanente) values
  ('e63a3d4e-f772-531f-9cb3-f9a8511172ce', 'P0033-001', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 1, 0.0, 180.0, 1.700, 1.400, true),
  ('fbc9b423-4c62-5aaa-96e3-ac676671df3e', 'P0033-002', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 2, 1.7, 180.0, 1.700, 1.400, true),
  ('25d4faaf-64bb-5441-9cba-98f21fe78596', 'P0033-003', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 3, 3.4, 180.0, 1.700, 1.400, true),
  ('16fed982-c283-5b6c-b243-d02e5ea3bf59', 'P0033-004', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 4, 5.1, 180.0, 1.700, 1.400, true),
  ('d2cfffd1-e2de-509a-91d9-ae9c04bd9d07', 'P0033-005', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 5, 6.8, 180.0, 1.700, 1.400, true),
  ('0a345868-d87e-5f0f-b5d3-b7cb66dbe9f1', 'P0033-006', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 6, 8.5, 180.0, 1.700, 1.400, true),
  ('6c4946e1-b7e4-5c4e-8ccd-fb3af58b40a3', 'P0033-007', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 7, 10.2, 180.0, 1.700, 1.400, true),
  ('a52ad7bf-40bf-50d0-b761-549740dadf1d', 'P0033-008', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 8, 11.9, 180.0, 1.700, 1.400, true),
  ('e9e513b5-71f7-5fe3-b405-5e709c0c1117', 'P0033-009', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 9, 13.6, 180.0, 1.700, 1.400, true),
  ('02510823-0d57-58f0-a6ae-86b4abc9c6bb', 'P0033-010', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 10, 15.3, 180.0, 1.700, 1.400, true),
  ('120b75d1-1d04-5db5-83df-e3bfec1255da', 'P0033-011', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 11, 17.0, 180.0, 1.700, 1.400, true),
  ('8c992b88-4703-5c9c-9d2d-c1ad6dd94677', 'P0033-012', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 12, 18.7, 180.0, 1.700, 1.400, true),
  ('f421080c-94f3-5467-a157-d42df2dedd95', 'P0033-013', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 13, 20.4, 180.0, 1.700, 1.400, true),
  ('bbaccd04-29de-5e9f-b1f9-7bc7fb642c10', 'P0033-014', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 14, 22.1, 180.0, 1.700, 1.400, true),
  ('2bca9174-bc82-5a1f-94d6-0828f3008445', 'P0033-015', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 15, 23.8, 180.0, 1.700, 1.400, true),
  ('58611c57-3f49-59ae-93c1-c7c6cc4b839c', 'P0033-016', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 16, 25.5, 180.0, 1.700, 1.400, true),
  ('36f06234-35b8-54ce-ade0-e250bf572a93', 'P0033-017', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 17, 27.2, 180.0, 1.700, 1.400, true),
  ('1e164c0a-abfa-588d-b261-663d66ccbb3f', 'P0033-018', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 18, 28.9, 180.0, 1.700, 1.400, true),
  ('254b0002-e370-53de-8f70-0d622b5c94dd', 'P0033-019', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 19, 30.6, 180.0, 1.700, 1.400, true),
  ('fc8746e7-14d1-5d42-8890-28f96f531eab', 'P0033-020', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 20, 32.3, 180.0, 1.700, 1.400, true),
  ('d7e6fbc5-1718-5e71-9330-d60117684c41', 'P0033-021', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 21, 34.0, 180.0, 1.700, 1.400, true),
  ('79010ab8-8f74-5f43-bb6c-046c1be544b7', 'P0033-022', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 22, 35.7, 180.0, 1.700, 1.400, true),
  ('fedb7b69-2cdc-556a-b281-13938eae5afc', 'P0033-023', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 23, 37.4, 180.0, 1.700, 1.400, true),
  ('344f28b9-b183-5df1-82c3-99d8817e036a', 'P0033-024', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 24, 39.1, 180.0, 1.700, 1.400, true),
  ('3ac0a3cc-4509-54d7-b048-26aa3363a49c', 'P0033-025', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 25, 40.8, 180.0, 1.700, 1.400, true),
  ('697fa87e-13d9-5ecb-8014-3e937fa13021', 'P0033-026', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 26, 42.5, 180.0, 1.700, 1.400, true),
  ('fdeee221-6998-5c5a-80f5-285c20dcbaf9', 'P0033-027', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 27, 44.2, 180.0, 1.700, 1.400, true),
  ('127ef71a-9675-5b15-9f3e-0dc2aac69f84', 'P0033-028', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 28, 45.9, 180.0, 1.700, 1.400, true),
  ('56216839-83a7-533d-a2c5-6fff9bdf2841', 'P0033-029', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 29, 47.6, 180.0, 1.700, 1.400, true),
  ('065efa63-01d4-50c9-b9e6-f15e15b320d9', 'P0033-030', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 30, 49.3, 180.0, 1.700, 1.400, true),
  ('0e285fe5-f685-54de-a710-56f00e34de5c', 'P0033-031', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 31, 51.0, 180.0, 1.700, 1.400, true),
  ('b4263aed-1080-519b-9e3c-03b6925eb5e6', 'P0033-032', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 32, 52.7, 180.0, 1.700, 1.400, true),
  ('856ee78f-7b97-50cc-a4f0-ea26c4801fec', 'P0033-033', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 33, 54.4, 180.0, 1.700, 1.400, true),
  ('413010c6-2d5c-5f1c-90b7-1e5cfd1fbc37', 'P0033-034', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 34, 56.1, 180.0, 1.700, 1.400, true),
  ('0354f4c5-1d4a-5bf4-9878-815b8358cd3d', 'P0033-035', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 35, 57.8, 180.0, 1.700, 1.400, true),
  ('1655c991-75a8-5349-9a57-54df2b05a006', 'P0033-036', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 36, 59.5, 180.0, 1.700, 1.400, true),
  ('82348532-514d-5bd3-8020-e0e6ca0552c2', 'P0033-037', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 37, 61.2, 180.0, 1.700, 1.400, true),
  ('aabf8b45-1645-58fb-a707-e32817d6a263', 'P0033-038', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 38, 62.9, 180.0, 1.700, 1.400, true),
  ('ca3bacd5-901f-5c69-9c2d-24c6604f1ccc', 'P0033-039', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 39, 64.6, 180.0, 1.700, 1.400, true),
  ('79cbe616-9841-5f36-9d59-636597c4674f', 'P0033-040', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 40, 66.3, 180.0, 1.700, 1.400, true),
  ('dbf9bdcf-ba95-56b3-8b4c-07e33219f1d7', 'P0033-041', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 41, 68.0, 180.0, 1.700, 1.400, true),
  ('872c2aff-47e8-5ed3-9ecf-35df2f95a0eb', 'P0033-042', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 42, 69.7, 180.0, 1.700, 1.400, true),
  ('5ca7a732-3812-5dd9-935e-435bb68a2963', 'P0033-043', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 43, 71.4, 180.0, 1.700, 1.400, true),
  ('6f76ba54-35a9-51b4-a032-d7fdeb1442e9', 'P0033-044', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 44, 73.1, 180.0, 1.700, 1.400, true),
  ('ed93ebbb-4178-5896-ab63-394c68d77209', 'P0033-045', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 45, 74.8, 180.0, 1.700, 1.400, true),
  ('b7c0ee3d-ae89-53b1-8485-3cd2386f7ca5', 'P0033-046', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 46, 76.5, 180.0, 1.700, 1.400, true),
  ('8b7b2fd7-c92c-589c-80b4-aaa5b5f1eb9f', 'P0033-047', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 47, 78.2, 180.0, 1.700, 1.400, true),
  ('58d9fe8f-def9-5f26-9252-41c8f07b5c45', 'P0033-048', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 48, 79.9, 180.0, 1.700, 1.400, true),
  ('ea648e9e-0833-568d-8e55-ec9cd7093508', 'P0033-049', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 49, 81.6, 180.0, 1.700, 1.400, true),
  ('3876c834-ffde-51ee-856e-9baade517991', 'P0033-050', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 50, 83.3, 180.0, 1.700, 1.400, true),
  ('dc52a3b4-73d0-5283-8a3e-2af0bec31f8e', 'P0033-051', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 51, 85.0, 180.0, 1.700, 1.400, true),
  ('cd27a149-24b9-5e71-9ef3-6fd82c117f50', 'P0033-052', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 52, 86.7, 180.0, 1.700, 1.400, true),
  ('ec3559ec-f003-50bf-9b99-b5a94a98fa4d', 'P0033-053', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 53, 88.4, 180.0, 1.700, 1.400, true),
  ('f4088248-ed37-510d-b700-97c7afbdbf01', 'P0033-054', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 54, 90.1, 180.0, 1.700, 1.400, true),
  ('2f790624-dd6d-56c0-af1a-7e06b7a28d38', 'P0033-055', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 55, 91.8, 180.0, 1.700, 1.400, true),
  ('fb70ef30-afd2-5ee9-a154-3e061bd4b930', 'P0033-056', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 56, 93.5, 180.0, 1.700, 1.400, true),
  ('b48b0b52-2457-562c-a250-8f973adcf969', 'P0033-057', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 57, 95.2, 180.0, 1.700, 1.400, true),
  ('81f5155a-2d4f-577e-9219-3e59224232c6', 'P0033-058', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 58, 96.9, 180.0, 1.700, 1.400, true),
  ('9cd5bd6f-09e2-540a-9261-906c039485a1', 'P0033-059', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 59, 98.6, 180.0, 1.700, 1.400, true),
  ('14d9af61-83f2-5882-b4da-cc7827cced3a', 'P0033-060', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 60, 100.3, 180.0, 1.700, 1.400, true),
  ('35a115d1-a58d-57d2-baa2-8c4af717b8e7', 'P0033-061', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 61, 102.0, 180.0, 1.700, 1.400, true),
  ('267b9811-5b93-574c-8839-ba7fc22dffbd', 'P0033-062', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 62, 103.7, 180.0, 1.700, 1.400, true),
  ('5bda27f0-c17a-55c9-a2b5-d6bf4378a1ce', 'P0033-063', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 63, 105.4, 180.0, 1.700, 1.400, true),
  ('32cd5956-9216-521a-9f61-2648366ca833', 'P0033-064', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 64, 107.1, 180.0, 1.700, 1.400, true),
  ('55c3a6c2-e871-5ec1-a8ef-c44681c5ebae', 'P0033-065', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 65, 108.8, 180.0, 1.700, 1.400, true),
  ('92302585-6b76-5806-aac8-23ce8d5e0e68', 'P0033-066', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 66, 110.5, 180.0, 1.700, 1.400, true),
  ('469ac42f-9c0c-5666-82ee-d500f09014ad', 'P0033-067', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 67, 112.2, 180.0, 1.700, 1.400, true),
  ('fdcdd8f0-ce17-51bf-98ab-de773009e9be', 'P0033-068', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 68, 113.9, 180.0, 1.700, 1.400, true),
  ('87df68ef-ee66-5b8d-8a26-6a56191264f5', 'P0033-069', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 69, 115.6, 180.0, 1.700, 1.400, true),
  ('b9e6167b-b240-5bf2-93fb-a5cdb17b9d21', 'P0033-070', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 70, 117.3, 180.0, 1.700, 1.400, true),
  ('1f322bf8-dd54-53c5-bd15-a851e606ef61', 'P0033-071', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 71, 119.0, 180.0, 1.700, 1.400, true),
  ('b7eb2ef6-723d-55e9-ae54-09f8a654b2ac', 'P0033-072', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 72, 120.7, 180.0, 1.700, 1.400, true),
  ('f099721c-61c9-590b-b48a-1af4d03093d1', 'P0033-073', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 73, 122.4, 180.0, 1.700, 1.400, true),
  ('56ed72bd-26ab-5c62-9b63-f0b96b1d976a', 'P0033-074', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 74, 124.1, 180.0, 1.700, 1.400, true),
  ('6c532e46-4213-543d-bf58-2d2424ae3b19', 'P0033-075', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 75, 125.8, 180.0, 1.700, 1.400, true),
  ('2b730a0f-aac8-52d5-8323-26e8ef93ac8e', 'P0033-076', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 76, 127.5, 180.0, 1.700, 1.400, true),
  ('7be47030-7039-58c3-88bf-7328c2c3f1e0', 'P0033-077', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 77, 129.2, 180.0, 1.700, 1.400, true),
  ('07dc11ae-ba55-5017-9b89-28e90e6b6132', 'P0033-078', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 78, 130.9, 180.0, 1.700, 1.400, true),
  ('d9d6c122-eb52-5900-a876-838b2709310b', 'P0033-079', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 79, 132.6, 180.0, 1.700, 1.400, true),
  ('b4c680cb-4b0f-5d2b-9bad-8a35eb7af044', 'P0033-080', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 80, 134.3, 180.0, 1.700, 1.400, true),
  ('15553568-b8f7-5c82-8ec1-aab19952b6de', 'P0033-081', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 81, 136.0, 180.0, 1.700, 1.400, true),
  ('be03c1af-2f2f-5ad8-a129-2eb0343b370b', 'P0033-082', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 82, 137.7, 180.0, 1.700, 1.400, true),
  ('39551ebb-07e8-5b87-8a5a-47d29098fc4e', 'P0033-083', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 83, 139.4, 180.0, 1.700, 1.400, true),
  ('ac34be93-49ee-5917-b175-746b6fa8ac24', 'P0033-084', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 84, 141.1, 180.0, 1.700, 1.400, true),
  ('b83aee1c-c154-503d-b00b-5f6222100470', 'P0033-085', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 85, 142.8, 180.0, 1.700, 1.400, true),
  ('4a1fb504-8967-5540-8df7-45ec7aa7def2', 'P0033-086', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 86, 144.5, 180.0, 1.700, 1.400, true),
  ('0aebe0ea-335c-592b-bdb4-1e8a77733fec', 'P0033-087', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 87, 146.2, 180.0, 1.700, 1.400, true),
  ('e19969d0-5216-5b00-b639-111ab0381e44', 'P0033-088', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 88, 147.9, 180.0, 1.700, 1.400, true),
  ('accf31cf-c5f7-5fd9-b163-cc0b44ce953b', 'P0033-089', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 89, 149.6, 180.0, 1.700, 1.400, true),
  ('c63f4bcf-0081-52bf-a582-e3b5381db0f7', 'P0033-090', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 90, 151.3, 180.0, 1.700, 1.400, true),
  ('9a6e54bd-379f-5009-8d2c-2f68323ce805', 'P0033-091', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 91, 153.0, 180.0, 1.700, 1.400, true),
  ('05746304-5e6e-5494-b0fa-231e8cfab6b7', 'P0033-092', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 92, 154.7, 180.0, 1.700, 1.400, true),
  ('5c8be5e4-8bda-5122-adf8-258341d53c91', 'P0033-093', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 93, 156.4, 180.0, 1.700, 1.400, true),
  ('832494dd-ba03-5377-a282-647b5d415c27', 'P0033-094', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 94, 158.1, 180.0, 1.700, 1.400, true),
  ('053c946f-7668-5ff8-ac19-3cafde8fc4a5', 'P0033-095', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 95, 159.8, 180.0, 1.700, 1.400, true),
  ('84bf2ed7-3ce0-5683-a5aa-f99f0e9553ee', 'P0033-096', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 96, 161.5, 180.0, 1.700, 1.400, true),
  ('a2b1fbab-5dea-5eeb-ab2e-006912f85791', 'P0033-097', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 97, 163.2, 180.0, 1.700, 1.400, true),
  ('38b2891c-022f-58c7-bfb3-0d630498eec1', 'P0033-098', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 98, 164.9, 180.0, 1.700, 1.400, true),
  ('f31a4530-d287-5639-9993-c25ace43ff9f', 'P0033-099', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 99, 166.6, 180.0, 1.700, 1.400, true),
  ('4396a277-8c13-5fcd-b24c-1f446f305001', 'P0033-100', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 100, 168.3, 180.0, 1.700, 1.400, true),
  ('ab93d7f9-f675-547f-b84c-609d6a56ec98', 'P0033-101', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 101, 170.0, 180.0, 1.700, 1.400, true),
  ('1f7970b3-105e-5607-a3b2-9d41e82c092b', 'P0033-102', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 102, 171.7, 180.0, 1.700, 1.400, true),
  ('dbe2e5ef-c9a5-50b3-85e0-fed888a7b4ba', 'P0033-103', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 103, 173.4, 180.0, 1.700, 1.400, true),
  ('ab50d854-506d-5af8-8790-cc4aed85cced', 'P0033-104', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 104, 175.1, 180.0, 1.700, 1.400, true),
  ('a8c34479-c841-53b8-a5ac-dc3a9b69531c', 'P0033-105', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 105, 176.8, 180.0, 1.700, 1.400, true),
  ('8ef8a9f9-ee99-538c-b13f-df61f9ebee9e', 'P0033-106', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 106, 178.5, 180.0, 1.700, 1.400, true),
  ('4f225e51-e118-5d9f-83b6-69716cbbaa2a', 'P0033-107', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 107, 180.2, 180.0, 1.700, 1.400, true),
  ('a563674a-d556-5c5b-afb9-17b32da9a4e4', 'P0033-108', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 108, 181.9, 180.0, 1.700, 1.400, true),
  ('eb7f03ca-3706-521e-bff7-30da19238e3e', 'P0033-109', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 109, 183.6, 180.0, 1.700, 1.400, true),
  ('a6b8f270-5cba-5bf2-99b9-10147d6e70a7', 'P0033-110', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 110, 185.3, 180.0, 1.700, 1.400, true),
  ('5490b0aa-f457-5b33-b6df-fd37b0a2a8c5', 'P0033-111', '99c0be4c-572f-5185-a7b1-d8c2622a0a47', 111, 187.0, 180.0, 1.700, 1.400, true),
  ('2245fc3a-431d-5919-ac68-07fa1a7e0445', 'P0034-001', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 1, 0.0, 180.0, 1.700, 1.400, true),
  ('afa105cf-4024-5ae3-a397-51f223c3b61e', 'P0034-002', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 2, 1.7, 180.0, 1.700, 1.400, true),
  ('e6fe451f-d280-52f8-83ec-64055bc20229', 'P0034-003', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 3, 3.4, 180.0, 1.700, 1.400, true),
  ('52e5ffc4-d446-5c82-bba9-6185f2f70c8c', 'P0034-004', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 4, 5.1, 180.0, 1.700, 1.400, true),
  ('9c01be31-ef7f-5e87-b716-e0cff1c386c5', 'P0034-005', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 5, 6.8, 180.0, 1.700, 1.400, true),
  ('6b64d644-b101-5fdd-8818-3217076b8f08', 'P0034-006', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 6, 8.5, 180.0, 1.700, 1.400, true),
  ('a509e0b4-20ce-5080-b22c-362ee127ca76', 'P0034-007', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 7, 10.2, 180.0, 1.700, 1.400, true),
  ('b5cf660c-fc05-5d69-a66f-a9c3b2528b6c', 'P0034-008', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 8, 11.9, 180.0, 1.700, 1.400, true),
  ('8a2829fc-7f73-5a9f-b0f5-904d8a4cd613', 'P0034-009', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 9, 13.6, 180.0, 1.700, 1.400, true),
  ('708abedc-74bc-5e2a-9623-b5b8034cc0b0', 'P0034-010', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 10, 15.3, 180.0, 1.700, 1.400, true),
  ('38035bdb-f055-5310-9e5f-cd38b49e0fc6', 'P0034-011', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 11, 17.0, 180.0, 1.700, 1.400, true),
  ('f2cfa323-14d8-53d5-bc5f-bddc974308b3', 'P0034-012', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 12, 18.7, 180.0, 1.700, 1.400, true),
  ('ed104a59-2016-53cc-b687-7908f9a2b1fe', 'P0034-013', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 13, 20.4, 180.0, 1.700, 1.400, true),
  ('783c0705-5fd4-5fe6-882b-e969f6681c6b', 'P0034-014', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 14, 22.1, 180.0, 1.700, 1.400, true),
  ('ea2ff9bc-afae-5314-9277-4a0d1feaa2b5', 'P0034-015', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 15, 23.8, 180.0, 1.700, 1.400, true),
  ('cc56e5f1-aeca-5d73-84a2-78d88633a0b2', 'P0034-016', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 16, 25.5, 180.0, 1.700, 1.400, true),
  ('fa90c60a-ea6f-59e5-8783-7e7d817fc464', 'P0034-017', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 17, 27.2, 180.0, 1.700, 1.400, true),
  ('45f44d3f-fbbe-56af-806c-9e41d6a8ae13', 'P0034-018', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 18, 28.9, 180.0, 1.700, 1.400, true),
  ('63c9c3e2-3831-56e5-a306-d5fa7c6bbb1b', 'P0034-019', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 19, 30.6, 180.0, 1.700, 1.400, true),
  ('c15feeb2-869f-5c24-9b74-95fcf0b26c67', 'P0034-020', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 20, 32.3, 180.0, 1.700, 1.400, true),
  ('9713fb0e-1a89-572d-9906-2cf663b4493a', 'P0034-021', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 21, 34.0, 180.0, 1.700, 1.400, true),
  ('940f535f-32c0-516a-9a11-8c4055a9bf3c', 'P0034-022', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 22, 35.7, 180.0, 1.700, 1.400, true),
  ('bcd3d045-0c63-525f-821c-60e5c9581bfc', 'P0034-023', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 23, 37.4, 180.0, 1.700, 1.400, true),
  ('96dc6afd-99ed-5e7b-9492-2ed92fefd0d4', 'P0034-024', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 24, 39.1, 180.0, 1.700, 1.400, true),
  ('1e0b8883-7d4f-5e9a-abfd-e7b8ee82e2cb', 'P0034-025', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 25, 40.8, 180.0, 1.700, 1.400, true),
  ('293222da-4542-5f16-ba85-123591b23014', 'P0034-026', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 26, 42.5, 180.0, 1.700, 1.400, true),
  ('3ff34af4-118a-5246-8e8d-b30985b90df2', 'P0034-027', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 27, 44.2, 180.0, 1.700, 1.400, true),
  ('04356e80-a1a1-59d7-aee6-15105c92c2e0', 'P0034-028', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 28, 45.9, 180.0, 1.700, 1.400, true),
  ('77cb8598-33a1-544f-9c08-9d05ab4296e2', 'P0034-029', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 29, 47.6, 180.0, 1.700, 1.400, true),
  ('be79d42d-cfc5-582d-91a8-e174d8079972', 'P0034-030', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 30, 49.3, 180.0, 1.700, 1.400, true),
  ('1d91bf5d-e102-5083-a0c1-3b26b57232b5', 'P0034-031', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 31, 51.0, 180.0, 1.700, 1.400, true),
  ('0b0106f7-ae41-5ed1-9e1a-4df0f91f1c4d', 'P0034-032', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 32, 52.7, 180.0, 1.700, 1.400, true),
  ('aa67fc63-5dff-584f-ad71-4d095020fa28', 'P0034-033', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 33, 54.4, 180.0, 1.700, 1.400, true),
  ('28675ffd-dd44-5f82-b662-5dd90d57b76d', 'P0034-034', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 34, 56.1, 180.0, 1.700, 1.400, true),
  ('29d4bca3-d908-58ce-a055-520eeb46d031', 'P0034-035', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 35, 57.8, 180.0, 1.700, 1.400, true),
  ('56571c67-0f82-5401-bd8c-9d75b95e4212', 'P0034-036', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 36, 59.5, 180.0, 1.700, 1.400, true),
  ('5441c760-be61-5921-a0ba-28ca9635a4c5', 'P0034-037', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 37, 61.2, 180.0, 1.700, 1.400, true),
  ('686d4b82-a5ce-5fd8-a4ec-2ed789f4fac1', 'P0034-038', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 38, 62.9, 180.0, 1.700, 1.400, true),
  ('02adb11c-6866-5894-ba46-64d65e60f947', 'P0034-039', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 39, 64.6, 180.0, 1.700, 1.400, true),
  ('fef0a2e7-a129-5510-b743-ea8685f0e366', 'P0034-040', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 40, 66.3, 180.0, 1.700, 1.400, true),
  ('378d3758-61c3-54a0-b42a-ad319d0477f8', 'P0034-041', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 41, 68.0, 180.0, 1.700, 1.400, true),
  ('e62082b2-6339-57f7-87a8-7ae40954dd6d', 'P0034-042', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 42, 69.7, 180.0, 1.700, 1.400, true),
  ('10dd9046-480f-5a3b-93ed-a52a2117e90d', 'P0034-043', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 43, 71.4, 180.0, 1.700, 1.400, true),
  ('488ab60b-1e06-5ccb-9e5c-b667a1a4b126', 'P0034-044', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 44, 73.1, 180.0, 1.700, 1.400, true),
  ('2b4bbf55-1ba5-5575-a1b0-8b5587eb3962', 'P0034-045', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 45, 74.8, 180.0, 1.700, 1.400, true),
  ('9142760a-4006-53ab-829f-6cfb22ca47eb', 'P0034-046', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 46, 76.5, 180.0, 1.700, 1.400, true),
  ('251cf660-2e08-55ff-8054-bcb7e7125344', 'P0034-047', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 47, 78.2, 180.0, 1.700, 1.400, true),
  ('e33e1409-bbb6-5bb1-a495-fbac94f39b30', 'P0034-048', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 48, 79.9, 180.0, 1.700, 1.400, true),
  ('448dbb90-8a62-5d15-8a38-6b316232bbdb', 'P0034-049', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 49, 81.6, 180.0, 1.700, 1.400, true),
  ('a2cde314-0699-5030-8079-ad3b31dd7301', 'P0034-050', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 50, 83.3, 180.0, 1.700, 1.400, true),
  ('5b752650-f85d-5097-85d4-5bfcf7acecf9', 'P0034-051', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 51, 85.0, 180.0, 1.700, 1.400, true),
  ('2d727df0-43e6-5713-8886-0253e74ec619', 'P0034-052', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 52, 86.7, 180.0, 1.700, 1.400, true),
  ('c90e0998-6000-56a9-b9ab-54522df07764', 'P0034-053', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 53, 88.4, 180.0, 1.700, 1.400, true),
  ('9c879a5a-fcd9-5f93-b79f-d73195dd9370', 'P0034-054', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 54, 90.1, 180.0, 1.700, 1.400, true),
  ('729747e3-6ffa-5b3e-bf4a-03dd6b654262', 'P0034-055', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 55, 91.8, 180.0, 1.700, 1.400, true),
  ('7d620650-2c3c-50dc-bec3-3ad8ba48927f', 'P0034-056', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 56, 93.5, 180.0, 1.700, 1.400, true),
  ('1156ecfc-9b02-57ee-9380-23f850e65eab', 'P0034-057', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 57, 95.2, 180.0, 1.700, 1.400, true),
  ('7c7e4c6a-817b-56b8-9ddd-291d66edbcaf', 'P0034-058', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 58, 96.9, 180.0, 1.700, 1.400, true),
  ('7ee3a4b6-e127-5a61-be30-6ba42adf1304', 'P0034-059', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 59, 98.6, 180.0, 1.700, 1.400, true),
  ('c061e97c-c7d6-54be-99b6-f77b75d4fa01', 'P0034-060', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 60, 100.3, 180.0, 1.700, 1.400, true),
  ('30369a12-aef0-5c94-8de3-a96dcf5242bc', 'P0034-061', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 61, 102.0, 180.0, 1.700, 1.400, true),
  ('cfeeb909-fd06-5183-8000-e73dc83a0f0b', 'P0034-062', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 62, 103.7, 180.0, 1.700, 1.400, true),
  ('01946468-fc89-5f22-bbfc-627801ed81d5', 'P0034-063', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 63, 105.4, 180.0, 1.700, 1.400, true),
  ('7801f9e9-5c18-5d7e-9b1e-ef537a4166df', 'P0034-064', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 64, 107.1, 180.0, 1.700, 1.400, true),
  ('02f63b0b-99a0-5eb9-ae16-c577a7e9622f', 'P0034-065', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 65, 108.8, 180.0, 1.700, 1.400, true),
  ('2caf7f0d-ee8d-5622-a37b-2df67ba5435e', 'P0034-066', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 66, 110.5, 180.0, 1.700, 1.400, true),
  ('986585c0-d847-545f-88b5-157e9558898f', 'P0034-067', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 67, 112.2, 180.0, 1.700, 1.400, true),
  ('06f3c1b0-ba77-51bb-bdb4-97d03c417ba6', 'P0034-068', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 68, 113.9, 180.0, 1.700, 1.400, true),
  ('c6686950-258b-5b27-bc71-ce00048a1050', 'P0034-069', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 69, 115.6, 180.0, 1.700, 1.400, true),
  ('c9f24cda-30d9-56d0-8152-f633131665b5', 'P0034-070', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 70, 117.3, 180.0, 1.700, 1.400, true),
  ('7b36cff8-20cd-5ca3-92a8-677dd2ab9212', 'P0034-071', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 71, 119.0, 180.0, 1.700, 1.400, true),
  ('374caf19-6d5d-51ea-b0b3-57cfc5fa6af8', 'P0034-072', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 72, 120.7, 180.0, 1.700, 1.400, true),
  ('d23a0b46-9ab0-5d44-9c71-337b8949addc', 'P0034-073', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 73, 122.4, 180.0, 1.700, 1.400, true),
  ('c447056c-7f0b-53d7-ae88-db188da99ed9', 'P0034-074', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 74, 124.1, 180.0, 1.700, 1.400, true),
  ('8be8a832-0007-502f-886f-80646202f970', 'P0034-075', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 75, 125.8, 180.0, 1.700, 1.400, true),
  ('712484f9-32b1-5384-a5d4-823b5632f334', 'P0034-076', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 76, 127.5, 180.0, 1.700, 1.400, true),
  ('d2664cee-819b-53aa-a877-b0a9d60e47b2', 'P0034-077', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 77, 129.2, 180.0, 1.700, 1.400, true),
  ('839d7a16-9c77-5ea4-b75f-55212beb97fb', 'P0034-078', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 78, 130.9, 180.0, 1.700, 1.400, true),
  ('bf7413d3-bc0d-5d28-a000-2ffd6972ec21', 'P0034-079', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 79, 132.6, 180.0, 1.700, 1.400, true),
  ('1b52b5b8-d393-519d-8263-4e9bd60df945', 'P0034-080', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 80, 134.3, 180.0, 1.700, 1.400, true),
  ('73959bf1-ddea-50b9-9d44-464aae7ebc1e', 'P0034-081', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 81, 136.0, 180.0, 1.700, 1.400, true),
  ('1ec5d7cc-dedf-5900-8bb9-88c52e79038d', 'P0034-082', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 82, 137.7, 180.0, 1.700, 1.400, true),
  ('19ae0178-a238-5235-ac87-3d346f41f94f', 'P0034-083', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 83, 139.4, 180.0, 1.700, 1.400, true),
  ('9614a7e1-6796-5b89-bdc0-126c534a57ab', 'P0034-084', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 84, 141.1, 180.0, 1.700, 1.400, true),
  ('dea3b339-ec48-542a-90eb-8028c841ae5f', 'P0034-085', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 85, 142.8, 180.0, 1.700, 1.400, true),
  ('a0dc0403-d79a-532c-bdfe-e22cd409d45e', 'P0034-086', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 86, 144.5, 180.0, 1.700, 1.400, true),
  ('182799f7-a74e-5cbd-abf2-aa5a8247b0f4', 'P0034-087', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 87, 146.2, 180.0, 1.700, 1.400, true),
  ('0ce5bfa3-f8cb-5a58-8fc3-a88c0304cb13', 'P0034-088', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 88, 147.9, 180.0, 1.700, 1.400, true),
  ('3e869e90-9f97-5b32-8dd1-a28a03b7faa0', 'P0034-089', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 89, 149.6, 180.0, 1.700, 1.400, true),
  ('acf9708d-a82c-55ec-8f3c-2a0d4ccc3a9d', 'P0034-090', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 90, 151.3, 180.0, 1.700, 1.400, true),
  ('6d6b5a94-a348-5402-83b4-f89e4b4d2772', 'P0034-091', 'b8723747-a5ff-5bb9-8bfe-926f16e80a2c', 91, 153.0, 180.0, 1.700, 1.400, true),
  ('833bc0d5-4982-5a0b-ab51-95b236920ae7', 'P0035-001', '667a1213-c337-5706-8c79-45ac5e928274', 1, 0.0, 180.0, 1.700, 1.400, true),
  ('ca2943bf-2d1c-55ee-bd70-793cb652879f', 'P0035-002', '667a1213-c337-5706-8c79-45ac5e928274', 2, 1.7, 180.0, 1.700, 1.400, true),
  ('d381d5ae-5863-5346-adac-f26aa274b61e', 'P0035-003', '667a1213-c337-5706-8c79-45ac5e928274', 3, 3.4, 180.0, 1.700, 1.400, true),
  ('589580d2-d65f-5b1f-bf7a-46188eb81cd3', 'P0035-004', '667a1213-c337-5706-8c79-45ac5e928274', 4, 5.1, 180.0, 1.700, 1.400, true),
  ('a974d2a2-0f32-5edb-83b0-437d7d975b8f', 'P0035-005', '667a1213-c337-5706-8c79-45ac5e928274', 5, 6.8, 180.0, 1.700, 1.400, true),
  ('26807257-8203-56ff-a180-b955fba69be8', 'P0035-006', '667a1213-c337-5706-8c79-45ac5e928274', 6, 8.5, 180.0, 1.700, 1.400, true),
  ('f0fe1800-f607-54bf-8f06-dc5e7706cfa4', 'P0035-007', '667a1213-c337-5706-8c79-45ac5e928274', 7, 10.2, 180.0, 1.700, 1.400, true),
  ('c06fa6ae-88df-5374-9269-dcc34c520292', 'P0035-008', '667a1213-c337-5706-8c79-45ac5e928274', 8, 11.9, 180.0, 1.700, 1.400, true),
  ('4f704857-bd7a-57dc-b941-5a899531ed50', 'P0035-009', '667a1213-c337-5706-8c79-45ac5e928274', 9, 13.6, 180.0, 1.700, 1.400, true),
  ('ebd1e1f5-7e51-554e-8730-8499f8ff3f23', 'P0035-010', '667a1213-c337-5706-8c79-45ac5e928274', 10, 15.3, 180.0, 1.700, 1.400, true),
  ('345c0f86-0522-5ddf-8af2-bc6f58182959', 'P0035-011', '667a1213-c337-5706-8c79-45ac5e928274', 11, 17.0, 180.0, 1.700, 1.400, true),
  ('00789558-57e1-5889-94ab-bed521204f1b', 'P0035-012', '667a1213-c337-5706-8c79-45ac5e928274', 12, 18.7, 180.0, 1.700, 1.400, true),
  ('6968f258-5265-5c1b-8699-1c7e2b6f7358', 'P0035-013', '667a1213-c337-5706-8c79-45ac5e928274', 13, 20.4, 180.0, 1.700, 1.400, true),
  ('ceea4491-cc09-50a9-b93b-07c28e49a601', 'P0035-014', '667a1213-c337-5706-8c79-45ac5e928274', 14, 22.1, 180.0, 1.700, 1.400, true),
  ('72234755-7135-5420-8c40-b5bbf27fd7e0', 'P0035-015', '667a1213-c337-5706-8c79-45ac5e928274', 15, 23.8, 180.0, 1.700, 1.400, true),
  ('31839039-3866-5ccc-b58c-f9b0912807e9', 'P0035-016', '667a1213-c337-5706-8c79-45ac5e928274', 16, 25.5, 180.0, 1.700, 1.400, true),
  ('36e1cd2d-2e15-5f49-bd27-e633027dc8da', 'P0035-017', '667a1213-c337-5706-8c79-45ac5e928274', 17, 27.2, 180.0, 1.700, 1.400, true),
  ('99701b52-1528-5e34-9c7c-b6359b8f9189', 'P0035-018', '667a1213-c337-5706-8c79-45ac5e928274', 18, 28.9, 180.0, 1.700, 1.400, true),
  ('84c45ba1-f61d-5281-a61a-3c6a740d4cf5', 'P0035-019', '667a1213-c337-5706-8c79-45ac5e928274', 19, 30.6, 180.0, 1.700, 1.400, true),
  ('39863d3b-ec1d-5efc-b23f-2cd64f2282bc', 'P0035-020', '667a1213-c337-5706-8c79-45ac5e928274', 20, 32.3, 180.0, 1.700, 1.400, true),
  ('6899a987-4ce0-59b0-87fb-42b062bf06c5', 'P0035-021', '667a1213-c337-5706-8c79-45ac5e928274', 21, 34.0, 180.0, 1.700, 1.400, true),
  ('f3511d77-d146-5d7a-9a59-d0a0e37639f1', 'P0035-022', '667a1213-c337-5706-8c79-45ac5e928274', 22, 35.7, 180.0, 1.700, 1.400, true),
  ('f9727e8e-1a7a-5b91-a271-b060b4df0034', 'P0035-023', '667a1213-c337-5706-8c79-45ac5e928274', 23, 37.4, 180.0, 1.700, 1.400, true),
  ('1bde20e1-efac-5da8-bacc-00dab9a16d9b', 'P0035-024', '667a1213-c337-5706-8c79-45ac5e928274', 24, 39.1, 180.0, 1.700, 1.400, true),
  ('b832d87b-ab91-58d8-bb42-f914eb492ea3', 'P0035-025', '667a1213-c337-5706-8c79-45ac5e928274', 25, 40.8, 180.0, 1.700, 1.400, true),
  ('dd528a11-995e-5610-86b5-305797f17d9f', 'P0035-026', '667a1213-c337-5706-8c79-45ac5e928274', 26, 42.5, 180.0, 1.700, 1.400, true),
  ('c6d3324e-a08d-587d-b7ec-5cc379beb910', 'P0035-027', '667a1213-c337-5706-8c79-45ac5e928274', 27, 44.2, 180.0, 1.700, 1.400, true),
  ('8dde3d39-66e0-5bb1-acb8-85133c1277c4', 'P0035-028', '667a1213-c337-5706-8c79-45ac5e928274', 28, 45.9, 180.0, 1.700, 1.400, true),
  ('04013a54-dad6-5eaf-a558-77290645d83f', 'P0035-029', '667a1213-c337-5706-8c79-45ac5e928274', 29, 47.6, 180.0, 1.700, 1.400, true),
  ('3b773757-855e-5537-92ee-76f84dd363cd', 'P0035-030', '667a1213-c337-5706-8c79-45ac5e928274', 30, 49.3, 180.0, 1.700, 1.400, true),
  ('8c4def58-3f9e-59d2-850b-a0c6d110d4e6', 'P0035-031', '667a1213-c337-5706-8c79-45ac5e928274', 31, 51.0, 180.0, 1.700, 1.400, true),
  ('253bbec1-fb49-5cf0-a2a6-657867a41e80', 'P0035-032', '667a1213-c337-5706-8c79-45ac5e928274', 32, 52.7, 180.0, 1.700, 1.400, true),
  ('68844925-3115-5b33-9b89-19dee6ca693f', 'P0035-033', '667a1213-c337-5706-8c79-45ac5e928274', 33, 54.4, 180.0, 1.700, 1.400, true),
  ('0b2e9230-5fa3-5095-927e-dc3d0e76126b', 'P0035-034', '667a1213-c337-5706-8c79-45ac5e928274', 34, 56.1, 180.0, 1.700, 1.400, true),
  ('0c3b849e-bea2-5f41-8f11-d456489b8471', 'P0035-035', '667a1213-c337-5706-8c79-45ac5e928274', 35, 57.8, 180.0, 1.700, 1.400, true),
  ('c631877b-4796-55e7-afc9-e22a3e92f3ef', 'P0035-036', '667a1213-c337-5706-8c79-45ac5e928274', 36, 59.5, 180.0, 1.700, 1.400, true),
  ('22c9aa2e-4a7f-55f7-aba2-e3377a9e792f', 'P0035-037', '667a1213-c337-5706-8c79-45ac5e928274', 37, 61.2, 180.0, 1.700, 1.400, true),
  ('f46370b4-0e0e-5425-b14c-511012660eec', 'P0035-038', '667a1213-c337-5706-8c79-45ac5e928274', 38, 62.9, 180.0, 1.700, 1.400, true),
  ('7ba026a9-6ea5-5300-b8e4-e855f44c03d3', 'P0035-039', '667a1213-c337-5706-8c79-45ac5e928274', 39, 64.6, 180.0, 1.700, 1.400, true),
  ('e9cf01d6-0c97-53f4-b894-12417b660152', 'P0035-040', '667a1213-c337-5706-8c79-45ac5e928274', 40, 66.3, 180.0, 1.700, 1.400, true),
  ('d3d6fb75-db78-5258-89dd-1e622eac3f38', 'P0035-041', '667a1213-c337-5706-8c79-45ac5e928274', 41, 68.0, 180.0, 1.700, 1.400, true),
  ('bbf42d13-1b6b-5dbb-abdd-7e871e4b536d', 'P0035-042', '667a1213-c337-5706-8c79-45ac5e928274', 42, 69.7, 180.0, 1.700, 1.400, true),
  ('0ed3504d-50a4-555f-87ff-d85251d0dc74', 'P0035-043', '667a1213-c337-5706-8c79-45ac5e928274', 43, 71.4, 180.0, 1.700, 1.400, true),
  ('c63a6987-e148-5e89-98e0-8b94e6627218', 'P0035-044', '667a1213-c337-5706-8c79-45ac5e928274', 44, 73.1, 180.0, 1.700, 1.400, true),
  ('b86065b5-01bf-50e4-be24-e40203eda4cb', 'P0035-045', '667a1213-c337-5706-8c79-45ac5e928274', 45, 74.8, 180.0, 1.700, 1.400, true),
  ('d32f006b-275a-571b-883d-c15694909dc6', 'P0035-046', '667a1213-c337-5706-8c79-45ac5e928274', 46, 76.5, 180.0, 1.700, 1.400, true),
  ('de19054f-1a38-5f6b-9c31-cfa7598729d9', 'P0035-047', '667a1213-c337-5706-8c79-45ac5e928274', 47, 78.2, 180.0, 1.700, 1.400, true),
  ('1725f680-c1da-5846-84e4-d6fe9d02614e', 'P0035-048', '667a1213-c337-5706-8c79-45ac5e928274', 48, 79.9, 180.0, 1.700, 1.400, true),
  ('b413b398-19d0-522e-8367-1396c2f98ece', 'P0035-049', '667a1213-c337-5706-8c79-45ac5e928274', 49, 81.6, 180.0, 1.700, 1.400, true),
  ('3c6cd34e-98fd-5bf0-b1a2-c3e08e4340c3', 'P0035-050', '667a1213-c337-5706-8c79-45ac5e928274', 50, 83.3, 180.0, 1.700, 1.400, true),
  ('266606b2-e7b4-5d68-9659-de4f3c4c9ebf', 'P0035-051', '667a1213-c337-5706-8c79-45ac5e928274', 51, 85.0, 180.0, 1.700, 1.400, true),
  ('e5c60ff8-eee2-5ab1-8bcd-162608be8f05', 'P0035-052', '667a1213-c337-5706-8c79-45ac5e928274', 52, 86.7, 180.0, 1.700, 1.400, true),
  ('bb540a44-0e1c-562e-8cfb-30d8c713e5bd', 'P0035-053', '667a1213-c337-5706-8c79-45ac5e928274', 53, 88.4, 180.0, 1.700, 1.400, true),
  ('bbb73fec-06ff-50f6-85aa-a3b9523f13f9', 'P0035-054', '667a1213-c337-5706-8c79-45ac5e928274', 54, 90.1, 180.0, 1.700, 1.400, true),
  ('bce79ddc-32b1-587b-958b-1edfe1bff416', 'P0035-055', '667a1213-c337-5706-8c79-45ac5e928274', 55, 91.8, 180.0, 1.700, 1.400, true),
  ('2c0fd5da-4976-56a9-9878-a559600ed4e4', 'P0035-056', '667a1213-c337-5706-8c79-45ac5e928274', 56, 93.5, 180.0, 1.700, 1.400, true),
  ('e27b98f0-db50-541e-947e-cbe0a62c6e88', 'P0035-057', '667a1213-c337-5706-8c79-45ac5e928274', 57, 95.2, 180.0, 1.700, 1.400, true),
  ('90bcbb73-14f9-5f87-b424-6893ef25d6e4', 'P0035-058', '667a1213-c337-5706-8c79-45ac5e928274', 58, 96.9, 180.0, 1.700, 1.400, true),
  ('fb6b205a-a7b7-5796-9cf6-bd40fa45b798', 'P0035-059', '667a1213-c337-5706-8c79-45ac5e928274', 59, 98.6, 180.0, 1.700, 1.400, true),
  ('cbe875b0-a1f3-5c3b-b44f-19cff3c9dca4', 'P0035-060', '667a1213-c337-5706-8c79-45ac5e928274', 60, 100.3, 180.0, 1.700, 1.400, true),
  ('1b202e7d-1465-5af9-994d-38e943a71864', 'P0035-061', '667a1213-c337-5706-8c79-45ac5e928274', 61, 102.0, 180.0, 1.700, 1.400, true),
  ('bdc913ad-8fd7-5546-9724-3b33d473f844', 'P0035-062', '667a1213-c337-5706-8c79-45ac5e928274', 62, 103.7, 180.0, 1.700, 1.400, true),
  ('f64f49ea-b4f0-54d9-aa6d-d4c46cc97cf8', 'P0035-063', '667a1213-c337-5706-8c79-45ac5e928274', 63, 105.4, 180.0, 1.700, 1.400, true),
  ('6333dd83-52c0-5030-9b57-bc083ab6fb26', 'P0035-064', '667a1213-c337-5706-8c79-45ac5e928274', 64, 107.1, 180.0, 1.700, 1.400, true),
  ('8d066871-aa9f-547c-83ae-ee1662ddd974', 'P0035-065', '667a1213-c337-5706-8c79-45ac5e928274', 65, 108.8, 180.0, 1.700, 1.400, true),
  ('737b1837-88f7-5503-bbaf-0c52f4b664c4', 'P0035-066', '667a1213-c337-5706-8c79-45ac5e928274', 66, 110.5, 180.0, 1.700, 1.400, true),
  ('a0daa456-1758-5510-82cf-735f35c66e73', 'P0035-067', '667a1213-c337-5706-8c79-45ac5e928274', 67, 112.2, 180.0, 1.700, 1.400, true),
  ('13e6e493-eb5b-50ec-9bab-f9d097bee4c5', 'P0035-068', '667a1213-c337-5706-8c79-45ac5e928274', 68, 113.9, 180.0, 1.700, 1.400, true),
  ('ad491fb5-3d5b-5983-b625-bf5fafdad7b6', 'P0035-069', '667a1213-c337-5706-8c79-45ac5e928274', 69, 115.6, 180.0, 1.700, 1.400, true),
  ('ce97942e-73f7-5301-9d2e-1a81bc056371', 'P0035-070', '667a1213-c337-5706-8c79-45ac5e928274', 70, 117.3, 180.0, 1.700, 1.400, true),
  ('9ea8d5fc-8655-5a7a-af5f-cea5d7a13deb', 'P0035-071', '667a1213-c337-5706-8c79-45ac5e928274', 71, 119.0, 180.0, 1.700, 1.400, true),
  ('83248d7d-539a-5161-81f6-29c3145c07cb', 'P0035-072', '667a1213-c337-5706-8c79-45ac5e928274', 72, 120.7, 180.0, 1.700, 1.400, true),
  ('f90bba84-deef-5289-9152-45358564ae87', 'P0035-073', '667a1213-c337-5706-8c79-45ac5e928274', 73, 122.4, 180.0, 1.700, 1.400, true),
  ('dacfdae7-0ff0-5604-b320-829450c3c929', 'P0035-074', '667a1213-c337-5706-8c79-45ac5e928274', 74, 124.1, 180.0, 1.700, 1.400, true),
  ('638c2cf5-0ce6-5f12-bf8c-b3501ee12843', 'P0035-075', '667a1213-c337-5706-8c79-45ac5e928274', 75, 125.8, 180.0, 1.700, 1.400, true),
  ('12fc3812-411c-5ae3-b190-d64bbc92f8b8', 'P0035-076', '667a1213-c337-5706-8c79-45ac5e928274', 76, 127.5, 180.0, 1.700, 1.400, true),
  ('c6472af4-3fad-56e7-a598-0503a2d7d496', 'P0035-077', '667a1213-c337-5706-8c79-45ac5e928274', 77, 129.2, 180.0, 1.700, 1.400, true),
  ('37a3d792-e2a2-56f3-8868-1170794ade8b', 'P0035-078', '667a1213-c337-5706-8c79-45ac5e928274', 78, 130.9, 180.0, 1.700, 1.400, true),
  ('ba8d276d-153b-520b-aa91-4e372ba066a6', 'P0035-079', '667a1213-c337-5706-8c79-45ac5e928274', 79, 132.6, 180.0, 1.700, 1.400, true),
  ('5148b1a2-ec10-56ad-9278-3a534ff92599', 'P0035-080', '667a1213-c337-5706-8c79-45ac5e928274', 80, 134.3, 180.0, 1.700, 1.400, true),
  ('83ced731-465f-58ef-98b8-a9b88f126b94', 'P0035-081', '667a1213-c337-5706-8c79-45ac5e928274', 81, 136.0, 180.0, 1.700, 1.400, true),
  ('a991b59d-05e1-50fd-914c-640feb3dd091', 'P0035-082', '667a1213-c337-5706-8c79-45ac5e928274', 82, 137.7, 180.0, 1.700, 1.400, true),
  ('6c78afe6-f917-5185-8f16-b2c105dd15c2', 'P0035-083', '667a1213-c337-5706-8c79-45ac5e928274', 83, 139.4, 180.0, 1.700, 1.400, true),
  ('4ee92463-5ad2-54d9-9b94-973862178307', 'P0035-084', '667a1213-c337-5706-8c79-45ac5e928274', 84, 141.1, 180.0, 1.700, 1.400, true),
  ('10323b18-50ef-5976-b94a-e9bfcb66f4b5', 'P0035-085', '667a1213-c337-5706-8c79-45ac5e928274', 85, 142.8, 180.0, 1.700, 1.400, true),
  ('cab64dd7-045a-520c-996a-07ea7d7fd4b0', 'P0035-086', '667a1213-c337-5706-8c79-45ac5e928274', 86, 144.5, 180.0, 1.700, 1.400, true),
  ('352cad68-936d-54ec-8be1-2ccd06238c94', 'P0035-087', '667a1213-c337-5706-8c79-45ac5e928274', 87, 146.2, 180.0, 1.700, 1.400, true),
  ('a8fa4fc1-3f5f-59c2-8745-d3bd4a345dea', 'P0035-088', '667a1213-c337-5706-8c79-45ac5e928274', 88, 147.9, 180.0, 1.700, 1.400, true),
  ('82bd0419-2204-5cfc-9d86-72d539dc60fe', 'P0035-089', '667a1213-c337-5706-8c79-45ac5e928274', 89, 149.6, 180.0, 1.700, 1.400, true),
  ('11faf15c-103b-5778-ba7c-c4019921a49e', 'P0035-090', '667a1213-c337-5706-8c79-45ac5e928274', 90, 151.3, 180.0, 1.700, 1.400, true),
  ('f88e1546-a5b2-56ae-88c2-44df318b093a', 'P0035-091', '667a1213-c337-5706-8c79-45ac5e928274', 91, 153.0, 180.0, 1.700, 1.400, true),
  ('bf816331-4363-5eae-9211-ff4e40624748', 'P0036-001', '14193989-9230-582f-a6d9-722e745aee8f', 1, 0.0, 180.0, 1.700, 1.400, true),
  ('da272a7a-cba8-5aa3-bfe8-cf38f7fb2d49', 'P0036-002', '14193989-9230-582f-a6d9-722e745aee8f', 2, 1.7, 180.0, 1.700, 1.400, true),
  ('04dbe8c1-3e13-5d08-ada5-29a0ed302ce3', 'P0036-003', '14193989-9230-582f-a6d9-722e745aee8f', 3, 3.4, 180.0, 1.700, 1.400, true),
  ('430781f5-e6ae-5e79-a456-799d24917d06', 'P0036-004', '14193989-9230-582f-a6d9-722e745aee8f', 4, 5.1, 180.0, 1.700, 1.400, true),
  ('d1ca174b-3bb4-51e0-8f37-69f1d43dad5a', 'P0036-005', '14193989-9230-582f-a6d9-722e745aee8f', 5, 6.8, 180.0, 1.700, 1.400, true),
  ('624795e8-1d4e-536e-90f5-b0d4af1c357b', 'P0036-006', '14193989-9230-582f-a6d9-722e745aee8f', 6, 8.5, 180.0, 1.700, 1.400, true),
  ('089eedb1-3d5e-5a09-a32b-3c68d1481b12', 'P0036-007', '14193989-9230-582f-a6d9-722e745aee8f', 7, 10.2, 180.0, 1.700, 1.400, true),
  ('1a41a0fd-f024-5620-b850-cabf54607bcc', 'P0036-008', '14193989-9230-582f-a6d9-722e745aee8f', 8, 11.9, 180.0, 1.700, 1.400, true),
  ('659f2c55-2cfd-501c-9fd8-76a98ec5e5e8', 'P0036-009', '14193989-9230-582f-a6d9-722e745aee8f', 9, 13.6, 180.0, 1.700, 1.400, true),
  ('cad783bf-cd31-5d9e-80a8-7eda449c60b0', 'P0036-010', '14193989-9230-582f-a6d9-722e745aee8f', 10, 15.3, 180.0, 1.700, 1.400, true),
  ('aa967620-71a9-5e65-8e20-2bc846fb4550', 'P0036-011', '14193989-9230-582f-a6d9-722e745aee8f', 11, 17.0, 180.0, 1.700, 1.400, true),
  ('e994d9e9-d2ad-5078-a19d-42fe53490900', 'P0036-012', '14193989-9230-582f-a6d9-722e745aee8f', 12, 18.7, 180.0, 1.700, 1.400, true),
  ('d8f2fee7-a3e2-5808-990e-dbeba31298e5', 'P0036-013', '14193989-9230-582f-a6d9-722e745aee8f', 13, 20.4, 180.0, 1.700, 1.400, true),
  ('2d94527f-069f-5c2a-92fd-1ffadfb4b988', 'P0036-014', '14193989-9230-582f-a6d9-722e745aee8f', 14, 22.1, 180.0, 1.700, 1.400, true),
  ('ef0a480e-c524-5003-b5d1-6ced4ed72fd4', 'P0036-015', '14193989-9230-582f-a6d9-722e745aee8f', 15, 23.8, 180.0, 1.700, 1.400, true),
  ('1e3e3f6b-4703-5b17-b864-b511c62af133', 'P0036-016', '14193989-9230-582f-a6d9-722e745aee8f', 16, 25.5, 180.0, 1.700, 1.400, true),
  ('dd065152-4f9f-54af-baab-01b3c4c1cd45', 'P0036-017', '14193989-9230-582f-a6d9-722e745aee8f', 17, 27.2, 180.0, 1.700, 1.400, true),
  ('ac835b1e-effa-5573-be68-3b74dd20e36b', 'P0036-018', '14193989-9230-582f-a6d9-722e745aee8f', 18, 28.9, 180.0, 1.700, 1.400, true),
  ('318ccb00-64c7-56f2-8b1c-8f5a64d8a119', 'P0036-019', '14193989-9230-582f-a6d9-722e745aee8f', 19, 30.6, 180.0, 1.700, 1.400, true),
  ('f5e06df1-7e5e-5ceb-b712-1fd8794ea1c6', 'P0036-020', '14193989-9230-582f-a6d9-722e745aee8f', 20, 32.3, 180.0, 1.700, 1.400, true),
  ('9c5638bb-7ef2-533b-b1fa-e6b21dacd77c', 'P0036-021', '14193989-9230-582f-a6d9-722e745aee8f', 21, 34.0, 180.0, 1.700, 1.400, true),
  ('88d1cc74-2246-52be-8e2b-6ae632e36dfa', 'P0036-022', '14193989-9230-582f-a6d9-722e745aee8f', 22, 35.7, 180.0, 1.700, 1.400, true),
  ('f9f22d03-25d6-5b14-8ffc-f4f7fe32307e', 'P0036-023', '14193989-9230-582f-a6d9-722e745aee8f', 23, 37.4, 180.0, 1.700, 1.400, true),
  ('6be7d126-2fbc-5a00-8b0f-b31718080b82', 'P0036-024', '14193989-9230-582f-a6d9-722e745aee8f', 24, 39.1, 180.0, 1.700, 1.400, true),
  ('5537107d-3b8a-5ad6-9dc7-8e45322885a1', 'P0036-025', '14193989-9230-582f-a6d9-722e745aee8f', 25, 40.8, 180.0, 1.700, 1.400, true),
  ('f910d53c-3fb0-5f98-baf3-c68fe8ebf01e', 'P0036-026', '14193989-9230-582f-a6d9-722e745aee8f', 26, 42.5, 180.0, 1.700, 1.400, true),
  ('50d7619d-3d43-59d1-9265-7da4dbbecaf2', 'P0036-027', '14193989-9230-582f-a6d9-722e745aee8f', 27, 44.2, 180.0, 1.700, 1.400, true),
  ('4f10f3fc-e313-50a2-94e5-8139b4a9df33', 'P0036-028', '14193989-9230-582f-a6d9-722e745aee8f', 28, 45.9, 180.0, 1.700, 1.400, true),
  ('0e4e3bbf-f51f-5f13-9682-14156460d095', 'P0036-029', '14193989-9230-582f-a6d9-722e745aee8f', 29, 47.6, 180.0, 1.700, 1.400, true),
  ('38856407-e6f4-59fc-a2ef-304b41caec41', 'P0036-030', '14193989-9230-582f-a6d9-722e745aee8f', 30, 49.3, 180.0, 1.700, 1.400, true),
  ('7dc53018-682a-5ba0-aeb0-f4e6bb389160', 'P0036-031', '14193989-9230-582f-a6d9-722e745aee8f', 31, 51.0, 180.0, 1.700, 1.400, true),
  ('d232e983-e99d-5a01-acf3-2dfdac35632b', 'P0036-032', '14193989-9230-582f-a6d9-722e745aee8f', 32, 52.7, 180.0, 1.700, 1.400, true),
  ('7c80789e-7e8f-5724-93e9-6f31a956e533', 'P0036-033', '14193989-9230-582f-a6d9-722e745aee8f', 33, 54.4, 180.0, 1.700, 1.400, true),
  ('33092be4-a703-5882-b4f7-2e2d1cb5774b', 'P0036-034', '14193989-9230-582f-a6d9-722e745aee8f', 34, 56.1, 180.0, 1.700, 1.400, true),
  ('19f35a48-8fe4-53bb-af55-6d420e6830d4', 'P0036-035', '14193989-9230-582f-a6d9-722e745aee8f', 35, 57.8, 180.0, 1.700, 1.400, true),
  ('3f7f748b-07b9-555b-bb7b-369d41303119', 'P0036-036', '14193989-9230-582f-a6d9-722e745aee8f', 36, 59.5, 180.0, 1.700, 1.400, true),
  ('92790455-d625-5765-90fb-f894901f74b5', 'P0036-037', '14193989-9230-582f-a6d9-722e745aee8f', 37, 61.2, 180.0, 1.700, 1.400, true),
  ('cc0a3e02-0df8-5dbf-bb58-3b368eed89e5', 'P0036-038', '14193989-9230-582f-a6d9-722e745aee8f', 38, 62.9, 180.0, 1.700, 1.400, true),
  ('7762d1c8-0e30-5086-8d3e-a2d3b73523aa', 'P0036-039', '14193989-9230-582f-a6d9-722e745aee8f', 39, 64.6, 180.0, 1.700, 1.400, true),
  ('51dc3513-4f94-5963-8d21-c572bd8d5f7f', 'P0036-040', '14193989-9230-582f-a6d9-722e745aee8f', 40, 66.3, 180.0, 1.700, 1.400, true),
  ('1893aeb7-3299-57e7-8bd8-5583dd41a6b5', 'P0036-041', '14193989-9230-582f-a6d9-722e745aee8f', 41, 68.0, 180.0, 1.700, 1.400, true),
  ('bfc32d81-5b8f-5c6c-8b53-a312a0d55b1a', 'P0036-042', '14193989-9230-582f-a6d9-722e745aee8f', 42, 69.7, 180.0, 1.700, 1.400, true),
  ('2db68ca6-647e-5027-8c29-ba8bc46c8eb9', 'P0036-043', '14193989-9230-582f-a6d9-722e745aee8f', 43, 71.4, 180.0, 1.700, 1.400, true),
  ('65278cba-ee3f-5303-8590-5777089afe3b', 'P0036-044', '14193989-9230-582f-a6d9-722e745aee8f', 44, 73.1, 180.0, 1.700, 1.400, true),
  ('4c900745-d52e-5171-a7d9-a44e6f47965e', 'P0036-045', '14193989-9230-582f-a6d9-722e745aee8f', 45, 74.8, 180.0, 1.700, 1.400, true),
  ('70d8daf8-7ac0-5fc6-a972-50f23bd9d74e', 'P0036-046', '14193989-9230-582f-a6d9-722e745aee8f', 46, 76.5, 180.0, 1.700, 1.400, true),
  ('84516ae7-9201-52d4-8ab5-8bed1c1bbaf9', 'P0036-047', '14193989-9230-582f-a6d9-722e745aee8f', 47, 78.2, 180.0, 1.700, 1.400, true),
  ('f7e7b9a4-2013-58a4-8389-beb4cf5a09c2', 'P0036-048', '14193989-9230-582f-a6d9-722e745aee8f', 48, 79.9, 180.0, 1.700, 1.400, true),
  ('34695ebc-ba3a-5285-98a9-5ec6da378e32', 'P0036-049', '14193989-9230-582f-a6d9-722e745aee8f', 49, 81.6, 180.0, 1.700, 1.400, true),
  ('14e4caa7-3d98-5752-b59b-7d74fd22a4e5', 'P0036-050', '14193989-9230-582f-a6d9-722e745aee8f', 50, 83.3, 180.0, 1.700, 1.400, true),
  ('acd06af5-a2c8-5a0e-93da-2a36ccfec23a', 'P0036-051', '14193989-9230-582f-a6d9-722e745aee8f', 51, 85.0, 180.0, 1.700, 1.400, true),
  ('0d4e6d2f-f251-5793-a894-a582d2e07182', 'P0036-052', '14193989-9230-582f-a6d9-722e745aee8f', 52, 86.7, 180.0, 1.700, 1.400, true),
  ('0e2a4603-aa52-5d73-91e1-5524811db313', 'P0036-053', '14193989-9230-582f-a6d9-722e745aee8f', 53, 88.4, 180.0, 1.700, 1.400, true),
  ('fa76b1f2-7ed1-5a20-ad38-8895ddc37845', 'P0036-054', '14193989-9230-582f-a6d9-722e745aee8f', 54, 90.1, 180.0, 1.700, 1.400, true),
  ('772d3032-2cc3-5cf6-a372-552a6cf691a9', 'P0036-055', '14193989-9230-582f-a6d9-722e745aee8f', 55, 91.8, 180.0, 1.700, 1.400, true),
  ('21d87334-8be5-5f00-87b2-18dca4b06c37', 'P0036-056', '14193989-9230-582f-a6d9-722e745aee8f', 56, 93.5, 180.0, 1.700, 1.400, true),
  ('161b9494-da3d-527e-9140-bafce8fc612a', 'P0036-057', '14193989-9230-582f-a6d9-722e745aee8f', 57, 95.2, 180.0, 1.700, 1.400, true),
  ('4251a373-c68b-57ef-90c6-fe13001705b7', 'P0036-058', '14193989-9230-582f-a6d9-722e745aee8f', 58, 96.9, 180.0, 1.700, 1.400, true),
  ('17aafa3b-a8ea-59f8-8e32-d16aaf39e9df', 'P0036-059', '14193989-9230-582f-a6d9-722e745aee8f', 59, 98.6, 180.0, 1.700, 1.400, true),
  ('d7faddd9-0940-59e5-ae7e-da33be703697', 'P0036-060', '14193989-9230-582f-a6d9-722e745aee8f', 60, 100.3, 180.0, 1.700, 1.400, true),
  ('a09fb3ed-b118-5566-b061-447daae4bc1a', 'P0036-061', '14193989-9230-582f-a6d9-722e745aee8f', 61, 102.0, 180.0, 1.700, 1.400, true),
  ('02231e67-b42f-5ba2-9d9f-72628c3d43e9', 'P0036-062', '14193989-9230-582f-a6d9-722e745aee8f', 62, 103.7, 180.0, 1.700, 1.400, true),
  ('c1d256ec-fc5b-59ee-9891-f1d527f5c53c', 'P0036-063', '14193989-9230-582f-a6d9-722e745aee8f', 63, 105.4, 180.0, 1.700, 1.400, true),
  ('221d5e89-db99-5b49-b8da-a2f6be70b49b', 'P0036-064', '14193989-9230-582f-a6d9-722e745aee8f', 64, 107.1, 180.0, 1.700, 1.400, true),
  ('cc42fd40-1c72-5a6c-b800-264f97c23b23', 'P0036-065', '14193989-9230-582f-a6d9-722e745aee8f', 65, 108.8, 180.0, 1.700, 1.400, true),
  ('7d621ef5-a61e-5f5c-bd70-67accd592c08', 'P0036-066', '14193989-9230-582f-a6d9-722e745aee8f', 66, 110.5, 180.0, 1.700, 1.400, true),
  ('7edfa3e8-fb45-5154-8ebc-5a434118856a', 'P0036-067', '14193989-9230-582f-a6d9-722e745aee8f', 67, 112.2, 180.0, 1.700, 1.400, true),
  ('7f948877-a1d6-532b-8b03-3191c7d337be', 'P0036-068', '14193989-9230-582f-a6d9-722e745aee8f', 68, 113.9, 180.0, 1.700, 1.400, true),
  ('fd02825e-6af1-5170-82be-c766348508ec', 'P0036-069', '14193989-9230-582f-a6d9-722e745aee8f', 69, 115.6, 180.0, 1.700, 1.400, true),
  ('958ad543-0eb0-5702-9149-8f8198e7cf54', 'P0036-070', '14193989-9230-582f-a6d9-722e745aee8f', 70, 117.3, 180.0, 1.700, 1.400, true),
  ('664a7171-35c0-5e96-8683-5fb53f49ee78', 'P0036-071', '14193989-9230-582f-a6d9-722e745aee8f', 71, 119.0, 180.0, 1.700, 1.400, true),
  ('be77e252-4669-587a-bfe5-164d323487ed', 'P0036-072', '14193989-9230-582f-a6d9-722e745aee8f', 72, 120.7, 180.0, 1.700, 1.400, true),
  ('e18c1bc7-ecd0-5bbd-ab6a-7f2a19322396', 'P0036-073', '14193989-9230-582f-a6d9-722e745aee8f', 73, 122.4, 180.0, 1.700, 1.400, true),
  ('cc9b4b96-4579-5f44-b4e9-5e7e629a3032', 'P0036-074', '14193989-9230-582f-a6d9-722e745aee8f', 74, 124.1, 180.0, 1.700, 1.400, true),
  ('fcde1e6d-70be-5e59-9601-ea652dd272f8', 'P0036-075', '14193989-9230-582f-a6d9-722e745aee8f', 75, 125.8, 180.0, 1.700, 1.400, true),
  ('97c273e1-819c-5c79-a4d0-7d7a6f847d27', 'P0036-076', '14193989-9230-582f-a6d9-722e745aee8f', 76, 127.5, 180.0, 1.700, 1.400, true),
  ('641d444a-5c99-5f9e-a2c2-128f0ffc94c1', 'P0036-077', '14193989-9230-582f-a6d9-722e745aee8f', 77, 129.2, 180.0, 1.700, 1.400, true),
  ('86bb9a07-df2d-58c7-ad14-9e2e714a8c48', 'P0036-078', '14193989-9230-582f-a6d9-722e745aee8f', 78, 130.9, 180.0, 1.700, 1.400, true),
  ('13e80476-ae1a-5e2d-b651-349360f32980', 'P0036-079', '14193989-9230-582f-a6d9-722e745aee8f', 79, 132.6, 180.0, 1.700, 1.400, true),
  ('802b049a-bec8-516a-b10c-f8bb9fb8fbe3', 'P0036-080', '14193989-9230-582f-a6d9-722e745aee8f', 80, 134.3, 180.0, 1.700, 1.400, true),
  ('19dd0cee-39d1-567a-a06e-2c17d345a442', 'P0036-081', '14193989-9230-582f-a6d9-722e745aee8f', 81, 136.0, 180.0, 1.700, 1.400, true),
  ('7e3f68dc-4d9f-5ea4-a9f8-61cde21507b8', 'P0036-082', '14193989-9230-582f-a6d9-722e745aee8f', 82, 137.7, 180.0, 1.700, 1.400, true),
  ('b4fdcd3b-ac74-505f-acfa-acb8fecdf010', 'P0036-083', '14193989-9230-582f-a6d9-722e745aee8f', 83, 139.4, 180.0, 1.700, 1.400, true),
  ('aff4a2b9-4c5e-5019-84cd-0869cbfe9ce8', 'P0036-084', '14193989-9230-582f-a6d9-722e745aee8f', 84, 141.1, 180.0, 1.700, 1.400, true),
  ('40677d96-20ef-517b-9546-4a99d91f1c8c', 'P0036-085', '14193989-9230-582f-a6d9-722e745aee8f', 85, 142.8, 180.0, 1.700, 1.400, true),
  ('816c3e65-aa8a-52e5-a882-9e1844c874e0', 'P0036-086', '14193989-9230-582f-a6d9-722e745aee8f', 86, 144.5, 180.0, 1.700, 1.400, true),
  ('d95cc1ff-d08b-593d-9c4c-02bdbbb50997', 'P0036-087', '14193989-9230-582f-a6d9-722e745aee8f', 87, 146.2, 180.0, 1.700, 1.400, true),
  ('c493cad9-486d-5bd5-a018-69f2b24d1dd5', 'P0036-088', '14193989-9230-582f-a6d9-722e745aee8f', 88, 147.9, 180.0, 1.700, 1.400, true),
  ('0dac29a4-5260-57c1-9990-1c0391f19629', 'P0036-089', '14193989-9230-582f-a6d9-722e745aee8f', 89, 149.6, 180.0, 1.700, 1.400, true),
  ('49d0139f-0513-5524-89ea-f2ca7a133711', 'P0036-090', '14193989-9230-582f-a6d9-722e745aee8f', 90, 151.3, 180.0, 1.700, 1.400, true),
  ('1c3deac0-00c5-5542-b6a2-ae99547bfa52', 'P0036-091', '14193989-9230-582f-a6d9-722e745aee8f', 91, 153.0, 180.0, 1.700, 1.400, true),
  ('c38b6607-2c8b-56aa-b549-59f841a9fd09', 'P0036-092', '14193989-9230-582f-a6d9-722e745aee8f', 92, 154.7, 180.0, 1.700, 1.400, true),
  ('a1e382d6-aafb-5989-85d9-73c20d6f0ce4', 'P0036-093', '14193989-9230-582f-a6d9-722e745aee8f', 93, 156.4, 180.0, 1.700, 1.400, true),
  ('5d3666b1-0a13-5ea0-976a-f98f77aeb3d3', 'P0036-094', '14193989-9230-582f-a6d9-722e745aee8f', 94, 158.1, 180.0, 1.700, 1.400, true),
  ('9c55110e-3140-54a6-8fca-9064d2570e51', 'P0036-095', '14193989-9230-582f-a6d9-722e745aee8f', 95, 159.8, 180.0, 1.700, 1.400, true),
  ('d8b2766a-e3bd-5da5-b2e1-3f909e8ace64', 'P0036-096', '14193989-9230-582f-a6d9-722e745aee8f', 96, 161.5, 180.0, 1.700, 1.400, true),
  ('4edfa480-7388-5298-8392-6fb493bdb142', 'P0036-097', '14193989-9230-582f-a6d9-722e745aee8f', 97, 163.2, 180.0, 1.700, 1.400, true),
  ('6b7bc15a-8453-5e5d-a36f-67fb6c0ff135', 'P0036-098', '14193989-9230-582f-a6d9-722e745aee8f', 98, 164.9, 180.0, 1.700, 1.400, true),
  ('7e4d47c3-1669-517b-a995-1e7f95f48710', 'P0036-099', '14193989-9230-582f-a6d9-722e745aee8f', 99, 166.6, 180.0, 1.700, 1.400, true),
  ('5cd79b59-746d-5570-a866-76b8549c157b', 'P0036-100', '14193989-9230-582f-a6d9-722e745aee8f', 100, 168.3, 180.0, 1.700, 1.400, true),
  ('7f353805-04d5-52e0-b733-37bd838eeed7', 'P0036-101', '14193989-9230-582f-a6d9-722e745aee8f', 101, 170.0, 180.0, 1.700, 1.400, true),
  ('fd08f323-6d44-5177-a34e-2c6458d89770', 'P0036-102', '14193989-9230-582f-a6d9-722e745aee8f', 102, 171.7, 180.0, 1.700, 1.400, true),
  ('c55835cb-b49a-56f2-a0b1-b8dc7bc8800e', 'P0036-103', '14193989-9230-582f-a6d9-722e745aee8f', 103, 173.4, 180.0, 1.700, 1.400, true),
  ('770f003b-abeb-5b58-b018-f7e84a0228ca', 'P0036-104', '14193989-9230-582f-a6d9-722e745aee8f', 104, 175.1, 180.0, 1.700, 1.400, true),
  ('702a8746-4fda-56db-bb07-9d515a381099', 'P0036-105', '14193989-9230-582f-a6d9-722e745aee8f', 105, 176.8, 180.0, 1.700, 1.400, true),
  ('03bddfc5-6aa9-5994-ba86-6bcf5c194435', 'P0036-106', '14193989-9230-582f-a6d9-722e745aee8f', 106, 178.5, 180.0, 1.700, 1.400, true),
  ('af45f28a-69e6-55a2-849f-3b2f60865df1', 'P0036-107', '14193989-9230-582f-a6d9-722e745aee8f', 107, 180.2, 180.0, 1.700, 1.400, true),
  ('bf0a09b3-aa78-5a31-8d25-f24d5f8f9d93', 'P0036-108', '14193989-9230-582f-a6d9-722e745aee8f', 108, 181.9, 180.0, 1.700, 1.400, true),
  ('398057b8-647f-5331-918c-11a532963525', 'P0036-109', '14193989-9230-582f-a6d9-722e745aee8f', 109, 183.6, 180.0, 1.700, 1.400, true),
  ('483cbce5-3ead-5bef-9a9f-b33b688f45ab', 'P0036-110', '14193989-9230-582f-a6d9-722e745aee8f', 110, 185.3, 180.0, 1.700, 1.400, true),
  ('0fe21faf-d0d4-5fc5-8f40-0d6077d300f6', 'P0036-111', '14193989-9230-582f-a6d9-722e745aee8f', 111, 187.0, 180.0, 1.700, 1.400, true);


-- --------------------------------------------------------------------------
-- Cap des planches et sens de numerotation
-- Le cap vient du contour releve au GPS. Les parcelles sans cap gardent
-- le sens lu sur la feuille manuscrite, en attendant leur releve.
-- Lauch et Matt restent a null : ni releve, ni sens note sur la feuille.
-- --------------------------------------------------------------------------

update production.parcelle set azimut_planches = 104.9, planche_1_au = 'sud' where code = 'P0011';
update production.parcelle set azimut_planches = 104.8, planche_1_au = 'sud' where code = 'P0013';
update production.parcelle set azimut_planches = 104.6, planche_1_au = 'sud' where code = 'P0015';
update production.parcelle set azimut_planches = 8.1, planche_1_au = 'ouest' where code = 'P0016';
update production.parcelle set azimut_planches = 8.2, planche_1_au = 'ouest' where code = 'P0017';
update production.parcelle set azimut_planches = 8.2, planche_1_au = 'ouest' where code = 'P0018';
update production.parcelle set azimut_planches = 8.2, planche_1_au = 'ouest' where code = 'P0019';
update production.parcelle set azimut_planches = 8.2, planche_1_au = 'ouest' where code = 'P0020';
update production.parcelle set azimut_planches = 8.2, planche_1_au = 'ouest' where code = 'P0021';
update production.parcelle set azimut_planches = 106.6, planche_1_au = 'sud' where code = 'P0022';
update production.parcelle set azimut_planches = 106.0, planche_1_au = 'sud' where code = 'P0023';
update production.parcelle set azimut_planches = 106.0, planche_1_au = 'sud' where code = 'P0024';
update production.parcelle set azimut_planches = 106.2, planche_1_au = 'sud' where code = 'P0025';
update production.parcelle set azimut_planches = 8.5, planche_1_au = 'ouest' where code = 'P0026';

update production.parcelle set planche_1_au = 'ouest' where code = 'P0001';
update production.parcelle set planche_1_au = 'ouest' where code = 'P0005';
update production.parcelle set planche_1_au = 'ouest' where code = 'P0006';
update production.parcelle set planche_1_au = 'ouest' where code = 'P0007';
update production.parcelle set planche_1_au = 'ouest' where code = 'P0008';
update production.parcelle set planche_1_au = 'ouest' where code = 'P0009';
update production.parcelle set planche_1_au = 'ouest' where code = 'P0010';

update production.parcelle set hors_rotation = true where id = 'e1f34840-82d5-5d02-ba10-b57e3dd3b5d6';


-- --------------------------------------------------------------------------
-- Retournement
-- Ces sept parcelles ont leurs planches est-ouest et sont numerotees
-- depuis le nord dans la base. La convention veut la planche 1 au sud.
-- On inverse l'ordre ; les longueurs suivent leur planche, ce qui compte
-- pour F2 dont les 91 planches vont de 104 m a 163 m.
-- A partir d'ici, le numero affiche est celui du terrain.
-- --------------------------------------------------------------------------

--  Bruno Est
update production.unite_culture u set code = u.code || '~'
  from production.parcelle p
 where p.id = u.parcelle_id and p.code = 'P0011';
with ordonne as (
  select u.id, row_number() over (order by u.ordre desc) as rang
    from production.unite_culture u
    join production.parcelle p on p.id = u.parcelle_id
   where p.code = 'P0011')
update production.unite_culture u
   set ordre = o.rang,
       x_debut_m = (o.rang - 1) * 1.700,
       code = 'P0011-' || lpad(o.rang::text, 3, '0')
  from ordonne o where u.id = o.id;

--  Bruno Ouest
update production.unite_culture u set code = u.code || '~'
  from production.parcelle p
 where p.id = u.parcelle_id and p.code = 'P0013';
with ordonne as (
  select u.id, row_number() over (order by u.ordre desc) as rang
    from production.unite_culture u
    join production.parcelle p on p.id = u.parcelle_id
   where p.code = 'P0013')
update production.unite_culture u
   set ordre = o.rang,
       x_debut_m = (o.rang - 1) * 1.700,
       code = 'P0013-' || lpad(o.rang::text, 3, '0')
  from ordonne o where u.id = o.id;

--  Forêt 11
update production.unite_culture u set code = u.code || '~'
  from production.parcelle p
 where p.id = u.parcelle_id and p.code = 'P0015';
with ordonne as (
  select u.id, row_number() over (order by u.ordre desc) as rang
    from production.unite_culture u
    join production.parcelle p on p.id = u.parcelle_id
   where p.code = 'P0015')
update production.unite_culture u
   set ordre = o.rang,
       x_debut_m = (o.rang - 1) * 1.700,
       code = 'P0015-' || lpad(o.rang::text, 3, '0')
  from ordonne o where u.id = o.id;

--  F1
update production.unite_culture u set code = u.code || '~'
  from production.parcelle p
 where p.id = u.parcelle_id and p.code = 'P0022';
with ordonne as (
  select u.id, row_number() over (order by u.ordre desc) as rang
    from production.unite_culture u
    join production.parcelle p on p.id = u.parcelle_id
   where p.code = 'P0022')
update production.unite_culture u
   set ordre = o.rang,
       x_debut_m = (o.rang - 1) * 1.700,
       code = 'P0022-' || lpad(o.rang::text, 3, '0')
  from ordonne o where u.id = o.id;

--  F2
update production.unite_culture u set code = u.code || '~'
  from production.parcelle p
 where p.id = u.parcelle_id and p.code = 'P0023';
with ordonne as (
  select u.id, row_number() over (order by u.ordre desc) as rang
    from production.unite_culture u
    join production.parcelle p on p.id = u.parcelle_id
   where p.code = 'P0023')
update production.unite_culture u
   set ordre = o.rang,
       x_debut_m = (o.rang - 1) * 1.700,
       code = 'P0023-' || lpad(o.rang::text, 3, '0')
  from ordonne o where u.id = o.id;

--  F3
update production.unite_culture u set code = u.code || '~'
  from production.parcelle p
 where p.id = u.parcelle_id and p.code = 'P0024';
with ordonne as (
  select u.id, row_number() over (order by u.ordre desc) as rang
    from production.unite_culture u
    join production.parcelle p on p.id = u.parcelle_id
   where p.code = 'P0024')
update production.unite_culture u
   set ordre = o.rang,
       x_debut_m = (o.rang - 1) * 1.700,
       code = 'P0024-' || lpad(o.rang::text, 3, '0')
  from ordonne o where u.id = o.id;

--  F4
update production.unite_culture u set code = u.code || '~'
  from production.parcelle p
 where p.id = u.parcelle_id and p.code = 'P0025';
with ordonne as (
  select u.id, row_number() over (order by u.ordre desc) as rang
    from production.unite_culture u
    join production.parcelle p on p.id = u.parcelle_id
   where p.code = 'P0025')
update production.unite_culture u
   set ordre = o.rang,
       x_debut_m = (o.rang - 1) * 1.700,
       code = 'P0025-' || lpad(o.rang::text, 3, '0')
  from ordonne o where u.id = o.id;


-- --------------------------------------------------------------------------
-- Controle
-- Echoue si le compte de planches ne tombe pas sur ce qui a ete confirme,
-- ou si une parcelle garde un code de planche provisoire.
-- --------------------------------------------------------------------------

do $$
declare attendu constant jsonb := '{
  "P0001": 12, "P0005": 19, "P0006": 19, "P0007": 19, "P0008": 19,
  "P0009": 19, "P0010": 12, "P0011": 61, "P0013": 61, "P0015": 65,
  "P0016": 5, "P0017": 19, "P0018": 19, "P0019": 19, "P0020": 19,
  "P0021": 19, "P0022": 111, "P0023": 91, "P0024": 91, "P0025": 111,
  "P0026": 38, "P0027": 22, "P0028": 22, "P0029": 50, "P0030": 50,
  "P0031": 64, "P0032": 38, "P0033": 111, "P0034": 91, "P0035": 91,
  "P0036": 111 }'::jsonb;
  ecart text;
begin
  select string_agg(format('%s : %s planches au lieu de %s',
                           p.code, c.n, a.value::int), ', ')
    into ecart
    from jsonb_each(attendu) a
    join production.parcelle p on p.code = a.key
    join lateral (select count(*) n from production.unite_culture u
                   where u.parcelle_id = p.id) c on true
   where c.n <> a.value::int;
  if ecart is not null then
    raise exception 'Parcellaire incoherent -- %', ecart;
  end if;

  if exists (select 1 from production.unite_culture where code like '%~') then
    raise exception 'Des codes de planche provisoires sont restes en place';
  end if;

  if exists (select 1 from production.parcelle p
              where p.planche_1_au is null
                and p.code not in ('P0027','P0028','P0029','P0030',
                                   'P0031','P0032')) then
    raise exception 'Une parcelle n''a pas de sens de numerotation';
  end if;
end $$;

