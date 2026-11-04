#!/usr/bin/env bash
# Rejoue toutes les migrations sur une base neuve, puis verifie les garde-fous.
#   outils/tester.sh      (PGHOST/PGPORT/PGUSER du PostgreSQL local)
set -euo pipefail
cd "$(dirname "$0")/.."
: "${PGHOST:=/tmp}" "${PGPORT:=5433}" "${PGUSER:=postgres}"
export PGHOST PGPORT PGUSER
base=plan_culture_test
url="postgresql:///$base?host=$PGHOST&port=$PGPORT&user=$PGUSER"
journal=$(mktemp); trap 'rm -f "$journal"' EXIT

echo "1. Base neuve"
dropdb --if-exists "$base"; createdb "$base"
psql "$url" -X -q -v ON_ERROR_STOP=1 -f outils/banc-test/supabase-minimal.sql

echo "2. Analyse"
outils/appliquer.sh analyser "$url" | tail -3

echo "3. Refus sans validation quand une migration l'exige"
if outils/appliquer.sh appliquer "$url" >/dev/null 2>&1; then
  echo "   ECHEC : applique sans validation"; exit 1; fi
echo "   ok"

echo "4. Application complete, avec validation"
#  On garde la sortie : si une migration casse, c'est son message qu'on veut
#  voir, pas un code de retour muet.
if ! outils/appliquer.sh appliquer "$url" --avec-validation > "$journal" 2>&1; then
  echo "   ECHEC :"; grep -E "^::error" "$journal" | head -2 | sed 's/^/     /'; exit 1; fi
if grep -qE "^::error" "$journal"; then
  echo "   ECHEC :"; grep -E "^::error" "$journal" | head -2 | sed 's/^/     /'; exit 1; fi
echo "   ok"

echo "5. Rejeu : plus rien a faire"
n=$(outils/appliquer.sh analyser "$url" | grep -c '^  - ' || true)
[ "$n" = 0 ] || { echo "   ECHEC : rejeu non idempotent ($n restantes)"; exit 1; }
echo "   ok"

echo "6. La base reconstruite retrouve les comptes attendus"
psql "$url" -X -At -v ON_ERROR_STOP=1 -c "
do \$\$
declare p int; r int; g int;
begin
  select count(*) into p from production.parcelle;
  select count(*) into r from production.assolement_releve;
  select count(*) into g from production.geometrie;
  if p <> 31 then raise exception 'parcelles : % au lieu de 31', p; end if;
  if r <> 521 then raise exception 'releves : % au lieu de 521', r; end if;
  if g <> 26 then raise exception 'contours : % au lieu de 26', g; end if;
end \$\$;"
echo "   ok · 31 parcelles, 521 releves, 26 contours"

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cp -r migrations outils "$tmp/"

echo "7. Une migration « production » qui vise la paie echoue"
printf -- '-- portee: production\nupdate public.paie_leurre set montant = 0;\n' > "$tmp/migrations/9999_mauvaise.sql"
if "$tmp/outils/appliquer.sh" appliquer "$url" >/dev/null 2>&1; then
  echo "   ECHEC : la migration a pu toucher public"; exit 1; fi
echo "   ok (refusee par les droits, pas par une promesse)"

echo "8. drop passe en validation"
printf -- '-- portee: production\ndrop table if exists production.inexistante;\n' > "$tmp/migrations/9999_mauvaise.sql"
"$tmp/outils/appliquer.sh" analyser "$url" | grep -q '9999_mauvaise.sql (validation)' || {
  echo "   ECHEC : drop non detecte"; exit 1; }
echo "   ok"

echo "9. delete dans un corps de fonction : automatique ; hors corps : validation"
printf -- '-- portee: production\ncreate function production.t_ok() returns void language sql as $$ delete from production.historique where false $$;\n' > "$tmp/migrations/9999_mauvaise.sql"
"$tmp/outils/appliquer.sh" analyser "$url" | grep -q '9999_mauvaise.sql (production)' || {
  echo "   ECHEC : delete en corps de fonction mal classe"; exit 1; }
printf -- '-- portee: production\ndelete from production.affectation;\n' > "$tmp/migrations/9999_mauvaise.sql"
"$tmp/outils/appliquer.sh" analyser "$url" | grep -q '9999_mauvaise.sql (validation)' || {
  echo "   ECHEC : delete hors fonction non detecte"; exit 1; }
echo "   ok"

echo "10. Une migration sans en-tete passe en validation"
printf -- 'create table production.sans_entete(id int);\n' > "$tmp/migrations/9999_mauvaise.sql"
"$tmp/outils/appliquer.sh" analyser "$url" | grep -q '9999_mauvaise.sql (validation)' || {
  echo "   ECHEC : en-tete manquant non detecte"; exit 1; }
echo "   ok"

echo "11. Une meta-commande psql est refusee"
printf -- '-- portee: validation\n\\! env\n' > "$tmp/migrations/9999_mauvaise.sql"
if "$tmp/outils/appliquer.sh" analyser "$url" >/dev/null 2>&1; then
  echo "   ECHEC : meta-commande acceptee"; exit 1; fi
echo "   ok"

echo
echo "Tous les tests sont passes."
