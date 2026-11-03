"""La grille de rotation : une parcelle, six ans empiles, les planches en
abscisse et le meme repere pour toutes les annees.

C'est la lecture verticale qui compte : une coupe a la planche 42 donne les six
precedents culturaux de cette planche, dans l'ordre. Tout le travail de
conversion des numerotations ne sert qu'a ca -- sans lui, la coupe verticale
compare six endroits differents.
"""
import json

ANS = ('2021', '2022', '2023', '2024', '2025', '2026')

CODE = {'1':'P0001','2':'P0005','3':'P0006','4':'P0007','5':'P0008','6':'P0009',
        '11':'P0015','12':'P0016','13':'P0017','14':'P0018','15':'P0019',
        '16':'P0020','17':'P0021','F1':'P0022','F2':'P0023','F3':'P0024','F4':'P0025',
        'Bruno Est 180m':'P0011','Bruno Ouest 180m + 90m':'P0013',
        'Bruno Ouest 180m':'P0013','Bruno Ouest 90m':'P0013',
        'Etang':'P0026','L.2 est':'P0027','L.2 ouest':'P0028',
        'L.1 nord':'P0029','L.1 sud':'P0030','Matt 1':'P0031','Matt 2':'P0032',
        'R1 (nord est)':'P0033','R2 (nord ouest)':'P0034',
        'R3 (sud est)':'P0035','R4 (sud ouest)':'P0036'}
SENS = {**{c:'ouest' for c in ('P0001','P0005','P0006','P0007','P0008','P0009',
                               'P0016','P0017','P0018','P0019','P0020','P0021','P0026')},
        **{c:'sud' for c in ('P0011','P0013','P0015','P0022','P0023','P0024',
                             'P0025','P0033','P0034','P0035','P0036')},
        **{c:None for c in ('P0027','P0028','P0029','P0030','P0031','P0032')}}
NB = {'P0001':12,'P0005':19,'P0006':19,'P0007':19,'P0008':19,'P0009':19,
      'P0011':61,'P0013':61,'P0015':65,'P0016':5,'P0017':19,'P0018':19,
      'P0019':19,'P0020':19,'P0021':19,'P0022':111,'P0023':91,'P0024':91,
      'P0025':111,'P0026':38,'P0027':22,'P0028':22,'P0029':50,'P0030':50,
      'P0031':64,'P0032':38,'P0033':111,'P0034':91,'P0035':91,'P0036':111}
NB_FEUILLE = {'P0013': 61}
DECALAGE = {('P0022',112):-1, ('P0025',112):-1}

ILOT = [('Hangar', ['P0001','P0005','P0006','P0007','P0008','P0009']),
        ('Forêt',  ['P0015','P0016','P0017','P0018','P0019','P0020','P0021']),
        ('Francis',['P0022','P0023','P0024','P0025']),
        ('Bruno',  ['P0011','P0013']),
        ('Robert', ['P0033','P0034','P0035','P0036']),
        ('Étang',  ['P0026']),
        ('Lauch 1',['P0029','P0030']), ('Lauch 2',['P0027','P0028']),
        ('Matt',   ['P0031','P0032'])]
NOM = {'P0001':'1','P0005':'2','P0006':'3','P0007':'4','P0008':'5','P0009':'6',
       'P0015':'11','P0016':'12','P0017':'13','P0018':'14','P0019':'15',
       'P0020':'16','P0021':'17','P0022':'F1','P0023':'F2','P0024':'F3',
       'P0025':'F4','P0011':'Bruno Est','P0013':'Bruno Ouest','P0026':'Étang',
       'P0027':'L.2 est','P0028':'L.2 ouest','P0029':'L.1 nord','P0030':'L.1 sud',
       'P0031':'Matt 1','P0032':'Matt 2','P0033':'R1','P0034':'R2',
       'P0035':'R3','P0036':'R4'}

#  Delai de retour, en annees. Quatre ans partout : la regle appliquee en
#  bio. Elle est dans la base, dans famille_botanique.delai_retour_annees ;
#  cette copie disparaitra quand la page lira Supabase.
RETOUR = {f: 4 for f in ('crucifère', 'chénopodiacées', 'ombellifère',
          'solanacée', 'cucurbitacée', 'lilliacée', 'composée', 'légumineuse',
          'convolvulacées', 'labiée', 'rosacée', 'graminée')}

data = {c: {a: [] for a in ANS} for c in NB}
for an in ANS:
    for p in json.load(open(f'asso_{an}.json', encoding='utf-8'))['parcelles']:
        code = CODE[p['nom']]
        sc, nbt = SENS[code], NB[code]
        nf = NB_FEUILLE.get(code) or p['nb'] or nbt
        dec = DECALAGE.get((code, nf), 0)
        for e in p['e']:
            d, f = e['d'], e['f']
            if d is None or f is None: continue
            if sc is None or p['ori'] == sc: cd, cf = int(d)+dec, int(f)+dec
            else: cd, cf = nf+1-int(f)+dec, nf+1-int(d)+dec
            cd, cf = max(1, cd), min(nbt, cf)
            if cd > cf: continue
            data[code][an].append({'d': cd, 'f': cf, 'l': e['lib'],
                                   'm': e['fam'], 'ev': e['ev']})

teintes = json.load(open('asso_2026.json', encoding='utf-8'))['teintes']
json.dump({'ans': list(ANS), 'ilots': [[n, [[c, NOM[c], NB[c]] for c in cs]]
                                       for n, cs in ILOT],
           'data': data, 'teintes': teintes, 'retour': RETOUR},
          open('rota.json', 'w', encoding='utf-8'), ensure_ascii=False)
print(sum(len(v[a]) for v in data.values() for a in ANS), 'bandes ·',
      sum(NB[c] for _, cs in ILOT for c in cs), 'planches')
