import json, math, unicodedata

# ---------------------------------------------------------------- sources
PAC2NOM = {14: 'Hangar', 15: 'Robert', 16: 'Forêt', 20: 'Francis',
           5: 'Lauch 1', 6: 'Lauch 2', 21: 'Matt 1', 9: 'Matt 2'}

g = json.load(open('ilots_pac_2026.geojson', encoding='utf-8'))
HP = json.load(open('geo/hors_pac.json', encoding='utf-8'))

#  Contours releves par Coco sur photo aerienne, au bord du cultive. Quand une
#  parcelle en a un, il fait foi : il remplace le pavage calcule. Les ecarts a
#  la theorie sont de l'ordre du demi pour cent, donc on mesure son trait de
#  crayon plus que la parcelle.
TRACES = {
    'Bruno Est': [[7.4836744, 48.0690915], [7.4860043, 48.0686782],
                  [7.4862043, 48.0696087], [7.4838765, 48.0700206]],
    'Bruno S-O': [[7.4835912, 48.0691062], [7.4823490, 48.0693239],
                  [7.4824663, 48.0698260], [7.4837085, 48.0696054]],
    'Bruno N-O': [[7.4837041, 48.0696064], [7.4838040, 48.0700360],
                  [7.4814636, 48.0704509], [7.4813763, 48.0700221]],
    'F1': [[7.4894092, 48.0557399], [7.4917753, 48.0552688],
           [7.4916559, 48.0570652], [7.4893001, 48.0575118]],
    'F2': [[7.4916532, 48.0571059], [7.4895195, 48.0575150],
           [7.4901733, 48.0588613], [7.4915352, 48.0585974]],
    'F3': [[7.4916148, 48.0585804], [7.4939575, 48.0581307],
           [7.4940860, 48.0566292], [7.4917234, 48.0570905]],
    'F4': [[7.4917303, 48.0570436], [7.4940854, 48.0565872],
           [7.4942252, 48.0547941], [7.4918674, 48.0552489]],
    'Etang': [[7.4953824, 48.0581935], [7.4945038, 48.0583505],
              [7.4950324, 48.0607062], [7.4959011, 48.0605656]],
    #  Foret : parcelles 13 a 17 calculees a partir d'un trace de Coco, puis
    #  ajustees par lui. Ecarts mesures entre elles : 10,55 / 4,26 / 10,37 /
    #  4,53 / 9,95 m - l'alternance rangee double / rangee simple.
    '11': [
              [7.4965882, 48.0627041],
              [7.4989468, 48.0622948],
              [7.4987244, 48.0613015],
              [7.4963566, 48.0617086]],
    '12': [
              [7.4990209, 48.0622342],
              [7.4991340, 48.0622141],
              [7.4989354, 48.0612765],
              [7.4988173, 48.0612933]],
    '13': [
              [7.4992759, 48.0621910],
              [7.4997027, 48.0621171],
              [7.4994993, 48.0611743],
              [7.4990726, 48.0612482]],
    '14': [
              [7.4997587, 48.0621088],
              [7.5001855, 48.0620349],
              [7.4999821, 48.0610921],
              [7.4995553, 48.0611660]],
    '15': [
              [7.5003210, 48.0620099],
              [7.5007477, 48.0619360],
              [7.5005444, 48.0609932],
              [7.5001176, 48.0610671]],
    '16': [
              [7.5008066, 48.0619239],
              [7.5012334, 48.0618500],
              [7.5010301, 48.0609072],
              [7.5006033, 48.0609811]],
    '17': [
              [7.5013631, 48.0618251],
              [7.5017899, 48.0617511],
              [7.5015865, 48.0608083],
              [7.5011598, 48.0608823]],
}

#  Contours d'ilot releves par Coco. Ils remplacent le parcellaire PAC, qui ne
#  sert qu'a situer : sur Francis, le releve fait 1348 ares contre 1304 au PAC,
#  l'ecart etant une bande reguliere de 3 m tout autour - le PAC retient la
#  surface admissible, le releve suit le bord reel.
ILOTS_RELEVES = {
    'Francis': [[7.4942722, 48.0547203], [7.4891234, 48.0557267],
                [7.4889657, 48.0576219], [7.4894845, 48.0576153],
                [7.4901139, 48.0589359], [7.4940082, 48.0581950]],
    'Étang': [[7.4944751, 48.0582928], [7.4950267, 48.0607392],
              [7.4959358, 48.0605888], [7.4954042, 48.0581626],
              [7.4953375, 48.0581361]],
    'Forêt': [[7.4962305, 48.0616767], [7.5016493, 48.0607381],
              [7.5018916, 48.0618439], [7.4964641, 48.0627977]],
}

