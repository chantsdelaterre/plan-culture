/*  Session et accès à la base, partagés par tous les écrans.
 *
 *  Pas de bibliothèque extérieure. Le module qui porte l'authentification est
 *  celui dont tout le reste dépend : une version de CDN qui bouge ou qui
 *  disparaît couperait l'appli entière. L'API d'authentification de Supabase
 *  tient en trois appels, autant les écrire.
 *
 *  Lire ne demande pas de compte : les politiques de lecture sont ouvertes,
 *  et une page doit pouvoir s'afficher sur un téléphone dans un champ sans
 *  qu'on ait à taper un mot de passe. C'est ÉCRIRE qui demande d'être connu.
 */
(function (racine) {
'use strict';

const URL_SB = 'https://oldkmapumqnibdcniecd.supabase.co';
const CLE = 'sb_publishable_sMySTPpkgaiUtnban8uCtw_HQFxmsgv';
const BOITE = 'cdt.session';

//  localStorage peut jeter - navigation privee, stockage bloque, quota plein.
//  Dans ce cas la session ne vit que le temps de l'onglet, ce qui est genant
//  mais pas bloquant : on ne doit jamais tomber pour autant.
const boite = {
  lis()   { try { return JSON.parse(localStorage.getItem(BOITE)); }
            catch (e) { return memoire; } },
  ecris(v){ memoire = v;
            try { v ? localStorage.setItem(BOITE, JSON.stringify(v))
                    : localStorage.removeItem(BOITE); } catch (e) {} },
};
let memoire = null;
let enCours = null;   //  un seul rafraichissement a la fois, meme si dix
                      //  requetes partent ensemble au chargement d'une page

async function jetonBrut(corps, parametre) {
  const r = await fetch(`${URL_SB}/auth/v1/token?grant_type=${parametre}`, {
    method: 'POST',
    headers: {apikey: CLE, 'Content-Type': 'application/json'},
    body: JSON.stringify(corps),
  });
  const d = await r.json().catch(() => ({}));
  if (!r.ok) throw Object.assign(new Error(d.msg || d.error_description
    || 'Connexion refusée'), {code: r.status, brut: d.error_code});
  //  expires_at manque sur certaines reponses : on le recalcule.
  return {jeton: d.access_token, renouveau: d.refresh_token,
          expire: d.expires_at || Math.floor(Date.now() / 1000) + (d.expires_in || 3600),
          email: d.user && d.user.email, uid: d.user && d.user.id};
}

const Session = {
  compte() { const s = boite.lis(); return s && s.email ? s : null; },

  async connexion(email, motDePasse) {
    const s = await jetonBrut({email: String(email).trim(), password: motDePasse},
                              'password');
    boite.ecris(s);
    return s;
  },

  deconnexion() {
    const s = boite.lis();
    //  On prévient le serveur sans l'attendre : si l'appel échoue, la session
    //  locale est effacée quand même. Rester connecté par accident serait pire.
    if (s) fetch(`${URL_SB}/auth/v1/logout`, {method: 'POST',
      headers: {apikey: CLE, Authorization: 'Bearer ' + s.jeton}}).catch(() => {});
    boite.ecris(null);
  },

  /*  Rend un jeton valable, ou null si personne n'est connecté. Rafraîchit
   *  une minute avant l'échéance : un jeton qui expire pendant le vol d'une
   *  requête donnerait un 401 incompréhensible à l'utilisateur. */
  async jeton() {
    let s = boite.lis();
    if (!s) return null;
    if (s.expire - 60 > Date.now() / 1000) return s.jeton;
    if (!enCours) enCours = jetonBrut({refresh_token: s.renouveau}, 'refresh_token')
      .then(n => { boite.ecris(n); return n.jeton; })
      .catch(() => { boite.ecris(null); return null; })   // renouveau périmé : on redemande le mot de passe
      .finally(() => { enCours = null; });
    return enCours;
  },
};

/*  Un appel à la base. Avec une session, il part sous l'identité de la
 *  personne ; sans session, sous l'identité anonyme, qui ne sait que lire. */
async function pg(chemin, options) {
  const o = options || {};
  const jeton = await Session.jeton();
  const entetes = {
    apikey: CLE,
    Authorization: 'Bearer ' + (jeton || CLE),
    'Accept-Profile': 'production',
  };
  if (o.corps !== undefined) {
    entetes['Content-Type'] = 'application/json';
    entetes['Content-Profile'] = 'production';
    //  representation : on veut relire ce que la base a vraiment écrit, et
    //  non ce qu'on croit lui avoir envoyé.
    entetes.Prefer = o.prefer || 'return=representation';
  }
  const r = await fetch(`${URL_SB}/rest/v1/${chemin}`,
    {method: o.methode || (o.corps !== undefined ? 'POST' : 'GET'), headers: entetes,
     body: o.corps !== undefined ? JSON.stringify(o.corps) : undefined});
  if (!r.ok) {
    const t = await r.text();
    let m = t;
    try { const d = JSON.parse(t); m = d.message || d.hint || d.details || t; } catch (e) {}
    //  Un 401 ou un 403 sur une écriture, c'est presque toujours la session,
    //  pas la donnée. On le dit en clair plutôt que de rendre le code brut.
    if ((r.status === 401 || r.status === 403) && o.corps !== undefined)
      m = Session.compte() ? 'Ta session n’a pas le droit d’écrire ici. ' + m
                           : 'Il faut être connecté pour enregistrer.';
    throw Object.assign(new Error(m), {code: r.status});
  }
  return r.status === 204 ? null : r.json();
}

// ------------------------------------------------------- le coin connexion
const STYLE = `
.cx{margin-left:auto;display:flex;gap:8px;align-items:center;font-size:13px}
.cx button{font:500 12px/1 'Barlow Condensed',sans-serif;letter-spacing:.1em;
  text-transform:uppercase;padding:7px 12px;border-radius:7px;cursor:pointer;
  border:1px solid var(--trait);background:var(--surface);color:var(--encre)}
.cx button:hover{background:var(--surface-2)}
.cx .qui{color:var(--encre-2);font-size:12.5px}
dialog.cnx{border:1px solid var(--trait);border-radius:12px;padding:0;
  background:var(--surface);color:var(--encre);width:min(360px,calc(100vw - 32px));
  box-shadow:0 18px 50px rgba(0,0,0,.22)}
dialog.cnx::backdrop{background:rgba(10,14,13,.46)}
dialog.cnx h3{margin:0;padding:15px 18px;border-bottom:1px solid var(--trait);
  font:600 17px Barlow,sans-serif}
dialog.cnx form{padding:16px 18px 18px;margin:0}
dialog.cnx label{display:block;font:500 11px/1 'Barlow Condensed',sans-serif;
  letter-spacing:.14em;text-transform:uppercase;color:var(--encre-2);margin:0 0 5px}
dialog.cnx input{width:100%;padding:9px 11px;margin:0 0 13px;border-radius:7px;
  border:1px solid var(--trait);background:var(--papier);color:var(--encre);
  font:400 15px Barlow,sans-serif}
dialog.cnx input:focus{outline:2px solid var(--vert);outline-offset:1px}
dialog.cnx .rangee{display:flex;gap:9px;align-items:center;margin-top:4px}
dialog.cnx .rangee button{font:500 13px/1 Barlow,sans-serif;padding:10px 15px;
  border-radius:7px;cursor:pointer;border:1px solid var(--trait);
  background:var(--surface);color:var(--encre)}
dialog.cnx .rangee button[value=ok]{background:var(--vert);border-color:var(--vert);
  color:#fff;font-weight:600}
dialog.cnx .mot{color:var(--alerte);font-size:13px;margin:0 0 11px;display:none}
dialog.cnx .mot.on{display:block}
`;

function coinConnexion(hote) {
  if (!document.getElementById('cx-style')) {
    const s = document.createElement('style');
    s.id = 'cx-style'; s.textContent = STYLE;
    document.head.appendChild(s);
  }
  const coin = document.createElement('span');
  coin.className = 'cx';
  hote.appendChild(coin);

  const d = document.createElement('dialog');
  d.className = 'cnx';
  d.innerHTML = `<h3>Se connecter</h3><form method="dialog">
    <p class="mot" id="cx-mot"></p>
    <label for="cx-m">Adresse mail</label>
    <input id="cx-m" type="email" autocomplete="username" required>
    <label for="cx-p">Mot de passe</label>
    <input id="cx-p" type="password" autocomplete="current-password" required>
    <div class="rangee"><button value="ok" id="cx-ok">Connexion</button>
      <button value="non" type="button" id="cx-non">Annuler</button></div>
  </form>`;
  document.body.appendChild(d);
  const mot = d.querySelector('#cx-mot');
  d.querySelector('#cx-non').onclick = () => d.close();

  d.querySelector('form').addEventListener('submit', async ev => {
    ev.preventDefault();
    const b = d.querySelector('#cx-ok');
    b.disabled = true; b.textContent = 'Un instant…'; mot.className = 'mot';
    try {
      await Session.connexion(d.querySelector('#cx-m').value,
                              d.querySelector('#cx-p').value);
      d.close();
      //  On recharge : chaque écran décide à son chargement ce qu'il montre
      //  selon la session, plutôt que d'avoir à tout remettre à jour ici.
      location.reload();
    } catch (e) {
      mot.textContent = e.brut === 'invalid_credentials'
        ? 'Adresse ou mot de passe incorrect.'
        : (e.message || 'La connexion a échoué.');
      mot.className = 'mot on';
      d.querySelector('#cx-p').select();
    } finally { b.disabled = false; b.textContent = 'Connexion'; }
  });

  function peins() {
    const c = Session.compte();
    coin.innerHTML = '';
    if (c) {
      const q = document.createElement('span');
      q.className = 'qui'; q.textContent = c.email;
      const b = document.createElement('button');
      b.textContent = 'Déconnexion';
      b.onclick = () => { Session.deconnexion(); location.reload(); };
      coin.append(q, b);
    } else {
      const b = document.createElement('button');
      b.textContent = 'Se connecter';
      b.onclick = () => { mot.className = 'mot'; d.showModal();
                          d.querySelector('#cx-m').focus(); };
      coin.appendChild(b);
    }
  }
  peins();
}

racine.CDT = {Session, pg, coinConnexion, URL_SB, CLE};
})(window);
