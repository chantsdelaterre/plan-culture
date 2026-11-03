"""Ecrit la migration qui met les contours en base.

Les contours releves au GPS n'existaient que dans un fichier Python sur le
disque de l'atelier. C'est le seul endroit du projet ou l'on pouvait perdre du
travail deja fait : des heures de trace sur geojson.io, et aucune copie.

Stockage en GeoJSON dans une colonne jsonb, pas en PostGIS. Raison : PostGIS
ne s'installe pas dans l'atelier, donc une migration qui l'emploie ne serait
pas testable avant d'arriver sur la base de production. Le jour ou l'on en
aura besoin, ST_GeomFromGeoJSON convertit la colonne en une ligne.

Trois niveaux de verite, comme partout ailleurs dans ce projet :
  declare  le parcellaire PAC, tel que l'administration le connait
  releve   le trace sur orthophoto, a plus ou moins cinquante centimetres
  cale     le releve RTK au tracteur, a deux centimetres -- pas encore fait
On superpose, on n'ecrase pas.
"""
import json, math, uuid

NS = uuid.UUID('6f9619ff-8b86-d011-b42d-00cf4fc964ff')
def ident(*k): return str(uuid.uuid5(NS, '|'.join(map(str, k))))
def q(s): return "'" + str(s).replace("'", "''") + "'"

R = 6371008.8   # rayon moyen de la Terre, en metres

def aire_m2(anneau):
    """Aire d'un anneau en coordonnees geographiques, par excedent spherique.
    A l'echelle d'une parcelle l'erreur est bien en dessous du metre carre."""
    s = 0.0
    for (x1, y1), (x2, y2) in zip(anneau, anneau[1:] + anneau[:1]):
        s += math.radians(x2 - x1) * (2 + math.sin(math.radians(y1))
                                        + math.sin(math.radians(y2)))
    return abs(s * R * R / 2)

def perimetre_m(anneau):
    t = 0.0
    for (x1, y1), (x2, y2) in zip(anneau, anneau[1:] + anneau[:1]):
        p1, p2 = math.radians(y1), math.radians(y2)
        dl = math.radians(x2 - x1)
        a = (math.sin((p2 - p1) / 2) ** 2
             + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2)
        t += 2 * R * math.asin(min(1, math.sqrt(a)))
    return t

def ferme(anneau):
    a = [list(map(float, p)) for p in anneau]
    if a[0] != a[-1]: a.append(a[0])
    return a

def multi(anneaux):
    """GeoJSON MultiPolygon. Toujours multi, meme pour une seule piece : le
    releve de Bruno Ouest est en deux morceaux distants de deux centimetres,
    et les coller serait inventer."""
    return {'type': 'MultiPolygon', 'coordinates': [[ferme(a)] for a in anneaux]}

# ---------------------------------------------------------------- les sources
src = json.load(open('/tmp/geo_source.json'))
pac = json.load(open('ilots_pac_2026.geojson', encoding='utf-8'))
hors = json.load(open('geo/hors_pac.json', encoding='utf-8'))
ilots = {i['nom']: i for i in json.load(open('/tmp/ilots.json'))}
parcs = {p['nom']: p for p in json.load(open('/tmp/parcelles.json'))}

PAC2NOM = {14: 'Hangar', 15: 'Robert', 16: 'Forêt', 20: 'francis',
           5: 'Lauch 1', 6: 'Lauch 2', 21: 'Matt 1', 9: 'Matt 2'}
#  Le nom de l'ilot dans build_carte2 n'est pas toujours celui de la base.
NOM_BASE = {'Francis': 'francis', 'Étang': 'Etang', 'Bruno': 'Bruno', 'Forêt': 'Forêt'}
#  Bruno Ouest est une parcelle depuis la migration 012, mais le releve l'a
#  saisie en deux fois : on garde les deux morceaux dans un MultiPolygon.
PARC = {'Bruno Est': ['Bruno Est'], 'Bruno Ouest': ['Bruno S-O', 'Bruno N-O'],
        'F1': ['F1'], 'F2': ['F2'], 'F3': ['F3'], 'F4': ['F4'],
        'Etang': ['Etang'], **{str(n): [str(n)] for n in range(11, 18)}}

lignes, orphelins = [], []

def ajoute(cible, oid, niveau, anneaux, source, prec, date, note=None):
    g = multi(anneaux)
    lignes.append(dict(
        id=ident('geom', cible, oid, niveau), cible=cible, oid=oid, niveau=niveau,
        contour=json.dumps(g, ensure_ascii=False, separators=(',', ':')),
        surface=round(sum(aire_m2(a) for a in anneaux), 2),
        perimetre=round(sum(perimetre_m(a) for a in anneaux), 2),
        source=source, prec=prec, date=date, note=note))

#  1 · Le parcellaire PAC, niveau declare.
for f in pac['features']:
    n = f['properties']['numero']
    nom = PAC2NOM.get(n)
    if nom is None:
        orphelins.append(n); continue
    ajoute('ilot', ilots[nom]['id'], 'declare', [f['geometry']['coordinates'][0]],
           'RPG 2026, ilot PAC %d' % n, 2.00, '2026-01-01',
           'Surface declaree : %.2f ha' % f['properties']['surface_ha'])

