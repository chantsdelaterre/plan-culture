"""Ecrit la migration 013 : six ans d'assolement releve, 2021 a 2026.

Ce que porte une feuille manuscrite et ce que porte un plan de culture ne sont
pas de meme nature. La feuille dit "Choux Automne, 19 planches" la ou le plan
dit chou rouge 5, blanc 2, milan 6, brocoli 6, avec variete et dates. On ne les
met donc pas dans la meme table : le releve est une SOURCE, au meme titre que
le trace GPS d'un contour. Il se pose a cote du plan, il ne l'ecrase pas.

Ce qu'il porte de sur, et qui suffit a la rotation : une parcelle, une plage de
planches, une famille botanique. La variete, non -- et elle ne change rien au
precedent cultural.

Les numeros de planche sont convertis dans la convention du 20 octobre 2026
(planche 1 au sud ou a l'ouest). Les numeros de la feuille sont conserves a
cote, pour pouvoir revenir au document.
"""
import json, uuid, unicodedata

def pliee(x):
    return ''.join(c for c in unicodedata.normalize('NFD', x or '')
                   if unicodedata.category(c) != 'Mn').lower()

NS = uuid.UUID('6f9619ff-8b86-d011-b42d-00cf4fc964ff')
def ident(*k): return str(uuid.uuid5(NS, '|'.join(map(str, k))))
def q(s): return "'" + str(s).replace("'", "''") + "'"

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

#  Sens canonique et nombre de planches d'aujourd'hui, tels que la migration
#  012 les a poses. None = parcelle ni relevee ni annotee : on garde les
#  numeros de la feuille tels quels et on le signale.
SENS = {'P0001':'ouest','P0005':'ouest','P0006':'ouest','P0007':'ouest',
        'P0008':'ouest','P0009':'ouest','P0015':'sud','P0016':'ouest',
        'P0017':'ouest','P0018':'ouest','P0019':'ouest','P0020':'ouest',
        'P0021':'ouest','P0022':'sud','P0023':'sud','P0024':'sud','P0025':'sud',
        'P0011':'sud','P0013':'sud','P0026':'ouest',
        'P0027':None,'P0028':None,'P0029':None,'P0030':None,
        'P0031':None,'P0032':None,
        'P0033':'sud','P0034':'sud','P0035':'sud','P0036':'sud'}
NB = {'P0001':12,'P0005':19,'P0006':19,'P0007':19,'P0008':19,'P0009':19,
      'P0011':61,'P0013':61,'P0015':65,'P0016':5,'P0017':19,'P0018':19,
      'P0019':19,'P0020':19,'P0021':19,'P0022':111,'P0023':91,'P0024':91,
      'P0025':111,'P0026':38,'P0027':22,'P0028':22,'P0029':50,'P0030':50,
      'P0031':64,'P0032':38,'P0033':111,'P0034':91,'P0035':91,'P0036':111}

#  Bruno Ouest : la feuille le coupe en deux mais numerote 1 a 61 d'un bout a
#  l'autre. C'est l'echelle de l'ilot qu'il faut retourner, pas celle du
#  morceau de feuille.
NB_FEUILLE = {'P0013': 61}

#  F1 et F4 portaient 112 planches jusqu'en 2022 inclus sur la feuille : la
#  planche perdue est celle du sud, c'est-a-dire l'origine du comptage
#  canonique. Tout glisse donc d'un rang.
DECALAGE = {('P0022', 112): -1, ('P0025', 112): -1}

FAM = {'chénopodiacées':'FAM02','composée':'FAM03','convolvulacées':'FAM04',
       'crucifère':'FAM05','cucurbitacée':'FAM06','lilliacée':'FAM07',
       'légumineuse':'FAM08','ombellifère':'FAM09','solanacée':'FAM11',
       'labiée':'FAM12','graminée':'FAM13','rosacée':'FAM14'}

