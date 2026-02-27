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

```
SSL-Let-s-Encrypt-Addon-per-Jelastic/
├── manifest.jps                     # Entry point Jelastic
├── scripts/
│   ├── install-base.sh              # Setup iniziale (certbot + cron)
│   ├── add-domain.sh                # Provisioning dominio + SSL
│   ├── remove-domain.sh             # Rimozione dominio
│   ├── list-domains.sh              # Lista domini configurati
│   ├── renew-now.sh                 # Rinnovo manuale immediato
│   ├── renew-status.sh              # Stato ultimo rinnovo
│   ├── reapply-ssl.sh               # Riapplica SSL esistente
│   └── uninstall-addon.sh           # Disinstallazione completa
├── templates/
│   └── litespeed-vhost.xml          # Template vHost LiteSpeed 6.x
└── .github/
    └── copilot-instructions.md      # Documentazione tecnica
```


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
	•	Stato rinnovo
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

**WordPress Multisite**
	•	1 WordPress Multisite
	•	1 vHost LiteSpeed per dominio
	•	1 certificato SSL per dominio
	•	Supporto SNI nativo

Nessuna modifica a:
	•	wp-config.php
	•	database
	•	core WordPress

**Struttura Server LiteSpeed 6.x**

```
/var/www/
├── webroot/ROOT/                    # Document root WordPress
├── conf/
│   ├── httpd_config.xml             # Config principale LiteSpeed
│   └── vhosts/                      # Virtual hosts
│       ├── domain1.com/
│       │   └── vhconf.xml           # vHost config XML
│       ├── domain2.com/
│       │   └── vhconf.xml
│       └── ...
└── logs/

/etc/letsencrypt/
├── live/                            # Certificati attivi
│   ├── domain1.com/
│   │   ├── cert.pem
│   │   ├── chain.pem
│   │   ├── fullchain.pem
│   │   └── privkey.pem
│   └── ...
├── archive/                         # Storico certificati
└── renewal/                         # Config rinnovo

/var/log/
└── wp-multisite-ssl-manager.log     # Log addon
```

**Formato vHost (LiteSpeed 6.x XML)**

⚠️ **IMPORTANTE**: LiteSpeed 6.x richiede formato **XML**, non plain text.

Il template [templates/litespeed-vhost.xml](templates/litespeed-vhost.xml) contiene:
	•	Configurazione index files (index.html, index.php)
	•	Supporto .htaccess per WordPress
	•	Rewrite rules per permalink
	•	SSL/TLS settings (certificato Let's Encrypt)
	•	Docroot condiviso con WordPress Multisite

**SNI (Server Name Indication)**

⚠️ **CRITICO**: Nel file `/var/www/conf/httpd_config.xml`, i mapping specifici dei domini **devono apparire PRIMA** del mapping wildcard (*) nei listener HTTPS.

Ordine corretto:
```xml
<listener>
  <name>HTTPS</name>
  <vhostMap>
    <map vhost="domain1.com" domains="domain1.com"/>  ← specifico
    <map vhost="domain2.com" domains="domain2.com"/>  ← specifico
    <map vhost="*" domains="*"/>                     ← wildcard (ULTIMO)
  </vhostMap>
</listener>
```

Se il wildcard è prima, SNI non funziona e i certificati non vengono serviti correttamente.

⸻

🔧 Troubleshooting

**Il browser mostra "Not Secure" nonostante il certificato sia installato**
	1.	Verifica che il vHost sia in formato XML (non .conf)
	2.	Controlla l'ordine dei mapping SNI nel listener HTTPS
	3.	Verifica il CN del certificato: `echo | openssl s_client -servername DOMAIN -connect DOMAIN:443 2>/dev/null | openssl x509 -noout -subject`

**Errore "syntax error" in vhconf.conf**
	→ LiteSpeed 6.x richiede formato XML, non plain text. Usa il template `litespeed-vhost.xml`.

**HTTP 403 Forbidden dopo configurazione SSL**
	→ Manca configurazione index files o .htaccess support nel vHost XML.

**WordPress backend: "risposta non è JSON valida"**
	→ Rewrite rules mancanti nel vHost XML. Verifica sezione `<rewrite>` nel template.

**Log addon**
```bash
tail -f /var/log/wp-multisite-ssl-manager.log
```

**Verifica certificato attivo**
```bash
openssl x509 -in /etc/letsencrypt/live/DOMAIN/cert.pem -noout -dates -subject
```

**Reload manuale LiteSpeed**
```bash
systemctl reload lsws
```

⸻

⚠️ Note importanti
	•	Il DNS del dominio deve puntare al nodo prima di eseguire l’addon
	•	Ogni dominio deve essere unico
	•	Wildcard SSL non utilizzati
	•	Compatibile con domain mapping standard

⸻

🧪 Testato su
	•	LiteSpeed 6.3.4 Enterprise
	•	PHP 8.x LSAPI
	•	WordPress 6.x Multisite (subdomain + domain mapping)
	•	Jelastic Infomaniak (CentOS/RHEL)
	•	certbot 2.x + Let's Encrypt ACME v2
	•	Ambienti production con decine di domini attivi

⸻

🔧 Roadmap

**Completate** ✅
	•	✅ Rimozione dominio
	•	✅ Lista domini configurati (con scadenza certificati)
	•	✅ Rinnovo manuale immediato
	•	✅ Stato ultimo rinnovo
	•	✅ Logging con timestamp
	•	✅ Supporto domini multipli (comma-separated)
	•	✅ Icona personalizzata addon

**Future**
	•	🔍 Controllo DNS automatico pre-provisioning
	•	🧩 Integrazione wp_blogs (auto-detect nuovi siti)
	•	🏷 White-label / branding aziendale
	•	🔔 Notifiche email scadenza certificati
	•	📊 Dashboard riepilogo stato SSL

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
