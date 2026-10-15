# Journal de suivi — YELE

*(Mis à jour après chaque échange, conformément à PROMPT_GUIDE.md)*

## État du projet
- 4 dépôts analysés (extraits dans `../TEST/`) : `mobilefront` (Flutter), `mobiletest` (Go + MongoDB), `New_web` (dashboard HTML/JS), `AI_yele` (FastAPI, importé aussi ici).
- Cahier des charges lu : `../../.freebuff/TEST/Pronblème_constate.xlsx` → 20 points : 13 Issues + 7 Améliorations (P1×5, P2×10, P3×5).

## ✅ Fait
- Import du commit AI_yele `61f8777` dans le dossier courant (16 fichiers, syntaxe validée).
- Lecture du fichier « Problèmes constatés » (2 feuilles).
- Analyse code des 4 dépôts : causes racines identifiées pour chaque point du cahier des charges (voir synthèse du 08/09/2026).

## 🔍 Découvertes clés
- ISS-07 (720p) et ISS-10 (GPS bloquant) : **déjà corrigés dans le code actuel** — le rapport porte sur une version déployée antérieure (à re-vérifier sur device).
- ISS-12 : confirmé, `map.js` ne crée aucun marqueur au « Localisez-moi ».
- ISS-13 : les items Réglages (langue, unité…) sont de simples `_item()` non cliquables ; seul le toggle GPS change, sans persistance.
- ISS-03 : l'application distingue désormais le réseau réellement mesuré (Wi-Fi ou cellulaire) des informations de la SIM ; l'historique web affiche `/` dans « Réseau mobile » pour les mesures Wi-Fi.
- ISS-02 : la SIM data active est résolue via `SubscriptionManager` ; l'utilisateur confirme que le cas de double SIM est résolu.
- ISS-04 : aucun « Ouagadougou » dans le code ; libellé issu de la config du backend déployé (app codée en dur sur `Render.com`).
- ISS-09 : la mesure est envoyée à l'affichage du bilan, avant la réponse au questionnaire QoE ; le dashboard se rafraîchit automatiquement et son cache est limité.

**Note statut** : les constats et vagues ci-dessous ont été rédigés au début du suivi ; les correctifs ultérieurs sont consignés dans les entrées datées plus bas.

## 📋 Backlog initial restant (à re-trier)
1. Quick wins : ISS-11, ISS-12, ISS-13/IMP-02, IMP-04.
2. Mesure : ISS-01 (RSRP/RSRQ), ISS-06 (min/moy/max), IMP-01.
3. Scoring : IMP-05 + IMP-06 (échelle + seuils ARCEP), ISS-08 (durées).
4. Backend/déploiement : ISS-04, ISS-05 (protocole comparatif). IMP-03 (comptes) en dernier.

## 🤔 Décisions en attente
- Sur quel dépôt travailler : copies `../TEST/*-main` extraites des zip vs clones GitHub frais.
- Quel groupe de correctifs lancer en premier.

## 📌 Décisions du 08/09/2026
- **Module IA non prioritaire** (demande explicite) : `AI_yele` gelé, fin de backlog.
- Réponses en **anglais** à la demande de l'utilisateur (code et journal restent en français).

## 🚀 Campagne déploiement — avancement du 10/09/2026

Liste des 10 actions (image WhatsApp) et statut réel :

