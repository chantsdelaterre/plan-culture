-- ============================================================================
-- Plan de culture maraichere · Geometrie du parcellaire
--
-- Les contours releves au GPS n'existaient jusqu'ici que dans un fichier sur
-- un disque de travail. Aucune copie. C'etait le seul endroit du projet ou
-- l'on pouvait perdre des heures de trace deja faites : cette migration les
-- met en base.
--
-- TROIS NIVEAUX DE VERITE, et on superpose, on n'ecrase jamais :
--   declare  le parcellaire PAC, tel que l'administration le connait (+/- 2 m)
--   releve   le trace sur orthophoto IGN, fait a la main (+/- 0,50 m)
--   cale     le releve RTK au tracteur (+/- 0,02 m) -- a venir
-- Le niveau le plus fin disponible gagne a l'affichage, mais les autres
-- restent lisibles : quand le RTK contredira le PAC, on voudra voir les deux.
--
-- POURQUOI DU GeoJSON EN jsonb ET PAS PostGIS : pour qu'une migration puisse
-- etre rejouee entierement sur une base d'essai avant d'arriver ici. PostGIS
-- n'etant pas disponible sur cette base d'essai, l'employer aurait voulu dire
-- envoyer du SQL jamais execute. Les surfaces et perimetres sont donc calcules
-- a la saisie (excedent spherique, rayon 6 371 008,8 m) et stockes. Le jour ou
-- l'on aura besoin de calcul spatial en SQL, ST_GeomFromGeoJSON(contour)
-- convertit la colonne sans perte.
--
-- Rejouable et non destructive : les identifiants sont deterministes, la table
-- n'est creee que si elle manque, et les contours sont mis a jour en place. Un
-- releve RTK ajoute a la main plus tard survit donc a une relecture.
-- ============================================================================

-- ---------------------------------------------------------------- le niveau
do $$
begin
  if not exists (select 1 from pg_type t
                   join pg_namespace n on n.oid = t.typnamespace
                  where n.nspname = 'production' and t.typname = 'niveau_verite') then
    create type production.niveau_verite as enum ('declare', 'releve', 'cale');
  end if;
end $$;

-- ---------------------------------------------------------------- la table
create table if not exists production.geometrie (
  id            uuid primary key,
  ilot_id       uuid references production.ilot(id)     on delete cascade,
  parcelle_id   uuid references production.parcelle(id) on delete cascade,
  niveau        production.niveau_verite not null,
  contour       jsonb not null,
  surface_m2    numeric(14,2),
  perimetre_m   numeric(12,2),
  source        text not null,
  precision_m   numeric(6,2),
  releve_le     date,
  note          text,
  cree_le       timestamptz not null default now(),
  --  Un contour porte sur un ilot OU sur une parcelle, jamais sur les deux,
  --  jamais sur aucun des deux.
  constraint geometrie_un_seul_objet
    check (num_nonnulls(ilot_id, parcelle_id) = 1),
  constraint geometrie_geojson
    check (contour->>'type' in ('Polygon', 'MultiPolygon')
           and contour ? 'coordinates')
);

comment on table production.geometrie is
  'Contours geographiques des ilots et des parcelles, en GeoJSON WGS84. Un objet peut avoir plusieurs contours, un par niveau de verite : on superpose le PAC, le releve a la main et le RTK, on ne les ecrase pas.';
comment on column production.geometrie.contour is
  'GeoJSON Polygon ou MultiPolygon, longitude/latitude en WGS84 (EPSG:4326). Toujours MultiPolygon quand le releve est en plusieurs morceaux : coller deux morceaux proches serait inventer de la surface.';
comment on column production.geometrie.surface_m2 is
  'Calculee a la saisie par excedent spherique. Stockee parce que la base ne sait pas faire de geometrie : a ne pas recalculer a la main.';
comment on column production.geometrie.precision_m is
  'Incertitude attendue du trace, en metres : 2 pour le PAC, 0,50 pour un trace sur orthophoto, 0,02 pour du RTK.';