lignes, soucis = [], []
for an in ANS:
    d = json.load(open(f'asso_{an}.json', encoding='utf-8'))
    #  Le rang compte par PARCELLE, pas par bloc de feuille : "Bruno Ouest
    #  180m" et "Bruno Ouest 90m" sont deux morceaux de feuille pour une seule
    #  parcelle, et repartir de 1 sur le second donnait deux lignes de meme
    #  rang -- donc deux fois la meme clef.
    rangs = {}
    for p in d['parcelles']:
        code = CODE[p['nom']]
        sens_c, nb_today = SENS[code], NB[code]
        nf = NB_FEUILLE.get(code) or p['nb'] or nb_today
        dec = DECALAGE.get((code, nf), 0)
        for e in p['e']:
            rang = rangs[code] = rangs.get(code, 0) + 1
            fd, ff = e['d'], e['f']
            if fd is None or ff is None:
                cd = cf = None
            elif sens_c is None or p['ori'] == sens_c:
                cd, cf = int(fd) + dec, int(ff) + dec
            else:                                  # la feuille part de l'autre bout
                cd, cf = nf + 1 - int(ff) + dec, nf + 1 - int(fd) + dec
            #  Une plage qui deborde ne deborde que d'un rang, et toujours du
            #  cote de la planche disparue : elle la couvrait. On rabote, on
            #  ne jette pas -- le reste de la plage est juste.
            rabot = None
            if cd is not None:
                if cd < 1:
                    cd, rabot = 1, 'la plage couvrait aussi la planche disparue au sud'
                if cf > nb_today:
                    cf, rabot = nb_today, 'la plage debordait de la parcelle'
                if not (1 <= cd <= cf <= nb_today):
                    soucis.append(f"{an} {p['nom']} {e['lib'][:28]} -> {cd}-{cf} "
                                  f"hors de 1..{nb_today}")
                    cd = cf = None
            lignes.append(dict(
                id=ident('releve', an, code, rang), an=int(an), code=code, rang=rang,
                cd=cd, cf=cf, ecrit=e['tot'], lib=e['lib'] or '(sans libellé)',
                fam=FAM.get(e['fam']), ev=e['ev'],
                pas=e['fam'] == 'passage',
                sans=pliee(e['lib']).startswith('pas de culture'), f_nom=p['nom'], f_ori=p['ori'],
                f_nb=p['nb'], f_d=fd, f_f=ff,
                note=' · '.join(x for x in (
                    e['source'],
                    'sens de numérotation inconnu' if sens_c is None else None,
                    rabot) if x) or None))

L = []; w = L.append
def titre(t, *c):
    w(""); w("-- " + "-" * 74); w("-- " + t)
    for x in c: w("-- " + x)
    w("-- " + "-" * 74); w("")

w("-- " + "=" * 74)
w("-- Plan de culture maraichere - 013 · Six ans d'assolement releve")
w("-- 2021 a 2026, transcrits des feuilles manuscrites puis verifies au")
w("-- visuel, parcelle par parcelle, avec Coco.")
w("-- " + "=" * 74)

titre("Rejouable",
      "L'editeur SQL de Supabase valide instruction par instruction : une",
      "execution interrompue laisse donc derriere elle ce qu'elle avait deja",
      "fait. On efface avant de reposer, pour que relancer ce fichier donne",
      "toujours le meme resultat.")
w("drop view  if exists production.v_precedent_cultural;")
w("drop table if exists production.assolement_releve;")
w("")

titre("Familles botaniques : menage avant d'y accrocher six ans",
      "L'import FileMaker a laisse 'ombellifere' et 'ombellifère' cote a cote,",
      "et trois familles manquent : labiee, poacee, rosacee.")
w("update production.legume set famille_botanique_id =")
w("  (select id from production.famille_botanique where code = 'FAM09')")
w(" where famille_botanique_id =")
w("  (select id from production.famille_botanique where code = 'FAM10');")
w("delete from production.famille_botanique where code = 'FAM10';")
w("")
w("update production.famille_botanique set nom = 'ombellifère' where code = 'FAM09';")
w("update production.famille_botanique set nom = 'convolvulacées' where code = 'FAM04';")
w("update production.famille_botanique set nom = 'légumineuse' where code = 'FAM08';")
w("")
w("insert into production.famille_botanique (id, code, nom) values")
#  on conflict : si un essai precedent a deja insere ces trois familles,
#  relancer la migration ne doit pas buter dessus.
w(",\n".join(f"  ('{ident('fam', c)}', '{c}', '{n}')"
            for c, n in (('FAM12', 'labiée'), ('FAM13', 'graminée'),
                         ('FAM14', 'rosacée')))
  + "\non conflict (code) do nothing;")
