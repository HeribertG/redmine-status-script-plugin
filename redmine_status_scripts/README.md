\# Redmine Status Scripts Plugin



Ein Redmine-Plugin, das automatisch Skripte ausführt, wenn sich der Status von Issues ändert. Unterstützt Shell-Skripte, Webhooks und Ruby-Code.



\## 🚀 Features



\- \*\*3 Script-Typen\*\*: Shell, Webhook, Ruby

\- \*\*Flexible Trigger\*\*: Von beliebigen Status zu bestimmten Status

\- \*\*Projekt-spezifisch\*\*: Globale oder projekt-spezifische Konfiguration

\- \*\*Umfassendes Logging\*\*: Alle Ausführungen werden protokolliert

\- \*\*Admin-Interface\*\*: Einfache Verwaltung über Redmine-Web-Interface

\- \*\*Sicherheit\*\*: Timeout-Behandlung und Fehlerbehandlung

\- \*\*Integration\*\*: Perfekt für externe APIs und Benachrichtigungen



\## 📋 Anforderungen



\- \*\*Redmine\*\*: Version 5.0 oder höher

\- \*\*Ruby\*\*: Version 2.7 oder höher

\- \*\*Rails\*\*: Version 6.1 oder höher



\## 🔧 Installation



\### 1. Plugin herunterladen

```bash

cd /path/to/redmine/plugins

git clone https://github.com/yourusername/redmine\_status\_scripts.git

\# oder Plugin-Verzeichnis manuell erstellen

```



\### 2. Abhängigkeiten installieren

```bash

cd /path/to/redmine

bundle install --without development test

```



\### 3. Datenbank migrieren

```bash

rake redmine:plugins:migrate RAILS\_ENV=production

```



\### 4. Redmine neustarten

```bash

\# Je nach Setup:

sudo systemctl restart redmine

\# oder

touch tmp/restart.txt

```



\## ⚙️ Konfiguration



\### Admin-Interface aufrufen

1\. Gehe zu: \*\*Administration → Status Scripts\*\*

2\. Oder direkt: `http://your-redmine/status\_scripts`



\### Erstes Script erstellen

1\. Klicke auf \*\*"Neues Status Script"\*\*

2\. Fülle die Felder aus:

&nbsp;  - \*\*Name\*\*: Beschreibender Name

&nbsp;  - \*\*Von Status\*\*: Ausgangsstatus (leer = alle)

&nbsp;  - \*\*Zu Status\*\*: Zielstatus (erforderlich)

&nbsp;  - \*\*Projekt\*\*: Spezifisches Projekt (leer = alle)

&nbsp;  - \*\*Script-Typ\*\*: Shell, Webhook oder Ruby

&nbsp;  - \*\*Script-Inhalt\*\*: Je nach Typ



\## 📝 Script-Typen



\### Shell Script

Bash-Skripte mit Zugriff auf Umgebungsvariablen:



```bash

\#!/bin/bash

echo "Issue ${REDMINE\_ISSUE\_ID} changed to ${REDMINE\_NEW\_STATUS\_NAME}"

echo "Project: ${REDMINE\_PROJECT\_NAME}"

echo "Assignee: ${REDMINE\_ASSIGNEE\_NAME}"



\# Slack-Benachrichtigung

curl -X POST -H 'Content-type: application/json' \\

&nbsp; --data "{\\"text\\":\\"🎯 Issue #${REDMINE\_ISSUE\_ID} wurde auf '${REDMINE\_NEW\_STATUS\_NAME}' gesetzt\\"}" \\

&nbsp; https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK



\# E-Mail senden

echo "Issue #${REDMINE\_ISSUE\_ID} Status: ${REDMINE\_NEW\_STATUS\_NAME}" | \\

&nbsp; mail -s "Redmine Update" admin@example.com

```



\### Webhook

HTTP POST-Request an externe APIs:



\- \*\*URL\*\*: `https://your-app.com/api/redmine-webhook`

\- \*\*Content-Type\*\*: `application/json`

\- \*\*Body\*\*: JSON mit allen Issue-Daten



```json

{

&nbsp; "issue\_id": 1234,

&nbsp; "issue\_subject": "Bug in Login",

&nbsp; "project\_name": "Webshop",

&nbsp; "old\_status\_name": "Neu",

&nbsp; "new\_status\_name": "In Bearbeitung",

&nbsp; "assignee\_name": "Max Mustermann",

&nbsp; "author\_name": "Anna Schmidt",

&nbsp; "created\_on": "2025-07-15T10:30:00Z",

&nbsp; "updated\_on": "2025-07-15T14:45:00Z"

}

```



