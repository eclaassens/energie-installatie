# Energie-app installeren

Een app die je verbruik uit Home Assistant haalt en uitrekent wat een ander energiecontract, een
thuisaccu of meer zonnepanelen je zouden opleveren. Hij draait op je eigen Windows-pc; er gaat niets
naar buiten behalve naar je eigen Home Assistant.

## Wat je nodig hebt

- Een Windows-pc (Windows 10 of 11, Intel of AMD) met ongeveer 2 GB vrij geheugen.
- Home Assistant met een slimme meter (P1) erin.
- Claude, gekoppeld aan je Home Assistant.

## Zo werkt het

Begin een nieuw gesprek met Claude en zeg:

> Lees https://github.com/eclaassens/energie-installatie/blob/main/INSTRUCTIE-VOOR-CLAUDE.md
> en help me de energie-app te installeren.

Lukt het lezen van de link niet, download dan [INSTRUCTIE-VOOR-CLAUDE.md](INSTRUCTIE-VOOR-CLAUDE.md)
en sleep het bestand in het gesprek.

Claude zoekt in Home Assistant de juiste sensoren en geeft je de instellingen. Jij doet vier dingen
zelf:

1. Een **token** maken in Home Assistant (Claude legt uit waar). Plak dat token nooit in de chat.
2. **PowerShell** openen en deze regel plakken:

   ```
   irm https://raw.githubusercontent.com/eclaassens/energie-installatie/main/installeer.ps1 | iex
   ```

3. In het **Kladblok** dat opengaat de regels van Claude plakken (alleen de verbinding met Home
   Assistant), je token achter `HA_TOKEN=` zetten, opslaan en sluiten. Wil je de tarieven ook in Home
   Assistant (MQTT), dan typ je daar ook het wachtwoord van de HA-gebruiker achter `MQTT_PASSWORD=`.
4. In de app, die vanzelf opent op http://localhost:8000, bij **Beheer**: onder **Sensoren** per meting de
   sensor kiezen die Claude noemt, onder **Instellingen** je zonnepanelen en gascorrectie, en onder
   **Tarieven** je contract (Claude helpt als je een foto van je jaarnota stuurt).

**Bijwerken** naar een nieuwe versie: plak dezelfde regel nog eens in PowerShell. Daarmee pas je ook de
verbinding aan (kies "j" bij de vraag om ze aan te passen); sensoren en instellingen wijzig je in de app.

**Een aanbod vergelijken**: gebruik je Claude Code of de Code-tab van de Claude-app, stuur Claude dan een screenshot
van een aanbod op gaslicht.com (klap eerst **Prijsdetails** open), of log in de ingebouwde browser zelf in op
gaslicht.com en vraag "haal het aanbod van vandaag op". Claude zet het in de app en zegt wat overstappen per jaar
scheelt. Een aanbod is één dag geldig.

## Wat er op je pc komt

- Docker Desktop (als het er nog niet is).
- De map `energie-app` in je gebruikersmap, met `docker-compose.yml` en `.env` (de verbinding met Home
  Assistant: token en eventueel MQTT-wachtwoord; deel dat bestand niet).
- De Claude-skill `energie-aanbod` in `.claude\skills` in je gebruikersmap (voor Claude Code en de Code-tab).
- Een Docker-volume `energie_energie-data` met de database. Weghalen: in Docker Desktop de container
  `energie-app` en dat volume verwijderen.
