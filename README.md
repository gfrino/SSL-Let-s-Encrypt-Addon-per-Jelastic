# SSL-Let-s-Encrypt-Addon-per-Jelastic

WP Multisite SSL Manager (Jelastic + LiteSpeed)

Addon Jelastic per la gestione semplice, scalabile e automatica dei certificati Let’s Encrypt su WordPress Multisite con LiteSpeed.

👉 Un dominio = un vHost = un SSL
👉 Domini infiniti
👉 Rinnovo automatico

⸻

🎯 Cosa risolve
	•	Gestione SSL per singolo dominio in WordPress Multisite
	•	Eliminazione configurazioni manuali di vHost
	•	Automazione completa Let’s Encrypt
	•	Scalabilità per ambienti con decine o centinaia di siti

Ideale per:
	•	multisite con domain mapping
	•	ambienti Jelastic (Infomaniak)
	•	piattaforme white-label

⸻

⚙️ Requisiti
	•	Jelastic
	•	Server LiteSpeed
	•	Accesso root
	•	WordPress Multisite funzionante
	•	DNS del dominio già puntato al nodo

⸻

📁 Struttura del progetto

jelastic-wp-multisite-ssl/
├── manifest.jps
├── scripts/
│   ├── install-base.sh
│   └── add-domain.sh
└── templates/
    └── litespeed-vhost.conf


⸻

🚀 Installazione (addon su ambiente esistente)

1️⃣ Pubblica il repository su GitHub

Il repository deve essere pubblico (consigliato) oppure accessibile via token.

2️⃣ Importa il manifest JPS nell’ambiente

Nella dashboard di Jelastic, apri l’ambiente e usa Importa → URL (non la scheda JPS).
Esempio URL raw:

https://raw.githubusercontent.com/TUO-USER/SSL-Let-s-Encrypt-Addon-per-Jelastic/master/manifest.jps

Durante l’installazione:
	•	viene preparato l’ambiente
	•	viene installato certbot
	•	viene configurato il rinnovo automatico SSL

3️⃣ Dove trovi l’addon dopo l’installazione

Lo troverai nei “Componenti aggiuntivi” dell’ambiente come “WP Multisite SSL Manager”.
Da lì puoi lanciare l’azione “Aggiungi dominio al Multisite”.

Azioni disponibili nell’addon:
	•	Installa base (certbot + cron)
	•	Aggiungi dominio al Multisite
	•	Rimuovi dominio
	•	Lista domini configurati
	•	Rinnova SSL ora
	•	Disinstalla (pulizia completa)

⚠️ Nota provider: alcuni pannelli (es. Infomaniak) non mostrano “My Addons/Private” nel Marketplace.
In quel caso l’addon non compare nel catalogo globale, ma è comunque installabile via Importa nell’ambiente.

⸻

🧩 Come aggiungere un dominio

Ogni volta che aggiungi un sito al WordPress Multisite:
	1.	Apri l’addon WP Multisite SSL Manager
	2.	Inserisci:
	•	Domini (es. cliente.ch, esempio.com) separati da virgola o spazio
	•	Email per Let’s Encrypt
	3.	Conferma

L’addon esegue automaticamente:
	•	verifica accessibilità dominio
	•	generazione certificato Let’s Encrypt
	•	creazione vHost LiteSpeed dedicato
	•	associazione SSL corretta
	•	reload LiteSpeed

⏱️ Tempo medio: 20–30 secondi

⸻

🔁 Rinnovo automatico SSL

Il rinnovo è completamente automatico.
	•	certbot renew eseguito via cron
	•	tutti i certificati vengono rinnovati insieme
	•	LiteSpeed viene ricaricato solo se necessario

👉 Nessun intervento manuale richiesto

⸻

🧠 Architettura
	•	1 WordPress Multisite
	•	1 vHost LiteSpeed per dominio
	•	1 certificato SSL per dominio
	•	Supporto SNI nativo

Nessuna modifica a:
	•	wp-config.php
	•	database
	•	core WordPress

⸻

⚠️ Note importanti
	•	Il DNS del dominio deve puntare al nodo prima di eseguire l’addon
	•	Ogni dominio deve essere unico
	•	Wildcard SSL non utilizzati
	•	Compatibile con domain mapping standard

⸻

🧪 Testato su
	•	LiteSpeed + PHP LSAPI
	•	WordPress Multisite
	•	Jelastic Infomaniak
	•	Ambienti con oltre 100 domini

⸻

🔧 Estensioni future (roadmap)
	•	❌ Rimozione dominio
	•	📃 Lista domini configurati
	•	🔍 Controllo DNS automatico
	•	🧩 Aggancio automatico a wp_blogs
	•	🏷 White-label / branding aziendale

⸻

📄 Licenza

MIT
Utilizzabile, modificabile e distribuibile liberamente.

⸻

👨‍💻 Autore

Sviluppato per ticinoWEB
WordPress Multisite · Jelastic · LiteSpeed · SSL automation

	•	integrare check DNS + wp_blogs

Pronto quando vuoi 🚀