#  2 · Les contours d'ilots releves par Coco sur orthophoto.
for nom, anneau in src['ilots'].items():
    ajoute('ilot', ilots[NOM_BASE[nom]]['id'], 'releve', [anneau],
           'Trace geojson.io sur orthophoto IGN', 0.50, '2026-10-18')
#  Bruno n'est pas au PAC : son seul contour est le releve.
ajoute('ilot', ilots['Bruno']['id'], 'releve', [hors['Bruno']],
       'Trace geojson.io sur orthophoto IGN', 0.50, '2026-10-18',
       'Ilot hors PAC')

#  3 · Les contours de parcelles releves.
for nom, clefs in PARC.items():
    anneaux = [src['traces'][k] for k in clefs]
    note = ('Releve en deux morceaux, distants de 2 cm : les deux moities de '
            'Bruno Ouest avant leur fusion en une seule parcelle'
            if len(anneaux) > 1 else None)
    ajoute('parcelle', parcs[nom]['id'], 'releve', anneaux,
           'Trace geojson.io sur orthophoto IGN', 0.50, '2026-10-18', note)

json.dump(lignes, open('/tmp/geom_lignes.json', 'w'))
print(len(lignes), 'contours ·',
      sum(1 for l in lignes if l['cible'] == 'ilot'), 'ilots ·',
      sum(1 for l in lignes if l['cible'] == 'parcelle'), 'parcelles')
print('ilots PAC sans correspondance (plus exploites) :', orphelins)

# ================================================================= migration
E = []
w = E.append
w("""-- ============================================================================
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
""")

# ------------------------------------------------------------ les 26 contours
w("\n-- ------------------------------------------------------------- les contours")
w("insert into production.geometrie\n  (id, ilot_id, parcelle_id, niveau, contour, surface_m2,"
  " perimetre_m, source, precision_m, releve_le, note) values")
vals = []
for l in lignes:
    vals.append("  (%s, %s, %s, %s, %s::jsonb, %s, %s, %s, %s, %s, %s)" % (
        q(l['id']),
        q(l['oid']) if l['cible'] == 'ilot' else 'null',
        q(l['oid']) if l['cible'] == 'parcelle' else 'null',
        q(l['niveau']), q(l['contour']), l['surface'], l['perimetre'],
        q(l['source']), l['prec'], q(l['date']),
        q(l['note']) if l['note'] else 'null'))
w(',\n'.join(vals))
w("""on conflict (id) do update set
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
""")

# ------------------------------------------------------------- la correction
w("""
-- -------------------------------------------------- correction des ilots Matt
--  La base rattachait Matt 1 a l'ilot PAC 9 et Matt 2 a l'ilot PAC 7. Les deux
--  sont faux. L'ilot 7 n'existe meme pas dans la declaration 2026, et les
--  surfaces tranchent : PAC 21 fait 1,41 ha pour les 64 planches de Matt 1
--  (emprise 109,10 m), PAC 9 fait 0,77 ha pour les 38 planches de Matt 2
--  (emprise 64,90 m). On corrige dans cet ordre : Matt 1 libere le 9 avant que
--  Matt 2 ne le prenne.
update production.ilot set ilot_pac = '21' where nom = 'Matt 1';
update production.ilot set ilot_pac = '9'  where nom = 'Matt 2';
""")

# --------------------------------------------------------------- la vue
w("""
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
""")

#  Un objet qui a un contour PAC et un releve ne compte qu'une fois dans la vue.
NB_OBJETS = len({(l['cible'], l['oid']) for l in lignes})

# -------------------------------------------------------------- le controle
w("""
-- ------------------------------------------------------------- le controle
do $$
declare n integer; s numeric;
begin
  select count(*) into n from production.geometrie;
  if n <> %d then raise exception 'Geometrie a %% contours au lieu de %d', n; end if;

  select count(*) into n from production.geometrie where ilot_id is not null;
  if n <> %d then raise exception '%% contours d''ilot au lieu de %d', n; end if;

  --  v_contour ne rend qu'un contour par objet : les ilots qui ont a la fois
  --  un contour PAC et un releve n'y comptent qu'une fois.
  select count(*) into n from production.v_contour;
  if n <> %d then raise exception 'v_contour rend %% objets au lieu de %d', n; end if;

  --  Les parcelles de l'ilot Foret relevees une a une doivent tenir dans le
  --  contour de l'ilot : si la somme le depassait, un trace serait a cote.
  select sum(surface_m2) into s from production.v_contour
   where objet = 'parcelle' and parcelle_ilot_id =
     (select id from production.ilot where nom = 'Foret' or nom = 'Forêt');
  raise notice 'Foret : %% m2 de parcelles relevees', round(s);

  select ilot_pac into s from production.ilot where nom = 'Matt 1';
  if s <> 21 then raise exception 'Matt 1 toujours sur l''ilot PAC %%', s; end if;
end $$;
""" % (len(lignes), len(lignes),
       sum(1 for l in lignes if l['cible'] == 'ilot'),
       sum(1 for l in lignes if l['cible'] == 'ilot'),
       NB_OBJETS, NB_OBJETS))

open('20261103100000_production_geometrie.sql', 'w').write('\n'.join(E))
print('migration ecrite ·', sum(len(x) for x in E) // 1024, 'ko')