w("")

titre("Le releve d'assolement",
      "Une ligne par entree de feuille. Les numeros de planche sont convertis",
      "dans la convention du 20 octobre 2026 ; ceux de la feuille sont gardes",
      "a cote, pour pouvoir revenir au document et relire l'ecriture.")
w("create table production.assolement_releve (")
w("  id                    uuid primary key default gen_random_uuid(),")
w("  annee                 smallint not null check (annee between 2000 and 2100),")
w("  parcelle_id           uuid not null references production.parcelle (id)")
w("                          on delete cascade,")
w("  rang                  smallint not null check (rang > 0),")
w("  planche_debut         smallint check (planche_debut > 0),")
w("  planche_fin           smallint check (planche_fin > 0),")
w("  nb_planches_ecrit     numeric(6,2) check (nb_planches_ecrit > 0),")
w("  libelle               text not null,")
w("  famille_botanique_id  uuid references production.famille_botanique (id),")
w("  est_engrais_vert      boolean not null default false,")
w("  est_passage           boolean not null default false,")
w("  est_sans_culture      boolean not null default false,")
w("  feuille_nom           text not null,")
w("  feuille_planche_1_au  text not null,")
w("  feuille_nb_planches   smallint,")
w("  feuille_planche_debut smallint,")
w("  feuille_planche_fin   smallint,")
w("  note                  text,")
w("  unique (parcelle_id, annee, rang),")
w("  constraint releve_plage_coherente check (")
w("    (planche_debut is null) = (planche_fin is null)")
w("    and (planche_debut is null or planche_fin >= planche_debut))")
w(");")
w("")
w("create index releve_parcelle_idx on production.assolement_releve")
w("  (parcelle_id, annee);")
w("create index releve_famille_idx on production.assolement_releve")
w("  (famille_botanique_id);")
w("")
for col, txt in [
  ('planche_debut',
   "Premiere planche, dans la convention du 20 octobre 2026 : planche 1 au sud "
   "ou a l''ouest. Null quand la feuille ne donne pas de plage -- les feuilles "
   "LAUCH n''ont pas de planches numerotees."),
  ('nb_planches_ecrit',
   "Le nombre ecrit a la main a cote de l''accolade. Quand il contredit la "
   "plage, c''est lui qui fait foi : l''accolade est posee a vue, le nombre est "
   "compte."),
  ('libelle',
   "Le libelle tel qu''il est ecrit sur la feuille, sans normalisation. C''est "
   "la seule chose dont on soit certain."),
  ('famille_botanique_id',
   "Famille lue dans le libelle. Null pour un engrais vert -- un melange pois, "
   "vesce, ble n''a pas une famille mais deux -- et pour un passage."),
  ('est_sans_culture',
   "La parcelle existait et n''a rien porte cette annee-la. A ne pas confondre "
   "avec l''absence de ligne, qui veut dire qu''on n''a pas le document -- et "
   "avec hors_rotation sur la parcelle, qui veut dire qu''elle ne suit pas "
   "l''assolement du tout."),
  ('feuille_planche_1_au',
   "Le bout d''ou la feuille numerote. Jusqu''en 2026 il change d''une annee a "
   "l''autre sur la meme parcelle : F2 part du nord en 2024, du sud en 2025. "
   "C''est ce qui rend la conversion necessaire, et c''est ce qui permet de la "
   "refaire si on la juge fausse.")]:
    w(f"comment on column production.assolement_releve.{col} is")
    w(f"  '{txt}';"); w("")

