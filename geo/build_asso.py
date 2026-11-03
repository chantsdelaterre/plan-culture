"""Relit la transcription d'un relevé d'assolement et en fait une page de
controle : une bande par parcelle, les planches en abscisse, une couche par
succession. On y compare d'un coup d'oeil la page et la feuille manuscrite.
"""
import json, re, unicodedata, sys

AN = sys.argv[1] if len(sys.argv) > 1 else '2026'

def pliee(s):
    return ''.join(c for c in unicodedata.normalize('NFD', s or '')
                   if unicodedata.category(c) != 'Mn').lower()

def nb(s):
    s = (s or '').strip().replace(',', '.')
    try: return float(s)
    except ValueError: return None

#  Familles botaniques, par mots-cles. C'est MA lecture du libelle, pas celle
#  du transcripteur : ce qui ne tombe dans aucune case ressort en gris et dans
#  la liste a trancher.
FAM = [
 ('engrais vert',   ('engrais vert', 'e.v', 'ev')),
 ('légumineuse',    ('haricot', 'petit pois', 'mangetout', 'pois', 'luzerne', 'feverole',
                     'legumineuse', 'borlotto', 'bolotto', 'vesce', 'ppmt')),
 ('crucifère',      ('crucif', 'chou', 'navet', 'radis', 'pak choi', 'pakcho', 'roquette',
                     'cresson', 'colza', 'moutarde', 'brocoli', 'romanesco',
                     'rutabaga', 'oster')),
 ('ombellifère',    ('ombellifere', 'carotte', 'panais', 'persil', 'coriandre', 'aneth',
                     'celeri', 'fenouil', 'ombellifere')),
 ('chénopodiacées', ('blette', 'bett', 'epinard', 'betterave', 'choggia', 'poiree', 'cheno')),
 ('lilliacée',      ('oignon', 'ail', 'echalot', 'poireau', 'ciboul')),
 ('cucurbitacée',   ('cucurbitace', 'courge', 'potimarron', 'butternut', 'pasteque', 'concombre',
                     'melon', 'kuri', 'spaghetti', 'sweet')),
 ('composée',       ('salade', 'scarole', 'pain de sucre', 'pissenlit', 'topi',
                     'laitue', 'chicoree', 'endive')),
 ('solanacée',      ('p. de t', 'pdt', 'pomme de terre', 'poivron', 'tomate',
                     'tom', 'aubergine', 'piment')),
 ('convolvulacées', ('patate',)),
 ('labiée',         ('basilic', 'menthe', 'thym', 'sauge', 'romarin')),
 ('rosacée',        ('fraise', 'framboise')),
 ('graminée',         ('ble', 'lolium', 'ray-grass', 'raygrass', 'seigle',
                     'avoine', 'orge', 'triticale', 'mais')),
]
def famille(lib):
    p = pliee(lib)
    if 'passage' in p: return 'passage'
    for f, mots in FAM:
        if any(m in p for m in mots): return f
    return None

TEINTES = {'légumineuse': 'sauge', 'crucifère': 'violet', 'ombellifère': 'amber',
           'chénopodiacées': 'brique', 'lilliacée': 'bleu', 'cucurbitacée': 'olive',
           'composée': 'teal', 'solanacée': 'rose', 'convolvulacées': 'prune',
           'labiée': 'teal2', 'rosacée': 'rose2', 'graminée': 'paille', 'engrais vert': 'sauge2', None: 'ardoise', 'passage': 'sable'}

