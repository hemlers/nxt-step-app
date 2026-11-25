# NXT Step USA App

Die Spieler-App von NXT Step USA mit Pathway, Profil, Resources und Admin-Bereich.

- **Hosting:** GitHub Pages. Jede Änderung im Ordner `docs` geht nach ein, zwei Minuten automatisch live.
- **Logins, Datenbank, Fotos und Dokumente:** Supabase, Serverstandort Frankfurt.
- **Spielerkonten:** Nur Admins legen Zugänge an. Selbst registrieren kann sich niemand.

Ohne Supabase-Zugangsdaten läuft die App im Demo-Modus. Dann bleibt alles nur im jeweiligen Browser gespeichert.

---

## Ordner

```
docs/                              die App (index.html, config.js, Bilder, Icons, PWA-Dateien)
docs/config.js                     deine Supabase-Adresse und der öffentliche anon-Key
supabase/schema.sql                Tabellen, Rechte und Speicher – einmal in Supabase ausführen
supabase/functions/admin-users/    Admin-Funktion: Zugänge anlegen, Passwörter setzen, Spieler löschen
```

---

## Einrichtung (ca. 25 Minuten, einmalig)

### 1. Supabase

1. Auf [supabase.com](https://supabase.com) **New project** wählen. Region **Central EU (Frankfurt)**, Datenbank-Passwort sicher notieren.
2. **SQL Editor → New query:** den kompletten Inhalt von `supabase/schema.sql` einfügen und **Run** klicken.
3. **Authentication → Sign In / Providers:** **Allow new users to sign up** ausschalten.
4. **Edge Functions → Deploy a new function → Via Editor:** Als Namen exakt `admin-users` eintragen, den Beispielcode löschen, den kompletten Inhalt von `supabase/functions/admin-users/index.ts` einfügen und **Deploy** klicken. Den geheimen Schlüssel stellt Supabase der Funktion selbst bereit, du musst nichts eintragen.
5. **Project Settings → Data API** (Project URL) und **API Keys** (`anon` `public` key) heraussuchen. Falls dort nur `sb_publishable…` steht: Tab **Legacy API Keys**. Den `service_role` key brauchst du nicht – er darf nie in den Code oder in einen Chat.

### 2. GitHub

1. Neues Repository anlegen, zum Beispiel `nxt-step-app`. Für GitHub Pages im kostenlosen Tarif muss es **öffentlich** sein. Spielerdaten liegen nicht im Code, sondern nur in Supabase.
2. Den Inhalt dieses Ordners hochladen (**Add file → Upload files**).
3. Im Repo die Datei `docs/config.js` öffnen, auf den Stift klicken und die beiden Werte eintragen:
   ```js
   window.NXT_CONFIG = {
     supabaseUrl: 'https://DEIN-PROJEKT.supabase.co',
     supabaseAnonKey: 'eyJ…'
   };
   ```
   **Commit changes** klicken.
4. **Settings → Pages:** Bei **Source** „Deploy from a branch“, Branch `main`, Ordner **`/docs`**, **Save**. Nach ein, zwei Minuten steht oben die Adresse, z. B. `https://deinname.github.io/nxt-step-app/`.
5. Zurück in Supabase: **Authentication → URL Configuration → Site URL** auf diese Adresse setzen.

Optional eigene Domain: In **Settings → Pages → Custom domain** `app.nxtstepusa.de` eintragen und beim Domain-Anbieter einen CNAME auf `deinname.github.io` setzen. Danach die Site URL in Supabase anpassen.

### 3. Ersten Admin anlegen

1. In Supabase unter **Authentication → Users → Add user** deinen Account anlegen und **Auto Confirm User** anhaken.
2. Im **SQL Editor** diese Zeile mit deiner E-Mail ausführen:
   ```sql
   insert into public.admins (user_id) select id from auth.users where email = 'deine@email.de';
   ```
3. Für Leo machst du dasselbe.

Danach meldest du dich in der App an: In der Login-Box oben rechts auf das **Schloss** tippen, dann E-Mail und Passwort eingeben. Der Admin-Bereich öffnet sich direkt. Solange du als Admin angemeldet bist, kommst du über den Knopf **Admin** oben in der App jederzeit zurück. Spieler sehen diesen Knopf nie.

---

## Spieler anlegen

1. **Admin → Profiles → Notion-Export:** Die HTML-Dateien aus Notion hierher ziehen. Verträge als PDF kannst du gleich mit auswählen. Notion exportiert über ⋯ → Export → HTML.
   - Neue Spieler werden angelegt. Bei bestehenden werden nur leere Felder ergänzt, nichts wird überschrieben.
   - Ein „Highlights“-Link von YouTube wird automatisch zum Profilvideo.
   - Der Startschritt im Pathway richtet sich nach dem Notion-Status: „Contract Signed“ → ab „Highlights sammeln“, „Paid?“ angehakt → ab „Highlightvideo + Profil“, „Whole Process Complete“ → ab „Sprachtest“. Bitte pro Spieler kurz prüfen.
2. Den Spieler öffnen und unter **Zugang erstellen** ein Passwort festlegen. Ein sicheres Passwort ist schon vorgeschlagen. Mit **Kopieren** schickst du dem Spieler die Zugangsdaten.
3. Falls ein Export keine E-Mail enthält, zum Beispiel bei Uche, trägst du sie im Profil von Hand ein.

**Passwort vergessen:** Der Spieler meldet sich per WhatsApp oder E-Mail bei euch. Im Profil des Spielers unter **Neues Passwort festlegen** setzt ihr ein neues und schickt es ihm.

---

## Was Spieler können

- Ihren Pathway sehen, Profil und Video ansehen, alle Resources nutzen
- Sichtbare Profilfelder selbst bearbeiten. Ausgeblendete Felder sehen sie nicht und können sie nicht ändern. Das prüft auch die Datenbank selbst.
- Bis zu **7 Fotos** in Originalqualität hochladen (max. 25 MB pro Bild), vorher zuschneiden und als Galerie ansehen
- Dokumente hochladen und herunterladen, etwa Zeugnisse, Pass-Kopie oder Sprachtest
- Ihr Passwort in den Einstellungen ändern

Spieler sehen immer nur ihr eigenes Profil. Admins sehen und bearbeiten alles.

---

## Wichtig vor dem Livegang

- **Datenschutz:** Ihr speichert Kontakt- und Elterndaten. Den Auftragsverarbeitungsvertrag (DPA) von Supabase abschließen, das geht online im Dashboard. GitHub Pages liefert nur die App-Dateien aus, ohne Spielerdaten. Außerdem die Datenschutzerklärung auf nxtstepusa.de um die App ergänzen. Die Links zu Impressum und Datenschutz in den Einstellungen zeigen auf `nxtstepusa.de/impressum` und `nxtstepusa.de/datenschutz`. Falls die Seiten anders heißen, in `docs/index.html` nach „impressum“ suchen und die Links anpassen.
- **Minderjährige Spieler:** Für Spieler unter 18 die Einwilligung der Eltern zur Nutzung der App einholen.
- **Sensible Felder:** Telefon, E-Mails, Budget, Package, Paid?, Status und Ähnliches sind nach dem Import automatisch für Spieler ausgeblendet. Unter Admin → Profiles → Profilfelder kannst du das mit dem Auge-Symbol anpassen.

---

## Änderungen später

Datei in GitHub ändern und speichern („Commit“). GitHub Pages stellt die neue Version nach ein, zwei Minuten online. Ändert sich `supabase/functions/admin-users/index.ts`, den neuen Inhalt in Supabase unter **Edge Functions → admin-users → Code** einfügen und erneut deployen.