w("insert into production.assolement_releve")
w("  (id, annee, parcelle_id, rang, planche_debut, planche_fin,")
w("   nb_planches_ecrit, libelle, famille_botanique_id, est_engrais_vert,")
w("   est_passage, est_sans_culture, feuille_nom, feuille_planche_1_au, feuille_nb_planches,")
w("   feuille_planche_debut, feuille_planche_fin, note) values")
corps = []
for r in lignes:
    fam = (f"(select id from production.famille_botanique where code = '{r['fam']}')"
           if r['fam'] else 'null')
    corps.append(
        f"  ('{r['id']}', {r['an']},"
        f" (select id from production.parcelle where code = '{r['code']}'),"
        f" {r['rang']}, {r['cd'] if r['cd'] else 'null'},"
        f" {r['cf'] if r['cf'] else 'null'},"
        f" {r['ecrit'] if r['ecrit'] else 'null'}, {q(r['lib'])}, {fam},"
        f" {str(r['ev']).lower()}, {str(r['pas']).lower()},"
        f" {str(r['sans']).lower()}, {q(r['f_nom'])},"
        f" {q(r['f_ori'])}, {r['f_nb'] if r['f_nb'] else 'null'},"
        f" {int(r['f_d']) if r['f_d'] else 'null'},"
        f" {int(r['f_f']) if r['f_f'] else 'null'},"
        f" {q(r['note']) if r['note'] else 'null'})")
w(",\n".join(corps) + ";")
w("")

titre("Le precedent cultural, planche par planche",
      "La question que l'appli posera a chaque fois qu'on pose une culture :",
      "qu'est-ce qui est passe sur cette planche, et quand ?",
      "La vue descend le releve au niveau de la planche. Une entree de six",
      "planches en produit six lignes, ce qui rend la question directe.")
w("create view production.v_precedent_cultural as")
w("select r.annee,")
w("       u.parcelle_id,")
w("       u.id   as unite_culture_id,")
w("       u.ordre,")
w("       r.famille_botanique_id,")
w("       f.nom  as famille,")
w("       r.libelle,")
w("       r.est_engrais_vert,")
w("       r.est_passage")
w("  from production.assolement_releve r")
w("  join production.unite_culture u")
w("    on u.parcelle_id = r.parcelle_id")
w("   and u.ordre between r.planche_debut and r.planche_fin")
w("  left join production.famille_botanique f")
w("    on f.id = r.famille_botanique_id;")
w("")
w("comment on view production.v_precedent_cultural is")
w("  'Le releve d''assolement descendu a la planche. Ne porte que le constate, "
  "jamais le prevu : une culture planifiee mais jamais plantee n''y figure pas.';")
w("")

titre("Droits")
w("alter table production.assolement_releve enable row level security;")
w("create policy assolement_releve_lecture on production.assolement_releve")
w("  for select to anon, authenticated using (true);")
w("grant select on production.assolement_releve to anon, authenticated;")
w("grant select on production.v_precedent_cultural to anon, authenticated;")
w("")
w("create trigger assolement_releve_audit")
w("  after insert or update or delete on production.assolement_releve")
w("  for each row execute function production.tracer_historique();")
w("")

titre("Controle")
w("do $$")
w("declare n integer; hors integer;")
w("begin")
w("  select count(*) into n from production.assolement_releve;")
w(f"  if n <> {len(lignes)} then")
w(f"    raise exception 'Releve incomplet : %s lignes au lieu de {len(lignes)}', n;"
  .replace('%s', '%'))
w("  end if;")
w("")
w("  select count(*) into hors")
w("    from production.assolement_releve r")
w("    join production.parcelle p on p.id = r.parcelle_id")
w("   where r.planche_fin is not null")
w("     and r.planche_fin > (select count(*) from production.unite_culture u")
w("                           where u.parcelle_id = p.id);")
w("  if hors > 0 then")
w("    raise exception '% plages de planches sortent de leur parcelle', hors;")
w("  end if;")
w("end $$;")
w("")

vus = {}
for r in lignes:
    if r['id'] in vus:
        raise SystemExit(f"clef en double : {r} et {vus[r['id']]}")
    vus[r['id']] = r

f = '20261020110000_production_assolement_releve.sql'
open(f, 'w', encoding='utf-8').write('\n'.join(L) + '\n')
print(f, '·', len(lignes), 'lignes de releve')
for s in soucis: print('  !', s)