\### Ruby Code

Ruby-Skripte mit Zugriff auf Instanzvariablen:



```ruby

\# Zugriff auf Parameter über @variablen

puts "Issue #{@issue\_id}: #{@issue\_subject}"

puts "Status: #{@old\_status\_name} → #{@new\_status\_name}"



\# E-Mail bei bestimmtem Status

if @new\_status\_name == 'Erledigt'

&nbsp; # UserMailer.issue\_completed(@issue\_id).deliver\_now

&nbsp; puts "E-Mail gesendet für Issue ##{@issue\_id}"

end



\# HTTP-Request an externe API

require 'net/http'

require 'json'



uri = URI('https://your-api.com/webhook')

http = Net::HTTP.new(uri.host, uri.port)

http.use\_ssl = true



request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')

request.body = {

&nbsp; event: 'status\_changed',

&nbsp; issue\_id: @issue\_id,

&nbsp; new\_status: @new\_status\_name,

&nbsp; project: @project\_name

}.to\_json



response = http.request(request)

puts "API Response: #{response.code}"

```



\## 🔄 Verfügbare Parameter



Alle Scripts haben Zugriff auf folgende Parameter:



| Parameter | Beschreibung | Shell | Ruby | Webhook |

|-----------|--------------|-------|------|---------|

| `issue\_id` | Issue-ID | `$REDMINE\_ISSUE\_ID` | `@issue\_id` | `issue\_id` |

| `issue\_subject` | Issue-Titel | `$REDMINE\_ISSUE\_SUBJECT` | `@issue\_subject` | `issue\_subject` |

| `project\_id` | Projekt-ID | `$REDMINE\_PROJECT\_ID` | `@project\_id` | `project\_id` |

| `project\_name` | Projekt-Name | `$REDMINE\_PROJECT\_NAME` | `@project\_name` | `project\_name` |

| `old\_status\_id` | Alter Status-ID | `$REDMINE\_OLD\_STATUS\_ID` | `@old\_status\_id` | `old\_status\_id` |

| `old\_status\_name` | Alter Status-Name | `$REDMINE\_OLD\_STATUS\_NAME` | `@old\_status\_name` | `old\_status\_name` |

| `new\_status\_id` | Neuer Status-ID | `$REDMINE\_NEW\_STATUS\_ID` | `@new\_status\_id` | `new\_status\_id` |

| `new\_status\_name` | Neuer Status-Name | `$REDMINE\_NEW\_STATUS\_NAME` | `@new\_status\_name` | `new\_status\_name` |

| `assignee\_id` | Zugewiesene Person-ID | `$REDMINE\_ASSIGNEE\_ID` | `@assignee\_id` | `assignee\_id` |

| `assignee\_name` | Zugewiesene Person-Name | `$REDMINE\_ASSIGNEE\_NAME` | `@assignee\_name` | `assignee\_name` |

| `author\_id` | Ersteller-ID | `$REDMINE\_AUTHOR\_ID` | `@author\_id` | `author\_id` |

| `author\_name` | Ersteller-Name | `$REDMINE\_AUTHOR\_NAME` | `@author\_name` | `author\_name` |

| `created\_on` | Erstellungsdatum | `$REDMINE\_CREATED\_ON` | `@created\_on` | `created\_on` |

| `updated\_on` | Änderungsdatum | `$REDMINE\_UPDATED\_ON` | `@updated\_on` | `updated\_on` |



\## 📊 Monitoring \& Logs



\### Log-Ansicht

\- \*\*Alle Ausführungen\*\* werden protokolliert

\- \*\*Erfolgreiche und fehlgeschlagene\*\* Scripts

\- \*\*Ausführungszeit\*\* und Fehlerdetails

\- \*\*Filter\*\* nach Issue, Konfiguration oder Status



\### Logs verfolgen

```bash

\# Redmine Logs anzeigen

tail -f log/production.log | grep "Status Script"



\# Plugin-spezifische Logs

grep "Status Script Error" log/production.log

```



\## 🛠️ Beispiel-Szenarien



\### 1. Slack-Benachrichtigung bei "Erledigt"

```bash

\#!/bin/bash

if \[ "$REDMINE\_NEW\_STATUS\_NAME" = "Erledigt" ]; then

&nbsp; curl -X POST -H 'Content-type: application/json' \\

&nbsp;   --data "{\\"text\\":\\"✅ Issue #${REDMINE\_ISSUE\_ID} wurde erledigt: ${REDMINE\_ISSUE\_SUBJECT}\\"}" \\

&nbsp;   https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK

fi

```