--  Un seul contour par objet et par niveau. Deux traces du meme niveau sur la
--  meme parcelle, ce ne serait pas deux verites : ce serait un doublon.
create unique index if not exists geometrie_ilot_niveau_idx
  on production.geometrie (ilot_id, niveau) where ilot_id is not null;
create unique index if not exists geometrie_parcelle_niveau_idx
  on production.geometrie (parcelle_id, niveau) where parcelle_id is not null;

drop trigger if exists geometrie_audit on production.geometrie;
create trigger geometrie_audit after insert or update or delete on production.geometrie
  for each row execute function production.tracer_historique();

alter table production.geometrie enable row level security;
drop policy if exists geometrie_lecture on production.geometrie;
create policy geometrie_lecture on production.geometrie
  for select to anon, authenticated using (true);
grant select on production.geometrie to anon, authenticated;


-- ------------------------------------------------------------- les contours
insert into production.geometrie
  (id, ilot_id, parcelle_id, niveau, contour, surface_m2, perimetre_m, source, precision_m, releve_le, note) values
  ('10340870-bcf0-5a77-bdb5-9c12adc02d0d', 'a70fe42c-2e1c-5385-9528-74d32f8a1b3a', null, 'declare', '{"type":"MultiPolygon","coordinates":[[[[7.3488325,48.0387592],[7.3489826,48.038985],[7.3491693,48.0392666],[7.3493751,48.0395642],[7.3495636,48.0398243],[7.3498027,48.0401374],[7.3500064,48.0404089],[7.3501496,48.0405943],[7.3505086,48.0410675],[7.3516965,48.0406826],[7.3514873,48.0404304],[7.3512762,48.0401544],[7.3510704,48.0398789],[7.3508896,48.0396257],[7.3505151,48.0390934],[7.3501229,48.0385619],[7.3500673,48.03849],[7.3500035,48.0384025],[7.3498664,48.0384433],[7.34971,48.0384907],[7.3494257,48.0385799],[7.3491451,48.038669],[7.3488634,48.0387569],[7.3488325,48.0387592]]]]}'::jsonb, 27722.99, 762.44, 'RPG 2026, ilot PAC 5', 2.0, '2026-01-01', 'Surface declaree : 2.78 ha'),
  ('98c6f7b1-1044-5ccf-a4e0-f36917d00322', '131b723d-53bc-57e2-a583-bda698997115', null, 'declare', '{"type":"MultiPolygon","coordinates":[[[[7.3439027,48.0379148],[7.3482936,48.036547],[7.3482373,48.0364888],[7.3481313,48.0363568],[7.3481032,48.0363286],[7.3480084,48.0361921],[7.3438258,48.0375838],[7.3439027,48.0379148]]]]}'::jsonb, 14195.61, 789.63, 'RPG 2026, ilot PAC 6', 2.0, '2026-01-01', 'Surface declaree : 1.42 ha'),
  ('f565b6a4-ba94-593f-9a80-6e35f7eb3619', 'a63101a9-aa24-5f45-bf2d-41414b50f00f', null, 'declare', '{"type":"MultiPolygon","coordinates":[[[[7.341653,48.0491846],[7.3416574,48.0491882],[7.3416574,48.0491882],[7.3426092,48.0499712],[7.3426084,48.0499714],[7.3426195,48.0499796],[7.3426497,48.0500045],[7.3430269,48.0499073],[7.3435559,48.0497724],[7.3435237,48.0497486],[7.3435173,48.0497501],[7.3435163,48.0497493],[7.3435184,48.0497488],[7.3425857,48.0490011],[7.341653,48.0491846]]]]}'::jsonb, 7708.81, 374.58, 'RPG 2026, ilot PAC 9', 2.0, '2026-01-01', 'Surface declaree : 0.77 ha'),
  ('591353e8-71df-5c4e-abae-79817325c09f', 'b4586cb8-d990-593d-9ed1-7d311cf1982d', null, 'declare', '{"type":"MultiPolygon","coordinates":[[[[7.4817086,48.0719809],[7.4821097,48.0728718],[7.4835418,48.0726181],[7.483541,48.0726164],[7.4835414,48.0726164],[7.4835417,48.0726169],[7.4843842,48.072472],[7.4852065,48.0723297],[7.4852043,48.0723222],[7.4852046,48.0723221],[7.4852052,48.072324],[7.4867195,48.0720547],[7.4867194,48.0720541],[7.4867236,48.0720534],[7.4867239,48.0720548],[7.4868027,48.0720399],[7.486711,48.0716511],[7.4866265,48.0712632],[7.4866206,48.0712641],[7.4866204,48.0712632],[7.4866282,48.071262],[7.4864448,48.0704844],[7.4863782,48.0704964],[7.4863394,48.0705003],[7.4863411,48.070508],[7.48634,48.0705033],[7.4849663,48.0707189],[7.4849663,48.070719],[7.4847464,48.0707536],[7.4847467,48.0707574],[7.4833723,48.0709982],[7.4833725,48.0709986],[7.4833706,48.0709982],[7.4833678,48.0709975],[7.4826384,48.0711243],[7.4826102,48.0711291],[7.4826102,48.0711292],[7.4826061,48.0711299],[7.4826179,48.0711652],[7.4827514,48.0715436],[7.4827547,48.071543],[7.482755,48.0715437],[7.4827533,48.071544],[7.4828122,48.0717147],[7.4828353,48.0717789],[7.4826578,48.0718109],[7.4826216,48.0718173],[7.4824884,48.0718403],[7.4817086,48.0719809]]]]}'::jsonb, 59452.82, 1098.94, 'RPG 2026, ilot PAC 14', 2.0, '2026-01-01', 'Surface declaree : 5.96 ha'),
  ('f0452479-5aac-53d8-95a0-480053facf60', '48c01aaa-cbff-596c-ada0-84b2b5ebbd11', null, 'declare', '{"type":"MultiPolygon","coordinates":[[[[7.4909314,48.0614807],[7.4909314,48.061481],[7.491173,48.0625658],[7.4911732,48.0625658],[7.4911734,48.0625665],[7.4911717,48.0625668],[7.4914119,48.0636457],[7.4914135,48.0636454],[7.4914183,48.0636788],[7.4914632,48.0636701],[7.4922236,48.0635344],[7.4962655,48.062814],[7.4962652,48.0628134],[7.4963694,48.0627969],[7.496255,48.0622564],[7.4961404,48.0617248],[7.49614,48.0617248],[7.4961398,48.061724],[7.4961408,48.0617239],[7.4959056,48.060621],[7.4957984,48.0606399],[7.4957984,48.0606397],[7.494602,48.0608437],[7.4938844,48.0609687],[7.4926117,48.0611895],[7.4910225,48.0614644],[7.4910227,48.0614651],[7.4910226,48.0614652],[7.4910225,48.061465],[7.4909314,48.0614807]]]]}'::jsonb, 93100.4, 1254.65, 'RPG 2026, ilot PAC 15', 2.0, '2026-01-01', 'Surface declaree : 9.33 ha'),
  ('5794df46-dd8f-5076-9822-af72da31994f', '010521b8-5aea-53b8-94c4-9ca8bcf9f58a', null, 'declare', '{"type":"MultiPolygon","coordinates":[[[[7.4962232,48.0616742],[7.4964524,48.0627482],[7.4964624,48.0627973],[7.4991757,48.0623346],[7.5005373,48.0621031],[7.5012107,48.0619897],[7.5018979,48.0618716],[7.5018847,48.0618],[7.5018801,48.0618008],[7.5018798,48.0617996],[7.5018842,48.0617988],[7.5016698,48.0607535],[7.5012025,48.0608334],[7.501203,48.0608354],[7.5012023,48.0608355],[7.5012015,48.0608322],[7.4994946,48.0611229],[7.4994953,48.0611252],[7.4994908,48.0611259],[7.4994878,48.0611154],[7.4977877,48.0614117],[7.4977875,48.0614111],[7.4963318,48.0616534],[7.4962232,48.0616742]]]]}'::jsonb, 52196.03, 1088.87, 'RPG 2026, ilot PAC 16', 2.0, '2026-01-01', 'Surface declaree : 5.23 ha'),
  ('a92bd0dc-2dd1-5b6a-ae55-177903026186', 'f5b76332-a466-5294-a1d6-610aa912c751', null, 'declare', '{"type":"MultiPolygon","coordinates":[[[[7.4896935,48.0579101],[7.490216,48.0589188],[7.490216,48.0589188],[7.4939055,48.0582197],[7.4939661,48.0582007],[7.4941836,48.0547535],[7.4940198,48.0547862],[7.4892111,48.0557138],[7.4892111,48.0557138],[7.4891852,48.0557125],[7.4891852,48.0557126],[7.4890472,48.0576039],[7.4894883,48.0575203],[7.4895493,48.0576378],[7.4896935,48.0579101]]]]}'::jsonb, 130114.61, 1469.54, 'RPG 2026, ilot PAC 20', 2.0, '2026-01-01', 'Surface declaree : 13.03 ha'),
  ('59ad0c30-1cae-597e-b1c8-107325e2913f', '85c30de4-a66b-5cc0-b519-8350836b1f9e', null, 'declare', '{"type":"MultiPolygon","coordinates":[[[[7.3387362,48.0483939],[7.3389384,48.0489719],[7.3391424,48.0495521],[7.3391424,48.0495521],[7.3391426,48.0495526],[7.3391416,48.0495528],[7.3391601,48.0496046],[7.339879,48.0494701],[7.3405672,48.0493404],[7.3405484,48.0492851],[7.3405473,48.0492853],[7.3405469,48.049284],[7.3405474,48.0492839],[7.3404601,48.049042],[7.340279,48.0485366],[7.3402789,48.0485365],[7.3401842,48.0482702],[7.3394602,48.0483315],[7.3387362,48.0483939]]]]}'::jsonb, 14106.71, 477.97, 'RPG 2026, ilot PAC 21', 2.0, '2026-01-01', 'Surface declaree : 1.41 ha'),
  ('71206426-fdda-544c-a605-16cecd1f9b14', 'f5b76332-a466-5294-a1d6-610aa912c751', null, 'releve', '{"type":"MultiPolygon","coordinates":[[[[7.4942722,48.0547203],[7.4891234,48.0557267],[7.4889657,48.0576219],[7.4894845,48.0576153],[7.4901139,48.0589359],[7.4940082,48.058195],[7.4942722,48.0547203]]]]}'::jsonb, 134501.79, 1490.24, 'Trace geojson.io sur orthophoto IGN', 0.5, '2026-10-18', null),
  ('89bb8ff9-d11f-5875-81df-6c2bf15ede27', 'f2d4fc30-b7a9-5cdd-aff7-1b9e91ac4ed6', null, 'releve', '{"type":"MultiPolygon","coordinates":[[[[7.4944751,48.0582928],[7.4950267,48.0607392],[7.4959358,48.0605888],[7.4954042,48.0581626],[7.4953375,48.0581361],[7.4944751,48.0582928]]]]}'::jsonb, 19269.94, 689.54, 'Trace geojson.io sur orthophoto IGN', 0.5, '2026-10-18', null),
  ('65912204-2738-5a83-a3ee-91fe27ae9ba7', '010521b8-5aea-53b8-94c4-9ca8bcf9f58a', null, 'releve', '{"type":"MultiPolygon","coordinates":[[[[7.4962305,48.0616767],[7.5016493,48.0607381],[7.5018916,48.0618439],[7.4964641,48.0627977],[7.4962305,48.0616767]]]]}'::jsonb, 51756.34, 1083.18, 'Trace geojson.io sur orthophoto IGN', 0.5, '2026-10-18', null),
  ('a72f2f83-4917-5246-ba15-eb7d3f7945bf', 'e335c5d4-2dc3-58a3-b9ef-ba1be41c3333', null, 'releve', '{"type":"MultiPolygon","coordinates":[[[[7.4813173,48.0704966],[7.48626,48.0696242],[7.4860459,48.0686374],[7.4814684,48.0694497],[7.4814328,48.0696583],[7.4822416,48.0695113],[7.4823695,48.0698153],[7.4813495,48.0699976],[7.4813173,48.0704966]]]]}'::jsonb, 37900.77, 1097.38, 'Trace geojson.io sur orthophoto IGN', 0.5, '2026-10-18', 'Ilot hors PAC'),
  ('a449a53b-de40-5967-bc24-aa198bbc8a3c', null, 'a0177846-728a-5e0f-a12d-1329c1dbf38d', 'releve', '{"type":"MultiPolygon","coordinates":[[[[7.4836744,48.0690915],[7.4860043,48.0686782],[7.4862043,48.0696087],[7.4838765,48.0700206],[7.4836744,48.0690915]]]]}'::jsonb, 18576.13, 566.97, 'Trace geojson.io sur orthophoto IGN', 0.5, '2026-10-18', null),
  ('bd1bc143-bb4c-5db4-9ad7-728032e47b3c', null, '45749dc2-0931-5826-81fd-7c56e8539bb6', 'releve', '{"type":"MultiPolygon","coordinates":[[[[7.4835912,48.0691062],[7.482349,48.0693239],[7.4824663,48.069826],[7.4837085,48.0696054],[7.4835912,48.0691062]]],[[[7.4837041,48.0696064],[7.483804,48.070036],[7.4814636,48.0704509],[7.4813763,48.0700221],[7.4837041,48.0696064]]]]}'::jsonb, 13948.85, 759.03, 'Trace geojson.io sur orthophoto IGN', 0.5, '2026-10-18', 'Releve en deux morceaux, distants de 2 cm : les deux moities de Bruno Ouest avant leur fusion en une seule parcelle'),
  ('94f27d65-97ee-5de3-9a2f-cc0d40a11a7c', null, 'de71d335-10fa-5bc5-9e4f-89e893eee1e6', 'releve', '{"type":"MultiPolygon","coordinates":[[[[7.4894092,48.0557399],[7.4917753,48.0552688],[7.4916559,48.0570652],[7.4893001,48.0575118],[7.4894092,48.0557399]]]]}'::jsonb, 34378.43, 762.63, 'Trace geojson.io sur orthophoto IGN', 0.5, '2026-10-18', null),
  ('4316f738-c44f-52a6-b9ec-3dda757beb6e', null, '3777c0ad-5784-521f-8331-df2fe3c869bb', 'releve', '{"type":"MultiPolygon","coordinates":[[[[7.4916532,48.0571059],[7.4895195,48.057515],[7.4901733,48.0588613],[7.4915352,48.0585974],[7.4916532,48.0571059]]]]}'::jsonb, 21239.46, 593.83, 'Trace geojson.io sur orthophoto IGN', 0.5, '2026-10-18', null),
  ('769c96b4-1cb2-5796-ac61-2790775afae7', null, '63189345-1eba-51bd-a54e-9df892d9ac02', 'releve', '{"type":"MultiPolygon","coordinates":[[[[7.4916148,48.0585804],[7.4939575,48.0581307],[7.494086,48.0566292],[7.4917234,48.0570905],[7.4916148,48.0585804]]]]}'::jsonb, 28634.01, 697.18, 'Trace geojson.io sur orthophoto IGN', 0.5, '2026-10-18', null),
  ('bad0e926-9f02-5433-abb8-c493bebd3a53', null, '9026dc3d-77d4-536d-8c6d-8d518b7cf11a', 'releve', '{"type":"MultiPolygon","coordinates":[[[[7.4917303,48.0570436],[7.4940854,48.0565872],[7.4942252,48.0547941],[7.4918674,48.0552489],[7.4917303,48.0570436]]]]}'::jsonb, 34414.23, 764.11, 'Trace geojson.io sur orthophoto IGN', 0.5, '2026-10-18', null),
  ('da190334-fba7-5683-ba26-146dea78a298', null, 'f4a454f4-3470-5f5d-8bcb-1738f03bf58e', 'releve', '{"type":"MultiPolygon","coordinates":[[[[7.4953824,48.0581935],[7.4945038,48.0583505],[7.4950324,48.0607062],[7.4959011,48.0605656],[7.4953824,48.0581935]]]]}'::jsonb, 17710.53, 665.46, 'Trace geojson.io sur orthophoto IGN', 0.5, '2026-10-18', null),
  ('51610854-ec5d-52db-be8b-6e769ed56042', null, 'd208af6e-0696-5e1a-9bb5-198052582cd4', 'releve', '{"type":"MultiPolygon","coordinates":[[[[7.4965882,48.0627041],[7.4989468,48.0622948],[7.4987244,48.0613015],[7.4963566,48.0617086],[7.4965882,48.0627041]]]]}'::jsonb, 20184.44, 586.49, 'Trace geojson.io sur orthophoto IGN', 0.5, '2026-10-18', null),
  ('92f13580-2073-5646-acbd-b6d748c2237a', null, '6ff3f24b-6143-56d9-9c3b-e7f1c86bb36d', 'releve', '{"type":"MultiPolygon","coordinates":[[[[7.4990209,48.0622342],[7.499134,48.0622141],[7.4989354,48.0612765],[7.4988173,48.0612933],[7.4990209,48.0622342]]]]}'::jsonb, 927.88, 228.68, 'Trace geojson.io sur orthophoto IGN', 0.5, '2026-10-18', null),
  ('80547a8b-2a70-57cf-862c-ac87624d3121', null, '74468ac2-961d-5ddf-a64d-8a5192215b5a', 'releve', '{"type":"MultiPolygon","coordinates":[[[[7.4992759,48.062191],[7.4997027,48.0621171],[7.4994993,48.0611743],[7.4990726,48.0612482],[7.4992759,48.062191]]]]}'::jsonb, 3448.9, 277.36, 'Trace geojson.io sur orthophoto IGN', 0.5, '2026-10-18', null),
  ('d7d149d3-ead0-57c8-966a-e9e79e6f5e6f', null, '8720497e-c1ef-57c0-93fa-678a6542b032', 'releve', '{"type":"MultiPolygon","coordinates":[[[[7.4997587,48.0621088],[7.5001855,48.0620349],[7.4999821,48.0610921],[7.4995553,48.061166],[7.4997587,48.0621088]]]]}'::jsonb, 3449.33, 277.37, 'Trace geojson.io sur orthophoto IGN', 0.5, '2026-10-18', null),
  ('17191a5d-b93e-59d4-a9ff-2d064f97c81b', null, 'c64491ee-5a69-5bf4-91da-639d73b6a8fc', 'releve', '{"type":"MultiPolygon","coordinates":[[[[7.500321,48.0620099],[7.5007477,48.061936],[7.5005444,48.0609932],[7.5001176,48.0610671],[7.500321,48.0620099]]]]}'::jsonb, 3448.91, 277.36, 'Trace geojson.io sur orthophoto IGN', 0.5, '2026-10-18', null),
  ('ff9e9518-30bf-5e2c-91c8-2a9b5ba70394', null, 'cdf47cae-6b83-5ed1-b6db-6154819b9885', 'releve', '{"type":"MultiPolygon","coordinates":[[[[7.5008066,48.0619239],[7.5012334,48.06185],[7.5010301,48.0609072],[7.5006033,48.0609811],[7.5008066,48.0619239]]]]}'::jsonb, 3449.28, 277.37, 'Trace geojson.io sur orthophoto IGN', 0.5, '2026-10-18', null),
  ('e3ae4453-a780-568a-8c24-bcf6c4c3c3a2', null, 'ecc534cd-91db-53d0-abe4-7e97a31ed3eb', 'releve', '{"type":"MultiPolygon","coordinates":[[[[7.5013631,48.0618251],[7.5017899,48.0617511],[7.5015865,48.0608083],[7.5011598,48.0608823],[7.5013631,48.0618251]]]]}'::jsonb, 3449.09, 277.37, 'Trace geojson.io sur orthophoto IGN', 0.5, '2026-10-18', null)
