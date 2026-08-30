#!/usr/bin/env bash
# Rebuild words/answers-N.js and words/valid-N.js
#
#   valid-N  = every N-letter a-z word in dwyl/english-words  (permissive: accepted guesses)
#   answers-N = the most common N-letter words per hackerb9/gwordlist (Google Books
#               frequency, already filtered to dictionary headwords -> no proper nouns
#               or web junk), minus obvious plurals / -ed forms / a slur blocklist,
#               shuffled with a fixed seed, then ROT13'd.
#
# Needs: curl, awk, sort, shuf, tr, paste  (git-bash / coreutils is enough).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p words .cache && cd .cache

[ -f words_alpha.txt ]   || curl -sL -o words_alpha.txt   https://raw.githubusercontent.com/dwyl/english-words/master/words_alpha.txt
[ -f freq_gcide.txt ]    || curl -sL -o freq_gcide.txt    https://raw.githubusercontent.com/hackerb9/gwordlist/master/frequency-alpha-gcide.txt
awk 'NR>1{print $2}' freq_gcide.txt > freq_words.txt

# per-length answer caps (a few years of dailies, kept genuinely common)
declare -A CAP=([5]=900 [6]=750 [7]=550 [8]=400)

cat > mkanswers.awk <<'AWK'
BEGIN{
  split("anal anus arse butt clit cock coon crap cum cunt dick dike dago dyke fag fart feck fuck gook homo jizz kike nazi negro nigger paki piss poop porn pube puss pussy queef rape retard scum semen shit shite slut smegma spic twat wank whore wop damn hell", bad, " ")
  for(i in bad) BAD[bad[i]]=1
}
FILENAME==ARGV[1]{ SHORT[$1]=1; next }          # (N-1)-letter words
FILENAME==ARGV[2]{ VALID[$1]=1; next }          # N-letter valid words
{
  w=$1
  if(length(w)!=N || w !~ /^[a-z]+$/ || !(w in VALID) || (w in BAD) || (w in SEEN)) next
  if(w ~ /s$/ && substr(w,1,length(w)-1) in SHORT) next
  if(w ~ /ed$/ && (substr(w,1,length(w)-1) in SHORT || substr(w,1,length(w)-2) in SHORT)) next
  SEEN[w]=1; print w; if(++c>=LIMIT) exit
}
AWK

for n in 5 6 7 8; do
  p=$((n-1))
  grep -E "^[a-z]{$n}$" words_alpha.txt | sort -u > valid$n.txt
  grep -E "^[a-z]{$p}$" words_alpha.txt | sort -u > valid$p.txt
  awk -v N=$n -v LIMIT=${CAP[$n]} -f mkanswers.awk valid$p.txt valid$n.txt freq_words.txt \
    | shuf --random-source=<(yes "wordle-seed-$n") \
    | tr 'A-Za-z' 'N-ZA-Mn-za-m' > answers$n.txt

  tr 'N-ZA-Mn-za-m' 'A-Za-z' < answers$n.txt > answers$n.plain.txt   # ROT13 back
  ans=$(paste -sd'|' - < answers$n.txt | tr -d '\n')
  val=$(cat valid$n.txt answers$n.plain.txt | sort -u | paste -sd'|' - | tr -d '\n')
  printf 'window.WO_ANSWERS=window.WO_ANSWERS||{};window.WO_ANSWERS[%d]="%s";\n' "$n" "$ans" > ../words/answers-$n.js
  printf 'window.WO_VALID=window.WO_VALID||{};window.WO_VALID[%d]="%s";\n'       "$n" "$val" > ../words/valid-$n.js
  echo "grid $n: $(wc -l < answers$n.txt) answers, $(( $(tr -cd '|' < ../words/valid-$n.js | wc -c) + 1 )) valid guesses"
done
echo "done."