\### 2. Integration mit Angular-App

\*\*Redmine-Konfiguration:\*\*

\- Script-Typ: `Webhook`

\- URL: `https://your-angular-app.com/api/redmine-webhook`



\*\*Angular Service:\*\*

```typescript

@Injectable()

export class RedmineWebhookService {

&nbsp; constructor(private http: HttpClient) {}



&nbsp; @Post('api/redmine-webhook')

&nbsp; async handleStatusChange(@Body() data: any) {

&nbsp;   console.log(`Issue ${data.issue\_id} changed to ${data.new\_status\_name}`);

&nbsp;   

&nbsp;   // Dashboard aktualisieren

&nbsp;   await this.updateDashboard(data);

&nbsp;   

&nbsp;   // Benachrichtigungen senden

&nbsp;   if (data.new\_status\_name === 'Erledigt') {

&nbsp;     await this.sendCompletionNotification(data);

&nbsp;   }

&nbsp; }

}

```



\### 3. E-Mail-Benachrichtigung bei Zuweisung

```ruby

\# Ruby Script

if @assignee\_name \&\& @assignee\_name != @author\_name

&nbsp; # UserMailer.issue\_assigned(@issue\_id, @assignee\_name).deliver\_now

&nbsp; puts "E-Mail-Benachrichtigung an #{@assignee\_name} gesendet"

end

```



\## 🔐 Sicherheit



\### Plugin-Einstellungen

\- \*\*Timeout\*\*: Standard-Ausführungszeit (30 Sekunden)

\- \*\*Logging\*\*: Ein/Aus

\- \*\*Webhook-Domains\*\*: Nur bestimmte Domains erlauben



\### Best Practices

\- ✅ \*\*Timeouts setzen\*\* für Shell-Scripts

\- ✅ \*\*HTTPS verwenden\*\* für Webhooks

\- ✅ \*\*Eingaben validieren\*\* in Shell-Scripts

\- ✅ \*\*Exception Handling\*\* in Ruby-Scripts

\- ✅ \*\*Logs regelmäßig bereinigen\*\*



\## 🐛 Troubleshooting



\### Häufige Probleme



\*\*1. "Script wird nicht ausgeführt"\*\*

\- Prüfe ob Script aktiviert ist

\- Überprüfe Status-Übergang (von/zu)

\- Schaue in die Logs: `Administration → Status Scripts → Logs`



\*\*2. "Permission denied" bei Shell Scripts\*\*

```bash

\# Stelle sicher, dass Script ausführbar ist

chmod +x /path/to/script.sh

```



\*\*3. "Webhook timeout"\*\*

\- Erhöhe Timeout-Wert in Plugin-Einstellungen

\- Prüfe Webhook-URL: `curl -X POST https://your-webhook.com`



\*\*4. "Ruby Script Fehler"\*\*

\- Prüfe Syntax: `ruby -c script\_content.rb`

\- Schaue in Redmine-Logs: `log/production.log`



\### Debug-Modus

```bash

\# Verbose Logging aktivieren

echo "Rails.logger.level = :debug" >> config/environments/production.rb

```



\## 📦 Deinstallation



```bash

\# Migration rückgängig machen

rake redmine:plugins:migrate NAME=redmine\_status\_scripts VERSION=0 RAILS\_ENV=production



\# Plugin-Verzeichnis löschen

rm -rf plugins/redmine\_status\_scripts



\# Redmine neustarten

sudo systemctl restart redmine

```



\## 🤝 Support



\### Probleme melden

\- \*\*Issues\*\*: \[GitHub Issues](https://github.com/yourusername/redmine\_status\_scripts/issues)

\- \*\*Dokumentation\*\*: \[Wiki](https://github.com/yourusername/redmine\_status\_scripts/wiki)



\### Beitragen

1\. Fork das Repository

2\. Erstelle einen Feature-Branch

3\. Committe deine Änderungen

4\. Erstelle einen Pull Request



\## 📄 Lizenz



MIT License - siehe \[LICENSE](LICENSE) Datei für Details.



\## 📝 Changelog



\### Version 1.0.0

\- ✅ Initiale Version

\- ✅ Shell, Webhook und Ruby Script-Unterstützung

\- ✅ Admin-Interface

\- ✅ Umfassendes Logging

\- ✅ Projekt-spezifische Konfiguration



---



\*\*Entwickelt für Redmine 5+ mit ❤️\*\*