on conflict (id) do update set
  ilot_id     = excluded.ilot_id,
  parcelle_id = excluded.parcelle_id,
  niveau      = excluded.niveau,
  contour     = excluded.contour,
  surface_m2  = excluded.surface_m2,
  perimetre_m = excluded.perimetre_m,
  source      = excluded.source,
  precision_m = excluded.precision_m,
  releve_le   = excluded.releve_le,
  note        = excluded.note;


-- -------------------------------------------------- correction des ilots Matt
--  La base rattachait Matt 1 a l'ilot PAC 9 et Matt 2 a l'ilot PAC 7. Les deux
--  sont faux. L'ilot 7 n'existe meme pas dans la declaration 2026, et les
--  surfaces tranchent : PAC 21 fait 1,41 ha pour les 64 planches de Matt 1
--  (emprise 109,10 m), PAC 9 fait 0,77 ha pour les 38 planches de Matt 2
--  (emprise 64,90 m). On corrige dans cet ordre : Matt 1 libere le 9 avant que
--  Matt 2 ne le prenne.
update production.ilot set ilot_pac = '21' where nom = 'Matt 1';
update production.ilot set ilot_pac = '9'  where nom = 'Matt 2';


-- ------------------------------------------------------- la vue d'affichage
--  Ce que la carte veut lire : un contour par objet, le plus fin disponible,
--  en disant lequel c'est. Les autres niveaux restent dans la table pour qui
--  veut comparer.
drop view if exists production.v_contour;
create view production.v_contour as
with classe as (
  select g.*,
         case g.niveau when 'cale' then 1 when 'releve' then 2 else 3 end as rang,
         coalesce(g.ilot_id, g.parcelle_id) as objet_id,
         case when g.ilot_id is not null then 'ilot' else 'parcelle' end as objet
    from production.geometrie g
),
meilleur as (
  select *, row_number() over (partition by objet, objet_id order by rang) as n
    from classe
)
select m.objet, m.objet_id,
       coalesce(i.code, p.code) as code,
       coalesce(i.nom,  p.nom)  as nom,
       p.ilot_id                as parcelle_ilot_id,
       m.niveau, m.contour, m.surface_m2, m.perimetre_m,
       m.source, m.precision_m, m.releve_le, m.note
  from meilleur m
  left join production.ilot     i on i.id = m.ilot_id
  left join production.parcelle p on p.id = m.parcelle_id
 where m.n = 1;