# ------------------------------------------------------------------ lecture
parcelles, cur = [], None
for l in open(f'asso/{AN}.txt', encoding='utf-8'):
    c = [x.strip() for x in l.rstrip().split(';')]
    #  Un en-tete fait trois champs et ne commence pas par une annee. Le nombre
    #  de planches peut valoir "?" : sur les feuilles LAUCH il n'y en a pas.
    if len(c) == 3:            # un en-tete a 3 champs, une entree en a 6
        cur = {'nom': c[0], 'nb': int(c[1]) if c[1].isdigit() else None,
               'ori': c[2], 'e': []}
        parcelles.append(cur); continue
    if len(c) >= 6 and cur is not None:
        d, f = nb(c[2]), nb(c[3])
        ec = c[4].strip()
        tot = sum(nb(x) or 0 for x in ec.split('/')) if '/' in ec else nb(ec)
        span = None if (d is None or f is None) else f - d + 1
        fam = famille(c[5])
        #  La luzerne est une legumineuse, mais elle est semee pour trois ou
        #  quatre ans comme tete de rotation : elle ne doit pas declencher
        #  l'alerte de retour, elle EST la coupure.
        ev = fam == 'engrais vert' or 'luzerne' in pliee(c[5])
        cur['e'].append({'d': d, 'f': f, 'span': span, 'ecrit': ec, 'ev': ev,
                         'source': (c[6].strip() if len(c) >= 7 and c[6].strip()
                                    else None),
                         'tot': tot, 'lib': c[5], 'fam': fam,
                         #  Une demi-planche n'est pas une faute : c'est une
                         #  planche partagee entre deux cultures. Seul un ecart
                         #  d'une planche entiere ou plus merite un controle.
                         'ecart': None if (tot is None or span is None)
                                  else (0 if abs(span - tot) < 1
                                        else round(span - tot, 2))})

#  Couches : deux entrees qui se chevauchent sont des successions, on les
#  empile. L'ordre dans le fichier est celui de la feuille, on le garde.
for p in parcelles:
    couches = []
    for e in p['e']:
        if e['d'] is None:          # entree sans plage : sa propre couche, a part
            e['c'] = -1; continue
        for k, c in enumerate(couches):
            if all(e['d'] > q['f'] or e['f'] < q['d'] for q in c):
                c.append(e); e['c'] = k; break
        else:
            e['c'] = len(couches); couches.append([e])
    k = len(couches)
    for e in p['e']:
        if e['c'] == -1: e['c'] = k; k += 1    # une couche chacune, sinon elles se recouvrent
    p['nc'] = max(1, k)
    #  Une plage qui sort des bornes de la parcelle signale une numerotation
    #  continue a l'echelle de l'ilot, pas de la parcelle.
    p['hors'] = bool(p['nb']) and any(
        e['f'] is not None and e['f'] > p['nb'] for e in p['e'])

#  L'accolade : sur la feuille, une bande est parfois detaillee en varietes
#  juste en dessous, sans que la famille soit reecrite. On ne remonte donc que
#  vers le HAUT, et on s'arrete a la premiere ligne qui convient - deux
#  cultures qui se succedent sur la meme parcelle s'englobent sans etre une
#  accolade l'une de l'autre, et les lignes de F4 2023 le prouvent.
for p in parcelles:
    for i, e in enumerate(p['e']):
        if e['fam'] is not None: continue
        for q in reversed(p['e'][:i]):
            if q['fam'] in (None, 'passage') or q['d'] is None: continue
            if e['d'] is None:                      # ligne sans plage : la bande du dessus
                e['fam'] = q['fam']; e['herite'] = True; break
            if q['d'] <= e['d'] and e['f'] <= q['f'] and q['span'] > e['span']:
                e['fam'] = q['fam']; e['herite'] = True; break

inconnus = sorted({e['lib'] for p in parcelles for e in p['e'] if e['fam'] is None})
ecarts = [(p['nom'], e) for p in parcelles for e in p['e']
          if e['ecart'] not in (None, 0)]

json.dump({'an': AN, 'parcelles': parcelles, 'teintes': TEINTES,
           'inconnus': inconnus},
          open(f'asso_{AN}.json', 'w', encoding='utf-8'), ensure_ascii=False)

print(f"{len(parcelles)} parcelles · {sum(len(p['e']) for p in parcelles)} entrées "
      f"· {sum(p['nc'] for p in parcelles)} couches")
print(f"{len(ecarts)} écarts de décompte · {len(inconnus)} libellés sans famille")
for x in inconnus: print('   sans famille :', x)