# ---- parcelles FileMaker, par ilot
def lignes(p):
    t = open(p, encoding='utf-8').read().replace('\r\n', '\n').replace('\r', '\n')
    return [l for l in t.split('\n') if l.strip()]

def n(s):
    s = (s or '').replace('\xa0', '').replace(' ', '').strip()
    if s in ('', '?'): return None
    try: return float(s.replace(',', '.'))
    except ValueError: return None

PARC = {}          # nom ilot -> [ {nom, longueur, nb, surface} ]
SURF_FM = {}
courant = None
for l in lignes('fm/5b7d7386-ilots.tab'):
    r = l.split('\t')
    if r[0].strip():
        courant = r[2].strip()
        if courant.lower() == 'francis': courant = 'Francis'
        if courant.lower() == 'etang': courant = 'Étang'
        PARC[courant] = []
        SURF_FM[courant] = n(r[3])
    if len(r) > 8 and r[7].strip():
        PARC[courant].append({'nom': r[7].strip(), 'longueur': n(r[5]),
                              'nb': int(n(r[6]) or 0), 'surface': n(r[8])})

# ---------------------------------------------------------------- projection
anneaux = {}
for f in g['features']:
    num = f['properties']['numero']
    if num not in PAC2NOM: continue
    c = f['geometry']['coordinates']
    while isinstance(c[0][0][0], list): c = c[0]
    anneaux[PAC2NOM[num]] = {'ring': c[0], 'pac': num}
for nom, ring in HP.items():
    anneaux[nom] = {'ring': ring + [ring[0]], 'pac': None}
for nom, ring in ILOTS_RELEVES.items():
    if nom in anneaux:
        anneaux[nom]['ring'] = ring + [ring[0]]
        anneaux[nom]['releve'] = True

tous = [p for a in anneaux.values() for p in a['ring']]
LAT0 = sum(p[1] for p in tous) / len(tous)
LON0 = sum(p[0] for p in tous) / len(tous)
K = 111320.0
KX = K * math.cos(math.radians(LAT0))

def proj(lo, la):                 # metres, x vers l'est, y vers le sud
    return ((lo - LON0) * KX, -(la - LAT0) * K)

def aire(xy):
    a = 0
    for i in range(len(xy) - 1):
        a += xy[i][0] * xy[i + 1][1] - xy[i + 1][0] * xy[i][1]
    return abs(a) / 2

ilots = []
for nom, d in anneaux.items():
    xy = [proj(*p) for p in d['ring']]
    if xy[0] != xy[-1]: xy.append(xy[0])
    # dedoublonne les points repetes
    net = [xy[0]]
    for p in xy[1:]:
        if math.dist(p, net[-1]) > 0.5: net.append(p)
    if math.dist(net[0], net[-1]) > 0.5: net.append(net[0])
    xs = [p[0] for p in net]; ys = [p[1] for p in net]
    ilots.append({
        'nom': nom, 'pac': d['pac'],
        'ring': [[round(x, 1), round(y, 1)] for x, y in net],
        'cx': round(sum(xs[:-1]) / (len(xs) - 1), 1),
        'cy': round(sum(ys[:-1]) / (len(ys) - 1), 1),
        'x0': round(min(xs), 1), 'x1': round(max(xs), 1),
        'y0': round(min(ys), 1), 'y1': round(max(ys), 1),
        'aire': round(aire(net) / 100, 1),
        'fm': SURF_FM.get(nom),
        'parc': [dict(p, trace=[[round(x, 1), round(y, 1)]
                                for x, y in (proj(*q) for q in TRACES[p['nom']])])
                 if p['nom'] in TRACES else p
                 for p in PARC.get(nom, [])],
    })
ilots.sort(key=lambda i: -i['aire'])

json.dump({'ilots': ilots}, open('carte_data.json', 'w', encoding='utf-8'),
          ensure_ascii=False)

tot = sum(i['aire'] for i in ilots)
print(f'{len(ilots)} ilots, {tot:.1f} ares mesures')
for i in ilots:
    e = f"{i['aire'] - i['fm']:+.0f}" if i['fm'] else '   —'
    print(f"  {i['nom']:<9} pac {str(i['pac'] or 'HP'):>2}  "
          f"{i['aire']:7.1f} a  (fm {i['fm'] or 0:7.1f}, {e})  "
          f"{len(i['parc'])} parcelles  "
          f"{i['x1']-i['x0']:5.0f} x {i['y1']-i['y0']:5.0f} m")
print('emprise totale :', round(max(i['x1'] for i in ilots) - min(i['x0'] for i in ilots)),
      'x', round(max(i['y1'] for i in ilots) - min(i['y0'] for i in ilots)), 'm')