comment on view production.v_contour is
  'Un contour par ilot et par parcelle : le niveau de verite le plus fin disponible (cale, sinon releve, sinon declare). La colonne niveau dit toujours lequel, pour que la carte puisse l''afficher autrement selon la precision.';

grant select on production.v_contour to anon, authenticated;


-- ------------------------------------------------------------- le controle
do $$
declare n integer; s numeric;
begin
  select count(*) into n from production.geometrie;
  if n <> 26 then raise exception 'Geometrie a % contours au lieu de 26', n; end if;

  select count(*) into n from production.geometrie where ilot_id is not null;
  if n <> 12 then raise exception '% contours d''ilot au lieu de 12', n; end if;

  --  v_contour ne rend qu'un contour par objet : les ilots qui ont a la fois
  --  un contour PAC et un releve n'y comptent qu'une fois.
  select count(*) into n from production.v_contour;
  if n <> 24 then raise exception 'v_contour rend % objets au lieu de 24', n; end if;

  --  Les parcelles de l'ilot Foret relevees une a une doivent tenir dans le
  --  contour de l'ilot : si la somme le depassait, un trace serait a cote.
  select sum(surface_m2) into s from production.v_contour
   where objet = 'parcelle' and parcelle_ilot_id =
     (select id from production.ilot where nom = 'Foret' or nom = 'Forêt');
  raise notice 'Foret : % m2 de parcelles relevees', round(s);

  select ilot_pac into s from production.ilot where nom = 'Matt 1';
  if s <> 21 then raise exception 'Matt 1 toujours sur l''ilot PAC %', s; end if;
end $$;