| # | Action | Statut | Détail |
|---|---|---|---|
| 1 | Installer le backend Go (mobiletest) | ✅ FAIT | Go 1.27 (winget), `speedtest.exe` compilé, tourne sur :8989. Endpoints moteur testés OK : /getIP, /garbage, /empty, /results/telemetry. |
| 2 | Configurer MongoDB Atlas | ⏳ BLOQUÉ utilisateur | Aucun compte Atlas existant. Guide 6 étapes fourni. Sans lui : pas d'API dashboard (vérifié : `Dashboard requires database_type=mongodb`). |
| 3 | Déployer le dashboard web (New_web) | ⏳ En attente | Site statique ; `config.js` pointe déjà vers `mobiletest-j0c6.onrender.com`. Choix : local / Netlify / GitHub Pages / Render static. |
| 4 | Déployer le service IA (AI_yele) | ⏸️ GELÉ | Décision utilisateur : non prioritaire. |
| 5 | Installer l'app mobile (22 appareils) | 🔄 EN COURS | Flutter 3.47.3 + JDK 17 (Adoptium) + Android SDK 36 installés, `flutter doctor` tout vert, licences acceptées. Reste : `pub get` → `build apk --debug` → distribution ADB/APK. |
| 6 | Tests connectivité backend ↔ mobile | ⏳ | Après APK (ou via curl dès qu'Atlas branché). |
| 7 | Tests connectivité backend ↔ dashboard | ⏳ | Bloqué par Atlas (agrégations MongoDB). |
| 8 | Tests connectivité backend ↔ service IA | ⏸️ GELÉ | Avec l'IA. |
| 9 | Vérification permissions mobile | ⏳ | Analyse manifest possible dès maintenant ; tests réels sur device. |
| 10 | Tests de base (1 mesure par type) | ⏳ | Après APK + Atlas. |

**Environnement machine** : RAM 7,3 Go (peu !) → `~/.gradle/gradle.properties` force `-Xmx2048m` (sans toucher au dépôt, priorité utilisateur). Disque C: 390 Go libres. Réponse en anglais conservée ; guide PROMPT_GUIDE.md toujours suivi (journal vivant).

## 🚀 Avancement du 12/09/2026 — mise en route locale

| Étape | Statut | Preuve |
|---|---|---|
| Backend Go + **MongoDB Atlas** | ✅ FAIT | Log : `Connected to MongoDB Atlas, database: yele_speedtest`. Écoute `0.0.0.0:8989` (donc joignable depuis le LAN). |
| API dashboard | ✅ FAIT | `GET /api/dashboard/summary` → `{"totalTests":0,...}` (JSON valide, base vide). 7 endpoints exposés : summary, results, operators, map, timeline, heatmap, stats/advanced. |
| APK pointant sur le backend local | ✅ FAIT | `flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.100.148:8989` → APK 187 Mo, build 329 s. |

### 🔑 Pièges rencontrés et résolus
- **Mot de passe Atlas avec `@`** : dans une URI Mongo, `@` doit être encodé `%40`, sinon le driver coupe le mot de passe avant le `@` et l'authentification échoue. Chaîne utilisée : `mongodb+srv://yele_app:P%40ssw0rd@cluster0.32b2pnv.mongodb.net/`.
- **Secret hors dépôt** : la chaîne de connexion n'est jamais écrite dans un fichier du dépôt ; elle est passée via `SPEEDTEST_DATABASE_CONNECTION_STRING` (supporté nativement par `config/config.go`).
- **URL du backend sans recompiler le code** : `config.dart` utilise désormais `String.fromEnvironment('API_BASE_URL', defaultValue: <production>)`. Le défaut production est intact ; le local passe par `--dart-define`.
- **HTTP en clair autorisé** : `AndroidManifest.xml` contient déjà `android:usesCleartextTraffic="true"` — indispensable car Android bloque le HTTP non chiffré depuis API 28.
- **Build détaché obligatoire** : le timeout du terminal tue le groupe de processus. Solution fiable sous Git Bash (pas de `setsid`) : `powershell -NoProfile -Command 'Start-Process -FileNath cmd.exe ... -WindowStyle Hidden'`.

## 🚀 Avancement du 16/09/2026 — test local prêt

| Élément | Statut | Preuve |
|---|---|---|
| Backend Go + Atlas relancé | ✅ | Log : `Connected to MongoDB Atlas, database: yele_speedtest`, `Starting backend server on :8989` |
| API moteur (download/upload/IP) | ✅ | `/getIP` 200, `/garbage?ckSize=1` → 1 048 576 octets en 1,3 ms, `/api/dashboard/summary` → JSON valide |
| APK « LAN » | ✅ | `app-debug-lan.apk` (187 Mo) → `API_BASE_URL=http://192.168.100.148:8989` (Wi-Fi, exige la règle pare-feu) |
| APK « localhost » | ✅ | `app-debug.apk` (122 Mo, arm64) → `API_BASE_URL=http://127.0.0.1:8989` (USB via `adb reverse`, **sans droits admin**) |

### 🔑 Découverte : contourner le pare-feu sans élévation
`adb reverse tcp:8989 tcp:8989` fait écouter le port 8989 de la machine **sur le téléphone** : le trafic passe par le câble USB, donc aucune règle de pare-feu entrante n'est nécessaire. C'est la voie retenue pour les tests locaux, l'élévation ayant été refusée.

### 🔎 Audit permissions Android (action 9)
- Déclarées (manifest) : INTERNET, ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE, ACCESS_FINE/COARSE_LOCATION, READ_PHONE_STATE, FOREGROUND_SERVICE(+_LOCATION), POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED.
- Demandées à l'exécution : READ_PHONE_STATE et POST_NOTIFICATIONS (MainActivity.kt), position via `geolocator` (`location_service.dart`).
- Consentement explicite avant la collecte en arrière-plan + notification permanente avec action d'arrêt : présents.
- Limite connue et gérée : sur Android 14+, un service `location` ne peut pas démarrer depuis l'arrière-plan au boot → échec absorbé dans `BootReceiver.kt`.
- **Manque réel** : exemption d'optimisation de la batterie (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` / `isIgnoringBatteryOptimizations`) — sans elle, la collecte passive peut être tuée par le Doze sur plusieurs heures.
- Chaîne `'battery'` dans `config.dart` définie mais **jamais utilisée** → reste d'un écran de permissions jamais construit (IMP-04).

### ⛔ Blocage en cours : pare-feu Windows
- Profil réseau actif = **Public**, stratégie **BlockInbound, AllowOutbound**.
- Les règles existantes pour `speedtest.exe` sont en **Action : Bloquer** (TCP et UDP, profil Public).
- Conséquence : un téléphone du même Wi-Fi **ne peut pas** joindre `http://192.168.100.148:8989`.
- L'élévation pour ajouter la règle d'autorisation TCP 8989 a été **refusée** par l'utilisateur → trois voies possibles (voir échange).
- IP LAN de la machine : **192.168.100.148**. Aucun appareil connecté en ADB pour l'instant.

## ⛔ 24/09/2026 — Atlas injoignable : port 27017 filtré par le réseau

Configuration Atlas **vérifiée et correcte** (captures utilisateur) : utilisateur `yele_app` (SCRAM, `readWriteAnyDatabase@admin`), IP Access List `0.0.0.0/0` active, Cluster0 (AWS eu-west-3, tier Free, v8.0.32). Mot de passe régénéré et fourni.

**Échec constaté** au lancement (`./speedtest.exe -c settings-local.toml` avec `SPEEDTEST_DATABASE_CONNECTION_STRING`) :

```
level=fatal msg="MongoDB ping failed: server selection error: context deadline exceeded,
current topology: { Type: ReplicaSetNoPrimary, Servers: [{ Addr: ac-poe9qoi-shard-00-00.32b2pnv.mongodb.net:27017,
Last error: dial tcp 65.62.27.88:27017: i/o timeout }, ...] }"
```

**Diagnostic** — ce n'est ni le mot de passe, ni la whitelist, ni le pare-feu local :

| Test | Résultat | Conclusion |
|---|---|---|
| DNS des shards | `65.62.27.88` résolu | ✅ OK |
| ICMP (ping) vers le shard | `True` | ✅ hôte joignable |
| TCP **27017** (3 shards) | `False` | ⛔ **paquet filtré** |
| TCP 80 / 443 / 22 | `True` | ✅ sortie Internet OK |
| Pare-feu Windows (profil Public) | `BlockInbound,AllowOutbound`, aucune règle sortante sur 27017 | ✅ hors de cause |
| Backend Render (443) | `{"totalTests":750,"avgDownload":40.83,...}` | ✅ prod + Atlas fonctionnels |

Le port 27017 sortant est donc **bloqué en amont** (FAI/routeur — filtrage courant contre les attaques de ransom sur MongoDB). Les sessions des 12/09 et 16/09 passaient : le réseau a changé depuis.

### ✅ Résolu — 24/09 (changement de réseau)
Après changement de réseau (nouvelle IP publique `154.66.165.3`, machine `10.160.191.11`), le TCP 27017 passe : **la cause était bien le filtrage du port par le réseau précédent**.

| Élément | Statut |
|---|---|
| Connexion Atlas | ✅ `Connected to MongoDB Atlas, database: yele_speedtest` |
| Backend local | ✅ PID 13376, écoute `0.0.0.0:8989`, `/api/dashboard/summary` → `{"totalTests":0,...}` |
| Dashboard local | ✅ `python -m http.server 5500` (PID 7312), `config.js` basculé sur `http://localhost:8989` |
| App mobile | ❌ en attente — l'appareil n'est plus sur le réseau de la machine (`10.160.191.11` vs `192.168.100.93`) |

**Voie retenue par l'utilisateur pour rebrancher l'appareil** : Wi-Fi + « Débogage sans fil » (même réseau que la machine), puis `adb connect` → `install -r` APK release → `adb reverse tcp:8989 tcp:8989`. Le tunnel reste la clé : il évite toute règle de pare-feu entrante. Rappel : le port de connexion ADB change à chaque réactivation du débogage sans fil (mDNS `adb mdns services` ou scan pour le retrouver).

⚠️ `New_web-main/config.js` a été passé en `http://localhost:8989` **pour le test local uniquement** : à remettre sur l'URL de production avant tout commit/déploiement du dashboard.

### 🔓 Voies de déblocage (archive)
1. Tester sur un autre réseau (partage de connexion du téléphone) — confirme le blocage FAI en 30 s.
2. **MongoDB Community en local** (`mongod` sur `127.0.0.1:27017`) → pile 100 % locale, indépendante du FAI.
3. Utiliser le **backend Render** déjà déployé (défaut de `config.dart` et `config.js`) — opérationnel immédiatement.
4. Tunnel SSH/SOCKS pour faire passer 27017 sur 443 (nécessite un VPS).

## 📄 24/09/2026 — checklist « faire tourner YELE en local »

Aucune modification de code : simple état des lieux de ce qui est nécessaire pour lancer la pile en local au vu de l'existant.

| Bloc | Prérequis | Statut |
|---|---|---|
| 1. Backend Go | Chaîne MongoDB Atlas via `SPEEDTEST_DATABASE_CONNECTION_STRING` + `speedtest.exe -c settings-local.toml` | ✅ prêt (binaire du 10/09, config OK) — rien à recompiler |
| 2. Dashboard web | `config.js` reste sur Render → à basculer sur `http://localhost:8989` + `python -m http.server 5500` | ⚠️ 1 ligne à changer |
| 3. App mobile | APK arm64-v8a release (18 Mo) + `adb reverse tcp:8989 tcp:8989` | ✅ prêt (validé le 19/09) |
| 4. Service IA | `ai_service_url` vide → `/api/ai/*` désactivé | ⏸️ non requis (gelé) |

**Contraintes rappelées** : `adb`, `flutter` et `java` ne sont **pas** sur le PATH bash (chemins complets : `C:\Users\USER\android-sdk\platform-tools\adb.exe`, `C:\Users\USER\flutter-sdk\flutter\bin\flutter.bat`, `C:\Users\USER\jdk17`) ; `go` et `python` y sont. Le port ADB sans fil change après chaque réactivation du débogage → rescanner (`.freebuff/scan_adb.py`). Aucune règle de pare-feu n'est nécessaire tant que l'on passe par `adb reverse` ; l'APK « LAN » (187 Mo) reste le seul cas où une règle entrante serait requise.

## 🚀 Avancement du 19/09/2026 — installation sur téléphone (action 5, 1er appareil)

| Étape | Statut | Preuve |
|---|---|---|
| Appairage ADB sans fil | ✅ | `adb pair 192.168.100.93:33147 371156` → `Successfully paired [guid=adb-110142304006105-nJDwZi]` |
| Découverte du port de connexion | ✅ | Le port fourni (33147) est le **port de pairing**, fermé après appairage. Scan complet des 65535 ports → **41989** ouvert. `adb connect 192.168.100.93:41989` → `connected` |
| Périphérique cible | ✅ | `M5` / `M5_EEA_4G`, Android **12** (SDK 31), ABI **arm64-v8a** |
| Installation APK | ✅ | `app-arm64-v8a-release.apk` (18 Mo, `API_BASE_URL=http://127.0.0.1:8989`) → `Performing Streamed Install / Success`. Aucune version YELE préinstallée. |
| Permissions runtime | ✅ | Accordées via `pm grant` : READ_PHONE_STATE, ACCESS_FINE/COARSE_LOCATION. (`POST_NOTIFICATIONS` inexistante sur Android 12 → ignorée par l'OS.) |
| Tunnel sans pare-feu | ✅ | `adb reverse tcp:8989 tcp:8989` (fonctionne en ADB **sans fil**, pas seulement USB). Vérifié : `netstat` côté téléphone montre des connexions `127.0.0.1:…→127.0.0.1:8989` en TIME_WAIT, `nc` renvoie EXIT=0. |
| Backend local | ✅ | `speedtest.exe` relancé (PID 4968) avec `SPEEDTEST_DATABASE_CONNECTION_STRING` → `Connected to MongoDB Atlas` + `Starting backend server on :8989`. `/api/dashboard/summary` répond en JSON. |
| App lancée | ✅ | Process vivant (PID 24440), **aucun** FATAL/AndroidRuntime dans logcat. |

### 🔑 Découvertes de la session
- **Le téléphone n'a pas d'affichage capturable** : `screencap` renvoie une image 720×1600 **entièrement noire**, y compris pour l'écran Réglages système (test de contrôle). Ce n'est donc **pas** un bug de l'app YELE — c'est une limite de l'appareil M5 (type routeur/MiFi 4G sans écran exploitable). Toute vérification d'UI doit passer par la logique (logcat, netstat, `dumpsys`), pas par capture d'écran.
- **Piège Git Bash** : les chemins `/sdcard/...` sont réécrits en chemins Windows ; utiliser `MSYS_NO_PATHCONV=1` avant les commandes `adb shell screencap/pull`.
- Le port de connexion ADB change si le « Débogage sans fil » est désactivé/réactivé → rescanner (script `.freebuff/scan_adb.py`).

### ⏭️ Suite
- Installer sur les appareils restants (même recette : pair → scan port → connect → `install -r` → `reverse`).
- Ne pas oublier : le `adb reverse` doit être rejoué à chaque reconnexion ADB ; sinon, préférer un APK compilé avec `--dart-define=API_BASE_URL=http://<IP_LAN>:8989` **et** une règle pare-feu entrante (élévation requise).

## 🚀 26/09/2026 — nouvel appareil appairé (action 5, 2e appareil)

Appairage fourni par l'utilisateur : `code 391269` + `192.168.100.152:46833`.

| Étape | Statut | Preuve |
|---|---|---|
| Appairage ADB sans fil | ✅ | `adb pair 192.168.100.152:46833 391269` → `Successfully paired [guid=adb-STAR1202209061382-BCkL9y]` |
| Découverte du port de connexion | ✅ | `adb mdns services` annonce `_adb-tls-connect._tcp` ; le port mDNS (.12:40629) était refusé → `adb connect 192.168.100.152:40629` → `connected` |
| Périphérique cible | ✅ | `STAR 1` / **Hicel**, Android **12** (SDK 31), ABI **arm64-v8a** (≠ M5 précédent) |
| IP machine | ℹ️ | **192.168.100.149** (même /24 que le téléphone .152) |
| Installation APK | ✅ | `app-arm64-v8a-release.apk` (18 Mo, `API_BASE_URL=http://127.0.0.1:8989`) → `Performing Streamed Install / Success` |
| Permissions runtime | ✅ | `pm grant` READ_PHONE_STATE, ACCESS_FINE/COARSE_LOCATION sur `com.yele.mobilefront` |
| Tunnel sans pare-feu | ✅ | `adb reverse tcp:8989 tcp:8989` → `host-33 tcp:8989 tcp:8989` |
| Backend local | ❌ | Rien n'écoute sur `:8989` (`curl /api/dashboard/summary` sans réponse) → à lancer avec `SPEEDTEST_DATABASE_CONNECTION_STRING` (secret non présent dans le dépôt) |

**Blocage restant** : le backend Go a besoin de la chaîne Atlas (jamais committée). Sans elle, l'app installée n'aura pas de données ; alternatives : chaîne Atlas fournie par l'utilisateur, `mongod` local, ou backend Render de production (par défaut dans `config.dart`, sans tunnel).

## ✅ 26/09/2026 (suite) — chaîne Atlas fournie, pile locale 100 % opérationnelle

L'utilisateur a fourni la chaîne de connexion Atlas → blocage levé. Aucun secret écrit dans un fichier du dépôt (vérifié : recherche du mot de passe dans tout le projet = 0 résultat) ; passée uniquement via `SPEEDTEST_DATABASE_CONNECTION_STRING`.

| Élément | Statut | Preuve |
|---|---|---|
| Connexion Atlas | ✅ | `backend.err.log` : `Connected to MongoDB Atlas, database: yele_speedtest` (09:46:22Z) ; 6 connexions TLS `ESTABLISHED` vers les shards :27017 |
| Backend Go | ✅ | PID 6276, écoute `0.0.0.0:8989` + `[::]:8989` ; `/api/dashboard/summary` → 200 `{"totalTests":0,...}` ; `/getIP` → 200 |
| Dashboard web | ✅ | `python -m http.server 5500` (PID 12084), `config.js` = `http://localhost:8989` ; `index.html` → 200 |
| Dashboard ↔ backend | ✅ | Requête réelle `GET http://localhost:8989/api/dashboard/map` → **200**, aucune erreur console (CORS OK) |
| App mobile (STAR 1) | ✅ | `com.yele.mobilefront` installée (PID 30504 après lancement), **aucun** FATAL/AndroidRuntime |
| Tunnel app ↔ backend | ✅ | `adb -s 192.168.100.152:40629 reverse tcp:8989 tcp:8989` → `host-33` ; sonde depuis le device `nc -w 2 127.0.0.1 8989` → **rc=0** |

**Réseau actuel** : machine `192.168.100.149`, téléphone `192.168.100.152` (même /24) ; TCP 27017 sortant **non filtré** (contrairement au réseau du 24/09). Deux entrées ADB coexistent (`192.168.100.152:40629` et l'entrée mDNS) → toujours utiliser `-s` pour cibler l'appareil, sinon `error: more than one device/emulator`.

**Reste à faire** : (1) lancer une mesure réelle depuis l'app → vérifier qu'une ligne arrive dans `yele_speedtest` et remonte dans le dashboard ; (2) avant tout commit/déploiement du dashboard, remettre `New_web-main/config.js` sur l'URL de production ; (3) rejouer `adb reverse` à chaque reconnexion ADB.

**Sécurité** : le mot de passe Atlas ayant transité en clair dans la conversation, envisager une rotation si le canal n'est pas de confiance (la chaîne reste hors dépôt).

## 🛠️ 26/09/2026 (suite 2) — Vague 2 « Mesure » implémentée (ISS-01, ISS-02, ISS-06, IMP-01)

Dépôt modifié : `mobilefront-main` uniquement. Chaque correctif suit le critère
d'acceptation du cahier des charges.

| Item | Prio | Correctif | Fichiers |
|---|---|---|---|
| ISS-02 | P1 | Opérateur/techno lus sur **l'abonnement data actif** (`SubscriptionManager.getDefaultDataSubscriptionId()` + `TelephonyManager.createForSubscriptionId`) au lieu du TM par défaut (SIM 1). Renvoie aussi l'emplacement SIM et le nombre de SIM ; l'UI affiche « SIM n » sur bi-SIM. | `MainActivity.kt`, `network_info_service.dart`, `full_test_screen.dart`, `score_screen.dart`, `history_screen.dart` |
| ISS-01 | P1 | Lecture **RSRP/RSRQ** de la cellule servante (`SignalStrength.cellSignalStrengths`, LTE + NR, API 29+), valeurs « indisponibles » (Int.MAX_VALUE) écartées, plage dBm/dB validée. | `MainActivity.kt`, `network_info_service.dart`, modèle, UI |
| ISS-06 | P2 | **Min/moy/max** du débit (échantillons par fenêtre de 1 s hors montée en charge) et de la latence (min/max sur les 5 sondes). 6 indicateurs affichés au bilan et dans l'historique. | `speed_test_api_service.dart`, `config.dart`, modèle, UI |
| IMP-01 | P3 | **Consommation de données** du test = (rx + tx) via `TrafficStats` ; affichée en Ko/Mo/Go au bilan et dans l'historique. Nouveau canal `getTxBytes`. | `MainActivity.kt`, `traffic_stats_service.dart`, `speed_test_api_service.dart`, UI |

### Détails d'implémentation
- Modèle Hive `SpeedTestResult` : champs 34→43 (`minDownloadSpeed`, `avgDownloadSpeed`, `maxDownloadSpeed`, `minPing`, `avgPing`, `maxPing`, `dataConsumedKb`, `rsrp`, `rsrq`, `simSlot`). Adaptateur `.g.dart` mis à jour à la main (compteur de champs 33 → 43) ; les anciens résultats restent lisibles (champs absents → null).
- La consommation est relevée **avant/après** les phases du test (et non par phase) : elle couvre download + upload + streaming + navigation, soit ce que le forfait a réellement payé.
- Garde-fous : fenêtres sans octet ignorées pour ne pas fausser le minimum ; pas de « SIM 1 » affiché sur un appareil mono-SIM.

### Vérifications
- `flutter analyze` : **0 erreur** (aucun diagnostic sur les fichiers modifiés).
- `:app:compileDebugKotlin` (JAVA_HOME=jdk17) : **BUILD SUCCESSFUL** (seules des dépréciations préexistantes de `techLabel`).
- `flutter test` : **All tests passed** (1 test).

### ⚠️ Limite connue
RSRP/RSRQ dépendent de ce que le modem expose : sur certains terminaux/opérateurs, la valeur reste indisponible (« — »). Le champ est alors nul, jamais une fausse valeur.

## 📱 26/09/2026 (suite 3) — Vague 2 installée et vérifiée sur le téléphone

Appairage ADB sans fil : `adb pair 192.168.100.152:46847 283280` → OK ; port de connexion mDNS `192.168.100.152:45759`. Appareil **STAR 1 / Hicel**, Android 12 (SDK 31), **bi-SIM**.

| Étape | Résultat |
|---|---|
| Rebuild APK release arm64 (`--dart-define=API_BASE_URL=http://127.0.0.1:8989`) | ✅ `app-release.apk` 17,8 Mo |
| Installation | ⚠️ `INSTALL_FAILED_VERSION_DOWNGRADE` (installé = versionCode **2001**, nouveau = 1) → installé avec `install -r -d` (downgrade autorisé, données locales conservées) |
| Permissions runtime | ✅ READ_PHONE_STATE, ACCESS_FINE/COARSE_LOCATION |
| Tunnel | ✅ `adb reverse tcp:8989 tcp:8989` → `host-25` |

### Preuves fonctionnelles
- **ISS-02 (SIM data)** : l'écran de test affiche `Réseau mobile : « 4G · ONATEL · SIM 1 »` (arbre d'accessibilité `uiautomator`). Le suffixe « SIM 1 » n'apparaît que parce que l'appareil est bi-SIM → la résolution de l'abonnement data actif et la remontée de l'emplacement fonctionnent de bout en bout.
- **ISS-01 (RSRP/RSRQ)** : `dumpsys telephony.registry` montre que le modem **expose bien** les valeurs LTE — `phoneId=0 : rsrp=-93 rsrq=-9 level=4` et `phoneId=1 : rsrp=-87 rsrq=-13 level=4` ; le NR renvoie `2147483647` (indisponible), ce que le filtre rejette. Les valeurs produites seront donc réelles et non nulles sur ce terminal.

### ⚠️ Observations
- Les `print`/`logger` Dart **n'apparaissent pas dans logcat en build release** (même le log d'init Hive) : la vérification doit passer par l'arbre d'accessibilité ou `dumpsys`, pas par les logs.
- Le test complet lancé depuis l'UI a été **interrompu par la mise en arrière-plan de l'app** (Facebook Lite est passé au premier plan, puis Android a redémarré MainActivity) — **aucun FATAL/AndroidRuntime dans les logs**, donc pas de plantage imputable aux correctifs. La validation du bilan (RSRP/RSRQ, min/moy/max, données consommées) reste à faire sur un test complet non interrompu.
- Le versionCode installé (1) étant inférieur à l'ancien (2001), les prochaines installations `-r` échoueront encore : utiliser `-d` ou remonter le versionCode du projet.

## 🛠️ 27/09/2026 — ISS-03 « informations mobiles affichées en test Wi-Fi » corrigée

Constat de l'utilisateur confirmé : en test Wi-Fi, la colonne `Réseau mobile` (techno + opérateur + SIM) restait affichée et **rien** n'identifiait le réseau Wi-Fi utilisé. C'est exactement ISS-03 du cahier des charges (« Des informations de réseau mobile apparaissent alors que le test est effectué via Wi-Fi » / critère : *aucune information de réseau mobile ne doit être présentée comme réseau utilisé pour le test*).

| Élément | Statut | Détail |
|---|---|---|
| Type de connexion réel | ✅ | Canal natif `getConnection` : `ConnectivityManager.activeNetwork` + `NetworkCapabilities` → `WiFi` / `Mobile` / `Ethernet`. `connectivity_plus` ne peut pas trancher quand WiFi **et** data mobile sont actifs (il renvoie la liste des transports, pas le réseau par défaut) ; il ne sert plus que de repli. |
| Identité du réseau Wi-Fi | ✅ | SSID + bande (`WifiManager.connectionInfo`, fréquence → 2,4/5/6 GHz). Stockés dans `SpeedTestResult` (`wifiSsid`/`wifiBand`, champs Hive 44-45) et envoyés dans `extra` de la télémétrie. |
| Affichage | ✅ | Écran de test, bilan et historique : en Wi-Fi la 3e colonne devient `Réseau Wi-Fi · <SSID · bande>` ; la ligne/colonne `Réseau mobile` est **supprimée** (elle ne décrit pas le réseau mesuré). En mobile, comportement ISS-02 inchangé. |
| Repli honnête | ✅ | SSID masqué par l'OS → `null` (jamais un faux nom) ; l'UI affiche la cause : `nom masqué (localisation off)` si la localisation système est éteinte, sinon `nom indisponible`. |

### Preuves sur l'appareil (STAR 1 / Hicel, Android 12, bi-SIM)
- Reconnexion ADB sans fil : le port de *pairing* fourni (37551) était fermé (session expirée) → **scan complet des ports** → `35423` (port de connexion, déjà appairé) → `adb connect 192.168.100.152:35423` → `device`. Aucun ré-appairage nécessaire.
- État réseau du téléphone : `cmd wifi status` → connecté à `"FAMILLE TRAORE 2.4G"`, 2412 MHz (2,4 GHz) ; `dumpsys connectivity` → **réseau par défaut = WIFI** (network 249, `Transports: WIFI`). Le type détecté par l'app est donc bien `WiFi`.
- Log applicatif (build **debug**, seul cas où Dart écrit dans logcat) : `📶 NetworkStatus(WiFi, wifi=null/2,4 GHz, loc=false, tech=4G, sim=ONATEL, slot=0, rsrp=-90, rsrq=-12)`.
  → type Wi-Fi correct, **nom masqué** car `settings get secure location_mode` = **0** (localisation système éteinte) : Android ne livre le SSID qu'avec la localisation active. `locationEnabled=false` remonte jusqu'à l'UI, qui affiche la raison au lieu d'un `—` muet.
- ⚠️ Vérification d'affichage (arbre `uiautomator`) **bloquée** : écran du téléphone verrouillé (code PIN) — à refaire une fois l'appareil déverrouillé.

### Détails d'implémentation
- `MainActivity.kt` : `getConnection` → `{ connectionType, wifiSsid, wifiBand, locationEnabled }` ; SSID rejeté si `"<unknown ssid>"` ou `0x…` ; VPN sans transport reconnu → `null` (repli Dart).
- `network_info_service.dart` : `NetworkStatus.connectionLabel` (`Wi-Fi`/`Mobile`/…), `.wifiLabel` (SSID + bande, ou la raison du masquage), `locationEnabled`.
- `speed_test_result.dart` + `.g.dart` : `wifiSsid` (Hive 44), `wifiBand` (Hive 45), `isWifiTest`, `wifiLabel`. Les anciens résultats restent lisibles (champs absents → null).
- Vérifications : `flutter analyze` **0 erreur** (aucun diagnostic sur les fichiers touchés), `flutter test` **All tests passed**, `:app:compileDebugKotlin` **BUILD SUCCESSFUL**, APK release arm64 reconstruit (17,8 Mo).

### ⚠️ Observations hors périmètre
- `GET /getIP` du **backend local** (`speedtest.exe` du 10/09) répond en `Content-Type: text/plain` (alors que Render répond `application/json`) → côté app, `data['rawIspInfo']` lève `type 'String' is not a subtype of type 'int' of 'index'` : FAI/IP-localisation restent vides en test local (ils fonctionnent contre Render). Déblocable en recompilant le backend depuis les sources.
- En tunnel `adb reverse`, le backend voit `127.0.0.1` : la géoloc IP du test serait de toute façon vide en local.

## ✅ 27/09/2026 (suite) — test complet rejoué sur l'appareil + blocage de fin de test corrigé

Localisation activée par l'utilisateur (`location_mode=3`) et écran déverrouillé. Deux tests complets lancés depuis l'UI (build debug pour avoir les logs, puis release).

| Constat | Résultat |
|---|---|
| Identification Wi-Fi à l'écran | ✅ `Connexion : Wi-Fi` · `Réseau Wi-Fi : FAMILLE TRAORE 2.4G · 2,4 GHz` — **aucune** information de SIM présentée comme réseau du test (arbre `uiautomator`, vérifié en build **release** aussi) |
| SSID réel remonté | ✅ log debug : `NetworkStatus(WiFi, wifi=FAMILLE TRAORE 2.4G/2,4 GHz, loc=true, …)` — le nom n'est lisible que si la localisation système est active |
| Mesures | ✅ 1er test : DL 43,2 / UL 13,0 Mb/s, ping 279 ms ; 2e test : DL 27,8 / UL 5,0 Mb/s, ping 2269 ms ; navigation 100 % de réussite, 3 202 ms sur 6 pages (score 88) ; streaming 1080p 81,53 % (16 516 kiB) |
| Enregistrement + remontée | ✅ `Résultat sauvegardé` puis `Résultat uploadé: 01M3JHK8RB63AA3HHA1Q3TCY8M` ; `GET /api/dashboard/map` → point `networkType: WiFi`, DL 27.77, ping 2269.33 (Atlas) |

### 🐞 Bug bloquant trouvé pendant le test (corrigé) — le test ne finissait jamais
Symptôme : après l'échec de la phase streaming (« lecteur YouTube non chargé »), l'app restait indéfiniment sur l'écran de test — pas de bilan, pas de phase navigation, aucune activité réseau, aucune erreur en log.

Cause : dans le `finally` de `StreamingTestService.runTest`, `await controller.runJavaScript('stopLevel()')` sur une WebView dont la page **n'a jamais chargé** ne rend jamais la main (aucun document à évaluer) — le `catch (_)` ne peut rien rattraper, puisqu'il n'y a pas d'exception mais une attente infinie.

Correctif (`streaming_test_service.dart`) :
- appel de `stopLevel()` conditionné à `_ready?.isCompleted == true` (l'API du lecteur a réellement répondu) ;
- attente bornée à 5 s dans le `finally` **et** dans `_stopLevel()` : une phase en échec ne doit jamais figer la campagne (ISS-08).
Vérification après correctif : le test enchaîne navigation → bilan → envoi serveur (2e test ci-dessus).

### ⚠️ Observations
- Le **streaming YouTube échoue au 1er essai** (25 s d'attente de l'API du lecteur, `_ready` en timeout) et réussit au 2e : la latence du lien (2269 ms au 2e test) et le chargement de l'iframe YouTube sont manifestement à la limite du délai. Piste : porter le timeout de `_ready` à ~40 s et/ou préchauffer le lecteur pendant les phases débit/upload.
- L'écran **Historique** n'expose ni ses lignes ni son message « Aucun test pour cet onglet. » à `uiautomator` (arbre tronqué après l'en-tête) : la ligne « Réseau Wi-Fi » de l'historique n'a donc pas pu être vérifiée visuellement, uniquement par lecture de code.
- `wifiSsid`/`wifiBand` partent bien dans `extra`, mais le `mobileExtra` du backend Go ne les mappe pas encore (ils restent dans `extra_raw`) : le dashboard affiche `networkType` (correct : `WiFi`) et les métadonnées SIM. Extension backend + dashboard à faire si on veut le SSID côté serveur.

## 🛠️ 29/09/2026 — « FAI non détecté » : cause trouvée, corrigée et vérifiée

Constat confirmé par l'utilisateur : la ligne **FAI** de l'app restait à `—`. Ce point ne
figure pas dans le cahier des charges (20 items) : c'est un défaut de la pile de test
locale, révélé par les tests sur appareil.

### Cause racine (deux défauts cumulés)
1. **Chemin « IP privée » du backend** : avec le tunnel `adb reverse`, le serveur voit
   `127.0.0.1` et `getIP` sortait **avant** la résolution FAI, en écrivant le JSON sans
   `Content-Type` → Go renvoyait `text/plain; charset=utf-8`. Côté app, Dio livrait une
   `String`, et `data['rawIspInfo']` levait `type 'String' is not a subtype of type 'int'
   of 'index'`, avalée par le `catch` générique : FAI vide, **sans aucune trace**.
2. Même en JSON, ce chemin ne portait **aucune** donnée FAI (`rawIspInfo` vide) : une IP
   privée n'est pas géolocalisable.

Contraste mesuré : `GET /getIP?isp=true` → **Render** `200 application/json` +
`"org":"AS25543 ONATEL (…)"` ; **backend local** `200 text/plain` + `org:""`. La
production n'était donc pas en cause : c'est bien la recette locale qui ne pouvait pas
afficher de FAI.

### Correctifs

| # | Fichier | Changement |
|---|---|---|
| 1 | `web/web.go` | chemin IP privée : `Content-Type: application/json` explicite (le JSON est le format attendu par les clients) ; extraction du préfixe `AS<n>` factorisée dans `asPrefixRegexp` |
| 2 | `web/web.go`, `config/config.go`, `settings-local.toml` | nouvelle option `isp_info_for_private_ip` : quand le client est privé, le serveur interroge ipinfo.io pour **sa propre** IP publique. Un test lancé depuis le LAN sort par cette même connexion, l'opérateur annoncé est donc bien celui de la mesure. Sans effet en production (l'IP client y est publique). |
| 3 | `lib/services/location_service.dart` | `/getIP` accepté en `Map` **ou** en chaîne JSON (`_asJsonMap`) ; `loc` tolérante (absente ou malformée → plus d'exception) ; préfixe `AS<n>` retiré **seulement s'il est présent** (`_cleanOrg`) ; plus de coordonnées `0,0` inventées (retour `null` si rien d'exploitable) |

### Vérifications

| Contrôle | Résultat |
|---|---|
| `go vet` + `go build` | ✅ OK |
| `flutter analyze` | ✅ **0 erreur** (seuls des `info`/`warning` préexistants ailleurs) |
| `curl http://127.0.0.1:8989/getIP?isp=true` | ✅ `200` **`application/json`** + `"processedString":"127.0.0.1 - localhost IPv4 access - ONATEL (Office National des Telecommunications, PTT), BF"` + `city`/`loc`/`org` réels |
| Écran de test (appareil) | ✅ `Connexion: Wi-Fi` · `FAI: ONATEL (Office National des Telecommunications, PTT)` · `Réseau Wi-Fi: FAMILLE TRAORE 2.4G · 2,4 GHz` |
| Bilan du test | ✅ mêmes trois valeurs (barre du bas, après défilement) |
| Test complet rejoué | ✅ terminé sans blocage — DL 0,76 / UL 1,11 Mb/s, ping 581 ms (réseau dégradé pendant la session), navigation 47/100 (5,6 s, 83 %), streaming 1080p 90/100, 41,2 Mo consommés |
| Remontée serveur | ✅ QoE validé → `Évaluation enregistrée` → Atlas : `operator = ONATEL (…)`, `networkType = WiFi`, `simOperator = TELECEL`, `qoeRating = 3` ; `GET /api/dashboard/map` = 2 points ; `summary` → `totalTests 5, testsToday 1` |

### Appairage ADB du nouvel appareil
Appareil **M5** (Blackview M5, Android 12, SDK 31) : `adb pair 192.168.100.143:42774 023615`
→ OK ; le **port de connexion est `34377`**. Le port de *pairing* (42775) reste ouvert mais
n'accepte que l'appairage — `adb connect` dessus échoue. Piège : `.143` répond en ARP tout
en ignorant l'ICMP ; un `ping` muet ne prouve pas l'absence de l'appareil → scanner les
ports de la plage 30000-61000 (`.freebuff/find_phone.py`).

### ⚠️ Observations
- **L'envoi au serveur n'a lieu qu'après validation du QoE** (`ScoreScreen._finalize` est
  appelé par `_openQoe`) : quitter le bilan sans répondre laisse la mesure dans
  l'historique local uniquement. Comportement voulu, mais il explique un « dashboard vide »
  juste après un test — le bilan affiché ne signifie pas encore « mesure transmise ».
- Les mesures antérieures au correctif gardent `operator = "localhost IPv4 access""` dans
  Atlas : l'historique n'est pas réécrit.
- `wifiSsid`/`wifiBand` partent toujours dans `extra` mais `mobileExtra` ne les mappe pas :
  le SSID mesuré n'est pas visible côté dashboard.

## ✅ 29/09/2026 (suite) — ISS-09 « synchronisation » et ISS-08 « durée du test » corrigés

### ISS-09 — les données mettaient du temps à apparaître sur le Dashboard

Trois causes distinctes se cumulaient — la plus lourde n'était pas le réseau :

| # | Cause | Correctif |
|---|---|---|
| 1 | L'app n'envoyait la mesure qu'après validation du QoE **ou** sortie de l'écran bilan (`ScoreScreen._finalize` appelé par `_openQoe` / `onPopInvokedWithResult`). | Enregistrement + envoi **dès l'affichage du bilan** (`initState`). Le QoE, recueilli ensuite, est rattaché à la mesure déjà transmise via `POST /api/dashboard/qoe` (handler Go `DashboardQoeUpdate` + `MongoDB.UpdateQoe`), idempotent et sans doublon. |
| 2 | Le client API du dashboard mettait chaque réponse **en cache sans expiration** (`js/api.js`) : la requête n'était plus jamais émise, donc aucune mesure ne pouvait apparaître sans rechargement complet de la page. | Cache avec TTL de 15 s. |
| 3 | Le dashboard ne se rafraîchissait pas de lui-même. | `App.startAutoRefresh()` : la vue active est rejouée toutes les 20 s (map, stats, operators, history, compare, ai) et immédiatement au retour sur l'onglet. Garde-fous : onglet caché, saisie en cours, info-bulle ouverte. `MapView.refresh()` recharge sans afficher le bandeau d'attente. |

Champ Hive `serverId` (48) ajouté : identité **serveur** de la mesure, distincte de
l'identité locale `id`. Les confondre faisait réécrire l'entrée locale sous une seconde clé
à chaque enregistrement après envoi, et interdisait tout rattachement ultérieur.

**Cible définie** : la mesure doit apparaître sur le dashboard **en moins de 30 s après la
fin du test, sans aucune action de l'utilisateur**.

**Preuves** (4 tests réels du 29/09, aucun QoE rempli, aucun changement d'écran) :

| Test lancé | Mesure en base | Écart | Remarque |
|---|---|---|---|
| 08:33:04 | 08:34:44 | 101 s | mesure + QoE (3/5) rattaché ensuite — même document, total inchangé |
| 08:40:02 | 08:41:34 | 93 s | aucun QoE |
| 08:51:42 | 08:53:19 | 98 s | aucun QoE |
| 08:56:03 | 08:57:46 | 103 s | **dashboard déjà ouvert : 5 → 6 points à 08:57:59, soit 12,7 s après l'arrivée en base, sans rechargement** |

Vérifications complémentaires : `POST /api/dashboard/qoe` refuse un identifiant absent (400),
une note hors 1-5 (400) et un identifiant inconnu (404) ; le rafraîchissement automatique a
été constaté en direct (22 cycles en 7 min, soit un toutes les 20 s) ; l'ancien `api.js` resté
en cache navigateur a d'abord masqué le correctif — à garder en tête lors d'une recette :
forcer un chargement sans cache.

### ISS-08 — durée du test complet

- **Instrumentation** : `TestPhaseTimings` mesure init / descendant / montant / latence /
  streaming / navigation / total, stocké dans le résultat (champs Hive 46-47), **affiché au
  bilan** (« Durée du test » + « Répartition ») et dans l'historique, et transmis au serveur
  (`testDurationSec`, `phaseTimings` mappés dans le document Mongo).
- **Cible définie** : `FULL_TEST_TARGET_SEC = 120` (phases machine ; le QoE est un temps de
  réponse utilisateur et n'est pas compté).
- **Bornes de phase** : `STREAMING_PHASE_BUDGET_SEC = 45`, `BROWSING_PHASE_BUDGET_SEC = 30`.
  Un palier vidéo n'est entamé que si le budget le permet ; une page web n'est chargée que si
  le reliquat permet de la charger. Au-delà, la mesure restante n'est pas faite (colonne
  « — », page non comptée dans le taux de réussite) — un abandon ne se lit jamais comme un
  échec réseau.

Mesures réelles (réseau actuellement très dégradé : ping 1,3 à 3,8 s) :

| Test | Durée | Init | Desc. | Mont. | Latence | Streaming | Navigation |
|---|---|---|---|---|---|---|---|
| 08:34 | **96 s** | 1,0 | 10,0 | 10,0 | 7,8 | 41,7 | 25,7 |
| 08:41 | **89 s** | 0,7 | 10,0 | 10,0 | 12,1 | 39,6 | 16,8 |
| 08:53 | **94 s** | 0,7 | 10,0 | 10,0 | 11,8 | 40,9 | 20,1 |
| 08:57 | **100 s** | 0,5 | 10,0 | 10,0 | 20,1 | 41,3 | 17,9 |

Les 4 tests respectent la cible (89-100 s ≤ 120 s). Avant correctif, les deux tests du 27/09
n'avaient aucune borne : la phase streaming pouvait à elle seule coûter 25 s d'attente du
lecteur + 3 paliers, et la navigation jusqu'à 120 s sur six pages lentes.

### ⚠️ Observations
- Le budget streaming **n'a rien tronqué** dans ces quatre tests (39,6-41,7 s < 45 s) : il
  borne les cas pathologiques, il n'accélère rien. La phase reste la plus coûteuse et la
  seule vraie réserve de temps.
- Sur cette liaison, YouTube n'a servi que du **1080p** : les colonnes 720p et 2160p restent
  vides. C'est le comportement documenté (`setPlaybackQuality` n'est qu'une suggestion), mais
  ISS-07 mérite une vérification sur un lien sain.
- Les 20 s de débit (10 s descendant + 10 s montant) sont incompressibles sans dégrader la
  mesure — ce sont les seules phases à durée fixe non négociables.- `New_web-main/config.js` pointe toujours sur `http://localhost:8989` (état de la recette locale) : à remettre sur l'URL de production avant tout déploiement.

## 🚀 30/09/2026 — nouveau réseau (10.114.150.x), M5 reconnecté + tunnel posé

Réseau changé : machine **10.114.150.11** (Wi-Fi, passerelle .105), téléphone **M5** sur **10.114.150.227** (même /24).

| Étape | Statut | Preuve |
|---|---|---|
| Appairage ADB sans fil | ✅ | `adb pair 10.114.150.227:46281 867929` → `Successfully paired [guid=adb-110142304006105-nJDwZi]` — même M5 que le 29/09, **pas de nouveau GUID** |
| Port fourni 39501 | ⚠️ | C'était un **port de pairing déjà expiré** → `adb connect` refus (10061). Le port de pairing meurt après usage ; le port de connexion est l'autre affiché sur l'écran « Débogage sans fil » |
| Session ADB existante | ✅ | L'entrée mDNS `adb-110142304006105-nJDwZi._adb-tls-connect._tcp` répond à `shell echo ok` — l'appareil est joignable **sans re-scan de port** (le scan 1024-65535 renvoie d'ailleurs 0 port ouvert : scan bloqué/inutile sur ce réseau, ne pas s'y fier) |
| Tunnel | ✅ | `adb -s <guid> reverse tcp:8989 tcp:8989` → `host-25 tcp:8989 tcp:8989` ; sonde device `nc 127.0.0.1 8989` → **rc=0** |
| Appareil | ✅ | M5, Android 12 (SDK 31), IP `10.114.150.227/24` (wlan0), `com.yele.mobilefront` installée, écran déverrouillé |
| TCP 27017 sortant | ✅ | Les 2 shards testés répondent — **Atlas joignable sur ce réseau** |
| Backend local | ⛔ | PID 15624 (`speedtest.exe -c settings-local.toml`) écoute sur :8989 mais **sans la chaîne Atlas** → `/api/dashboard/summary` → `{"error":"Dashboard requires database_type=mongodb"}` ; `backend.err.log` 09:28 : ping MongoDB timeout ; relance 09:29 SANS variable → pas de MongoDB. `/getIP` répond 200 `application/json` |

### Procédure manuelle ADB (documentée pour l'utilisateur)
1. Téléphone : Options développeurs → **Débogage sans fil** → « Associer l'appareil avec un code » → code 6 chiffres + IP:PORT de **pairing**.
2. `adb pair <IP:PORT_PAIRING> <CODE>` (code à usage unique, ~1 min).
3. `adb connect <IP:PORT_CONNEXION>` (l'autre port affiché) puis `adb devices` → `device`.
4. `adb -s <IP:PORT> reverse tcp:8989 tcp:8989` puis vérif `reverse --list` + `nc -w 2 127.0.0.1 8989` (rc=0).
5. Lancer le test dans l'app (APK `API_BASE_URL=127.0.0.1:8989` → tout passe par le tunnel, zéro règle pare-feu).

### ⏭️ Reste à faire pour lancer le test complet
1. **Relancer le backend avec la chaîne Atlas** : tuer PID 15624 puis `SPEEDTEST_DATABASE_CONNECTION_STRING=... ./speedtest.exe -c settings-local.toml` (la variable n'est ni dans le dépôt ni dans l'environnement utilisateur — la fournir à nouveau).
2. Rejouer `adb reverse` si l'appareil se déconnecte.
3. Lancer un test complet depuis l'app M5 et vérifier la remontée Atlas + dashboard.

## 📱 30/09 (suite) — APK « production » construit pour les tests 4G

Contexte : les APK installés pointent tous sur `127.0.0.1:8989` (recette tunnel). Pour mesurer la **vraie 4G** (téléphone seul, Wi-Fi coupé, mesure partant sur Render), il faut la variante qui garde le défaut `config.dart` → **Render**. Rappel : le tunnel ADB et un test 4G sont incompatibles (le trafic mesuré passerait par le PC ; de plus couper le Wi-Fi tue ADB).

| Élément | Détail |
|---|---|
| Build | `flutter build apk --release` **sans** `--dart-define` (JAVA_HOME=jdk17, lancé détaché via Start-Process) — 204 s |
| APK | `mobilefront-main/build/app/outputs/flutter-apk/app-release.apk` (50,5 Mo, APK universel toutes ABI) |
| Cible | `API_BASE_URL` = défaut = `https://mobiletest-j0c6.onrender.com` |
| Installation | `adb install -r -d` (le `-d` reste obligatoire sur STAR 1 : versionCode installé 2001 > build 1) |
| Changements réseau depuis le matin | Machine puis téléphone passés sur un 3e réseau `10.65.36.x` (PC .80, M5 .81) ; session M5 mDNS toujours vivante après reconnexion Wi-Fi, tunnel reposé, `TUNNEL=0` |

**Test 4G à venir** : installer cet APK sur M5 + STAR 1 → Wi-Fi coupé, data active → la mesure part sur Render ; vérifier (a) la colonne mobile `techno · opérateur · SIM n` dans l'historique, (b) la confusion de SIM (ISS-02) sur le STAR 1 bi-SIM en basculant la SIM data entre slots, (c) l'arrivée côté dashboard Render.

### ✅ 30/09 (suite 2) — APK production installé sur le M5

| Étape | Statut | Détail |
|---|---|---|
| M5 reconnecté | ✅ | `adb connect 10.65.36.81:46817` (annonce mDNS, port 46817 ; redémarrage du daemon ADB en cours de route) → `device` |
| Installation APK production | ✅ | `install -r -d` → `Success` ; versionCode=1 / versionName=1.0.0 ; permissions runtime re-grantées (READ_PHONE_STATE, FINE/COARSE_LOCATION) |
| Conséquence | ⚠️ | Le M5 ne porte **plus** l'APK localhost : pour revenir à la recette tunnel il faudra réinstaller un build `--dart-define=API_BASE_URL=http://127.0.0.1:8989` |
| STAR 1 | ⛔ | Appairages successifs en échec (`protocol fault`) ; .78/.44 muettes (ping 100 % perdu, pas d'ARP) ; réapparu un moment en mDNS sous nouveau GUID `adb-066773714H105936` (.32:35281) puis disparu → appareil hors réseau, à réactiver par l'utilisateur |

**Piège noté** : le M5 (mono-SIM TELECEL) ne peut pas servir au test de confusion SIM (ISS-02) — il exige le STAR 1 bi-SIM avec deux opérateurs différents.

## 🚀 03/10/2026 — retour sur 192.168.100.x : APK redéployé sur le M5, pile complète opérationnelle

Réseau de retour : machine `192.168.100.149`, téléphone **M5** sur `192.168.100.143`. Le port fourni (38155) était muet → **scan 30000-61000 → port de connexion `38975`** → `adb connect` OK (pas de ré-appairage nécessaire).

| Étape | Statut | Détail |
|---|---|---|
| Connexion M5 | ✅ | `192.168.100.143:38975` → `device` (M5, Android 12/SDK 31, app `com.yele.mobilefront` déjà installée) |
| Détection périmé | ✅ | 5 fichiers Dart plus récents que l'APK du 30/09 → recompilation nécessaire |
| 🐞 Correctif Dart | ✅ | `speed_test_api_service.dart` : `upload` déclaré **dans** le bloc `if (selection.speed)` mais utilisé hors portée ligne 630 (`upload?.minMbps`…) → `SpeedTransferMeasurement? upload` remonté au niveau de `download` ; `flutter analyze` 0 erreur |
| 🐞 Correctif Kotlin | ✅ | `NETWORK_TYPE_LTE_CA` (API 29) non résolu par le compileSdk effectif dans `MainActivity.kt` + `SignalCollectorService.kt` (ajouts du 02/10) → constante **inlinée en 19** avec commentaire ; aucune collision de branches |
| Build | ✅ | `flutter build apk --release --dart-define=API_BASE_URL=http://127.0.0.1:8989` → `app-release.apk` **50,5 Mo** (script `build/build_release.cmd` lancé en caché — méthode fiable, les `Start-Process cmd /c ...` inline sont mangés par la réécriture Git Bash) |
| Installation | ✅ | `install -r -d` → `Success` (downgrade versionCode 1 < 2001 autorisé, données conservées) |
| Permissions | ✅ | `pm grant` READ_PHONE_STATE + ACCESS_FINE/COARSE_LOCATION rejoués après réinstall |
| Tunnel | ✅ | `adb reverse tcp:8989 tcp:8989` → `host-24` ; preuve côté device : `[::]:8989 LISTEN` + connexion `127.0.0.1:47160→127.0.0.1:8989` en TIME_WAIT (l'app a déjà parlé au backend) |
| Backend + Atlas | ✅ | `speedtest-new.exe` (PID 3444) relancé avec `SPEEDTEST_DATABASE_CONNECTION_STRING` via `Start-Process` PowerShell (secret non écrit dans un fichier) → `Connected to MongoDB Atlas` ; `/api/dashboard/summary` → `{"totalTests":9,...}` |
| App | ✅ | Lancée (`am start`), PID 23354, aucun FATAL/AndroidRuntime dans logcat |

### Pièges de la session
- **Git Bash réécrit les `/c`, `/d` inline** passés à `cmd` via `powershell Start-Process` → écrire un `.cmd` sur disque et le lancer. Seul lancement fiable.
- **Wi-Fi instable** (ping 199 ms, 50 % de perte) → commandes ADB shell parfois sans réponse : utiliser `timeout 25-30` autour de chaque appel et rejouer, l'appareil reste `device`.
- Le binaire backend s'appelle désormais **`speedtest-new.exe`** (build du 29/09 avec correctifs FAI) — ne plus invoquer `speedtest.exe`.

### ⏭️ Reste
- Lancer un **test complet** depuis l'app M5 et vérifier la remontée Atlas (la pile est prête).
- Test ISS-02 (confusion SIM) toujours conditionné au **STAR 1 bi-SIM** (hors réseau ce jour).

## 🐞 03/10/2026 (suite) — « Ouagadougou » en dur chassé du code + APK vérifié par empreinte

Signalement utilisateur : la ligne « Réseau : Ouagadougou » de l'historique est incompréhensible ; suspicion d'APK non mis à jour.

### Vérification APK (suspicion levée)
MD5 du binaire installé sur le M5 = MD5 de l'APK compilé (`e003e10d…`) → **identiques octet pour octet**. Ce que l'historique affichait = les **anciennes mesures stockées dans la base locale Hive**, jamais réécrites par une mise à jour. Après la réinstall, l'historique local affiche toujours ses anciennes lignes (comportement normal), mais tout nouveau test utilise le nouveau code.

### « Ouagadougou » : cause trouvée (ISS-04, résiduel)
Trois occurrences en dur, toutes retirées :

| Fichier | Avant | Après |
|---|---|---|
| `score_screen.dart:139` | bilan : si la géoloc IP échoue → affiche `Ouagadougou` inventé | `[BF] yele_serveur` seul (pas de ville fictive) |
| `full_test_screen.dart:503` | bannière figée `yele_serveur — Ouagadougou` | `[BF] yele_serveur` |
| `history_screen.dart:380` | ligne étiquetée `Réseau` montrant en réalité la **géolocalisation IP** (ville/pays de sortie) | étiquette renommée `Localisation IP` — honnête |

`SampleData` (Bamako) : classe de test jamais référencée — laissée telle quelle.

### Vérifications
- `flutter analyze` sur les 3 écrans : **No issues found**
- Build release : ✅ 50,5 Mo → `install -r -d` `Success` → permissions rejouées → app relancée (PID 28148)
- Rappel cohérence : la ligne « Réseau » de l'historique = ville de sortie IP ; le **réseau réel du test** est la ligne `Réseau Wi-Fi` ou `Réseau mobile` au-dessus (ISS-03).

## 🛠️ 03/10/2026 — Historique : champs prioritaires alignés sur nPerf

- Dans le détail des mesures, `FAI` est renommé `Opérateur`, `Réseau Wi-Fi` devient `Réseau` (SSID) et le champ `Techno` est ajouté.
- La technologie affiche `WiFi` et, si disponible, la bande Wi-Fi mesurée ; en cellulaire, elle utilise la technologie radio mesurée. Aucun débit radio n'est inventé.
- Pour les tests mobiles, le nom de réseau/SSID n'étant pas collecté, la ligne `Réseau` reste `—`.

## 🛠️ 03/10/2026 — Historique mobile présenté en deux colonnes

- Le détail développé reprend la disposition nPerf : serveur, opérateur/FAI, réseau, technologie, signal, coordonnées, adresse/localisation et trafic à gauche ; débits, latence, gigue et scores à droite.
- Les champs radio et les pics non mesurés restent signalés comme indisponibles au lieu d'être estimés. La liste résume désormais l'opérateur et le réseau mesuré plutôt que la localisation IP.
- Validation : `flutter analyze lib/screens/history_screen.dart` et `flutter test test/widget_test.dart` réussis.

## 🛠️ 03/10/2026 — Libellés réseau du tableau de bord

- Dans l'historique web, la colonne `FAI` est renommée `Opérateur/FAI`.
- Pour les résultats dont le type de connexion est Wi-Fi, `Réseau mobile` affiche `/` ; les tests cellulaires conservent la techno et l'opérateur SIM.

## 🛠️ 03/10/2026 — Réseau mobile Wi-Fi : cache du dashboard

- Vérification sur l'API de production : les résultats Wi-Fi portent bien `networkType = WiFi`, tandis que `cellularTech` et `simOperator` reflètent la SIM active (ex. `4G`, `Orange BF`), même si elle n'a pas transporté le test.
- Cause de l'affichage observé : le navigateur servait une ancienne version de `history.js`, sans le filtre Wi-Fi. Le test de la page actualisée confirme maintenant `/` pour les mêmes résultats.
- Filtre Wi-Fi rendu tolérant aux variantes de formatage et URL de script versionnée pour invalider le cache navigateur.

## ✅ État mis à jour — Réseau, double SIM et libellé Opérateur/FAI

- **Double SIM (ISS-02) : résolu**, confirmé par l'utilisateur. L'application identifie l'abonnement data actif et sa position SIM ; en réseau cellulaire, l'historique conserve la technologie et l'opérateur de cette SIM.
- **Wi-Fi (ISS-03) : résolu pour l'affichage de l'historique web.** « Réseau mobile » affiche `/` pour les mesures `WiFi`, même si la SIM Orange/Moov reste active sur le téléphone. La donnée SIM reste stockée séparément, elle n'est pas le réseau qui a transporté le test.
- La colonne s'intitule **`Opérateur/FAI`** et affiche le FAI associé à l'IP publique de la mesure. Cette valeur peut différer de l'opérateur SIM : si une connexion mobile Moov est attribuée à ONATEL par la résolution GeoIP, la colonne peut afficher ONATEL. Ce n'est pas une confusion de SIM ; le champ `simOperator` constitue l'information distincte de l'abonnement.
- Les entrées antérieures ne sont pas réécrites : l'API de production vérifiée contient notamment des tests Wi-Fi avec `operator = ONATEL`, et des tests antérieurs avec `operator = Moov Africa`. Pour distinguer l'attribution FAI de l'opérateur SIM, consulter séparément `operator` et `simOperator`.
- Vérification fonctionnelle du dashboard local : les tests `networkType = WiFi` ayant `cellularTech = 4G` et `simOperator = Orange BF` affichent désormais `/` dans la colonne « Réseau mobile ».
