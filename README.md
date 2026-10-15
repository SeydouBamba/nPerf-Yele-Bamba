# Corrections apportées au code d'origine

Ce document récapitule les erreurs et défauts corrigés dans les projets d'origine. Il ne décrit que les changements consignés et vérifiés dans le journal de suivi.

## Application mobile (`mobilefront-main`)

- **Double SIM (ISS-02)** — les informations cellulaires sont lues depuis l'abonnement utilisé pour les données mobiles, plutôt que depuis la SIM par défaut. La SIM correspondante est indiquée sur les appareils bi-SIM.
- **Mesures du signal et des performances (ISS-01, ISS-06, IMP-01)** — collecte du RSRP/RSRQ lorsque le modem les fournit, calcul des débits et latences minimum, moyens et maximum, et mesure du volume de données consommé. Une valeur non fournie par l'appareil reste indisponible plutôt que d'être inventée.
- **Identification Wi-Fi/mobile (ISS-03)** — détection du transport réellement utilisé pour le test. En Wi-Fi, l'application affiche le réseau Wi-Fi et sa bande au lieu de présenter la SIM comme réseau mesuré.
- **Fin de test bloquée** — l'arrêt du lecteur vidéo n'est tenté que lorsque son interface est prête, avec des délais bornés. Un lecteur qui ne se charge pas ne bloque donc plus indéfiniment le test.
- **Durée du test (ISS-08)** — ajout du suivi des durées et de limites aux phases de streaming et de navigation, afin que les phases lentes ou interrompues ne prolongent pas indéfiniment une mesure.
- **Envoi et synchronisation des résultats (ISS-09)** — la mesure est transmise à l'affichage du bilan, sans attendre la réponse au questionnaire QoE. La réponse QoE est associée ensuite au résultat existant; le tableau de bord peut ainsi se mettre à jour automatiquement sans doublon.
- **FAI et réponse `/getIP`** — correction du traitement des réponses JSON ou texte JSON, de champs de localisation absents ou malformés et des données FAI. Les coordonnées `0,0` ne sont plus utilisées comme valeur de remplacement lorsque la localisation manque.
- **Libellé de localisation trompeur (ISS-04)** — retrait de la ville « Ouagadougou » affichée par défaut lorsque la géolocalisation IP échoue; l'historique distingue la localisation IP du réseau utilisé.
- **Erreur de compilation Dart** — déplacement de la déclaration de la mesure montante hors du bloc conditionnel où elle était définie, afin qu'elle soit accessible aux traitements qui l'utilisent.
- **Erreur de compilation Android/Kotlin** — remplacement de la constante LTE non résolue dans `MainActivity.kt` et `SignalCollectorService.kt` par sa valeur numérique API 29, avec une indication dans le code.

## Backend (`mobiletest-main`)

- **Informations FAI en test local** — le chemin d'adresse IP privée de `/getIP` renvoie explicitement du JSON. Une option permet de résoudre le FAI à partir de l'adresse publique du serveur pour les tests lancés sur un réseau local.

## Tableau de bord web (`New_web-main`)

- **Réseau Wi-Fi présenté comme réseau mobile (ISS-03)** — dans l'historique, la colonne « Réseau mobile » affiche `/` pour les mesures Wi-Fi; les informations de SIM restent distinctes du réseau ayant transporté le test.
- **Affichage obsolète** — le cache des réponses API expire après 15 secondes et les vues se rafraîchissent automatiquement. Le script d'historique est versionné pour éviter de conserver l'ancienne correction en cache navigateur.
- **Libellé FAI** — la colonne est nommée « Opérateur/FAI » pour distinguer le fournisseur associé à l'adresse IP de l'opérateur de la SIM.

## Vérifications consignées

Le journal rapporte des analyses Flutter sans erreur, des tests Flutter réussis, `go vet` et `go build` réussis, ainsi que des essais fonctionnels sur appareil Android et des vérifications du tableau de bord.

Ce récapitulatif ne signifie pas que tous les points du cahier des charges ont été corrigés. Les problèmes simplement diagnostiqués, en attente ou non vérifiés ne sont pas présentés ici comme résolus.
