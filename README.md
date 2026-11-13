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

Claude zoekt in Home Assistant de juiste sensoren en geeft je de instellingen. Jij doet drie dingen
zelf:

1. Een **token** maken in Home Assistant (Claude legt uit waar). Plak dat token nooit in de chat.
2. **PowerShell** openen en deze regel plakken:

   ```
   irm https://raw.githubusercontent.com/eclaassens/energie-installatie/main/installeer.ps1 | iex
   ```

3. In het **Kladblok** dat opengaat de instellingen van Claude plakken, je token achter `HA_TOKEN=`
   zetten, opslaan en sluiten.

Daarna opent de app vanzelf op http://localhost:8000. Vul bij **Beheer** de tarieven van je contract
in; Claude helpt als je een foto van je jaarnota stuurt.

**Bijwerken** naar een nieuwe versie: plak dezelfde regel nog eens in PowerShell.

## Wat er op je pc komt

- Docker Desktop (als het er nog niet is).
- De map `energie-app` in je gebruikersmap, met `docker-compose.yml` en `.env` (je instellingen en
  token; deel dat bestand niet).
- Een Docker-volume `energie_energie-data` met de database. Weghalen: in Docker Desktop de container
  `energie-app` en dat volume verwijderen.
