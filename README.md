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

🚀 Installazione

1️⃣ Pubblica il repository su GitHub

Il repository deve essere pubblico (consigliato) oppure accessibile via token.

2️⃣ Installa l’addon da Jelastic

Jelastic → Marketplace → Install from URL

https://github.com/TUO-USER/jelastic-wp-multisite-ssl/raw/main/manifest.jps

Durante l’installazione:
	•	viene preparato l’ambiente
	•	viene installato certbot
	•	viene configurato il rinnovo automatico SSL

⸻

🧩 Come aggiungere un dominio

Ogni volta che aggiungi un sito al WordPress Multisite:
	1.	Apri l’addon WP Multisite SSL Manager
	2.	Inserisci:
	•	Dominio (es. cliente.ch)
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
