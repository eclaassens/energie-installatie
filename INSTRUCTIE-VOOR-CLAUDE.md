# Instructie voor Claude: de energie-app installeren

Je helpt iemand de energie-app te installeren op een Windows-pc. De app haalt meterstanden en
temperaturen uit Home Assistant (HA) en helpt bij drie keuzes: energiecontract, thuisaccu en
zonnepanelen. Hij draait als Docker-container op http://localhost:8000.

Jij hebt toegang tot HA via de Home Assistant-MCP (ha-mcp: tools als `ha_get_overview`,
`ha_manage_energy_prefs`, `ha_search`, `ha_get_state`, `ha_get_entity`, `ha_get_device`,
`ha_eval_template`, `ha_config_set_helper`). Je kunt geen opdrachten op de pc uitvoeren: dat doet de
gebruiker met één regel in PowerShell.

## Spelregels

- Schrijf Nederlands, kort en zonder vakjargon; de gebruiker is geen programmeur. Eén stap tegelijk.
- **Vraag nooit om het HA-token en laat het nooit in de chat plakken.** De gebruiker zet het zelf in
  het instellingenbestand (`.env`). Krijg je het toch, zeg dan dat hij het in HA moet intrekken en een nieuw maken.
  Hetzelfde geldt voor het MQTT-wachtwoord (stap 4b): dat typt hij zelf in Kladblok.
- Verander niets in HA zonder het eerst te vragen. Alleen lezen mag altijd. Het enige wat je eventueel
  aanmaakt zijn de hulpsensoren (helpers) uit stap 3, na een "ja". Verwijder nooit iets.
- Gok niet: weet je niet welke sensor het is, laat de gebruiker kiezen uit wat je vond.
- Het instellingenbestand bevat alleen de verbinding met HA (en eventueel MQTT). Welke sensor bij welke meting hoort,
  het vermogen van de panelen en de gascorrectie kiest de gebruiker in de app zelf, bij **Beheer** (stap 7). Jij zoekt
  ze nu op, zodat je hem daar per veld kunt zeggen wat hij kiest.

## Stap 1: HA bekijken

1. `ha_get_overview` (minimal): HA-versie en of de koppeling werkt.
2. `ha_manage_energy_prefs(mode="get", include_statistics=true)`: het energiedashboard. Daar staan meestal
   de meterstanden al:
   - `energy_sources` type `grid`: `stat_energy_from` = afname, `stat_energy_to` = teruglevering. In
     Nederland zijn het er twee: **tarief 1 = dal** (laag), **tarief 2 = normaal** (hoog). Controleer aan
     de naam (`tariff_1`/`tarief_1`/`low` → dal).
   - type `gas`: `stat_energy_from` = de gasmeter (m³).
   - type `solar`: de opbrengst van de panelen (kWh); de app wil het **vermogen** (zie hieronder).
3. Staat het energiedashboard niet ingesteld: zoek met `ha_search` naar de slimme-meterkoppeling (DSMR,
   HomeWizard P1, SlimmeLezer/ESPHome, P1 Monitor) en neem daar de sensoren van.

## Stap 2: de sensoren opzoeken

De app wil deze metingen. Lees van elke kandidaat de state en attributen (`ha_get_state`). Noteer per meting de
**naam** (friendly_name) én de entity-id: in de app kiest de gebruiker uit een keuzelijst met "naam · entity-id ·
stand", en die lijst toont alleen sensoren met de juiste eenheid.

| In de app (Beheer → Sensoren) | Wat | Eisen |
|---|---|---|
| Stroom dal (T1) / Stroom normaal (T2) | meterstand afname dal / normaal | kWh, `state_class` total_increasing |
| Teruglevering dal (T1) / normaal (T2) | meterstand teruglevering dal / normaal | kWh, total_increasing; geen panelen → geen |
| Gas meterstand | meterstand gas | m³, total_increasing; geen gas → geen |
| Netafname vermogen / Teruglevering vermogen | vermogen nu, afname en teruglevering apart | W of kW, `state_class` measurement, allebei ≥ 0 |
| Zonnepanelen vermogen | vermogen van de panelen nu | W of kW, measurement; geen panelen → geen |
| Buitentemperatuur | buitentemperatuur | °C, measurement |
| Binnentemperatuur | binnentemperatuur (woonkamer/thermostaat) | °C, measurement |
| Thuisaccu geladen / ontladen | thuisaccu: energie erin / eruit | kWh, total_increasing; geen accu → geen |
| Thuisaccu laadtoestand | thuisaccu: laadtoestand | %, measurement |

En bij **Beheer → Instellingen**:

| In de app | Wat |
|---|---|
| Zonnepanelen (kWp) | piekvermogen: vraag aantal panelen × wattpiek ÷ 1000; geen panelen → leeg |
| Gascorrectie | factor waarmee de leverancier de gemeten m³ omrekent, zie hieronder |

Waar je ze vindt:
- **Vermogen afname/teruglevering**: op hetzelfde apparaat als de meterstanden (`ha_get_device`), bv.
  "Power consumption" en "Power production". Heeft de meter één vermogen dat negatief wordt bij
  teruglevering (bv. HomeWizard "Actief vermogen"), maak dan in stap 3 twee hulpsensoren.
- **Panelen**: op het apparaat van de `solar`-sensor uit het energiedashboard (omvormer, bv. Enphase
  "current power production", SolarEdge "current power"). Alleen een kWh-teller? Dan in stap 3 een helper.
- **Buiten**: een echte buitensensor (eigen weerstation) gaat voor. Anders een weerdienst die een
  temperatuursensor heeft, bv. Buienradar (`sensor.buienradar_temperature`, het dichtstbijzijnde KNMI-station).
  Alleen `weather.*` (bv. `weather.forecast_home`)? Die heeft de temperatuur alleen als attribuut, dus dan in stap 3
  een helper. Liever niet: de buitentemperatuur van een thermostaat via een cloudkoppeling (die kan verdwijnen, zoals
  de Honeywell Lyric in november 2026) of het buitendeel van een airco (hele graden, en warmer als hij draait).
- **Binnen**: een temperatuursensor in de woonkamer, of de `current_temperature` van de thermostaat
  (`climate.*`; dan een helper).
- **Thuisaccu** (bv. HomeWizard Plug-In Battery, model HWE-BAT): op het apparaat van de accu de tellers
  "Energie import" (= laden) en "Energie export" (= ontladen) en "Laadtoestand". Meer accu's: in de app met
  **nog een accu** een tweede keuzelijst erbij, bij geladen, ontladen en laadtoestand steeds in dezelfde volgorde. Staat de accu in het energiedashboard (type `battery`),
  dan zijn `stat_energy_to` (laden) en `stat_energy_from` (ontladen) dezelfde tellers. Andere merken (Marstek,
  Anker Solix, …) werken net zo, als er kWh-tellers zijn. Heeft de integratie alleen een vermogen (W), maak dan in
  stap 3 de tellers met een helper.

**Gascorrectie**: de leverancier rekent niet met de m³ van de meter, maar met een gecorrigeerd volume. De factor
staat op de jaarnota bij gas ("correctiefactor", of gecorrigeerd verbruik ÷ gemeten verbruik, bv. 1.022). Vraag om
de jaarnota en reken hem uit; vind je hem niet, of geen gas: `1`. Laat hem in de app niet op de beginwaarde 1,022 staan:
dat is de factor van een ander huishouden.

Een sensor moet al langer bestaan om de geschiedenis te hebben: de app haalt de uurstatistiek van HA op,
jaren terug. Een nieuwe helper begint vandaag. Zeg dat erbij. (Vervang je later in Beheer een sensor door een andere,
dan gaat de geschiedenis van de oude mee; zie stap 7, "Een sensor vervangen".)

## Stap 3: hulpsensoren (alleen als het nodig is, na een "ja")

Gebruik `ha_config_set_helper(helper_type="template", menu_choice="sensor", config={...})`. Lees bij
twijfel eerst het formulier (zonder config) en vul de velden zoals HA ze noemt. Altijd een eenheid,
`device_class` en `state_class` "measurement", anders bewaart HA geen statistiek.

- **Buiten uit het weer**: name "Buitentemperatuur", eenheid °C, device_class temperature, state:
  ```
  {{ state_attr('weather.forecast_home', 'temperature') }}
  ```
- **Binnen uit de thermostaat**: name "Binnentemperatuur", eenheid °C, device_class temperature, state:
  ```
  {{ state_attr('climate.NAAM', 'current_temperature') }}
  ```
- **Afname en teruglevering uit één vermogen** (negatief = teruglevering): twee helpers, device_class
  power, state:
  ```
  {{ [states('sensor.VERMOGEN') | float(0), 0] | max }}
  ```
  ```
  {{ [-(states('sensor.VERMOGEN') | float(0)), 0] | max }}
  ```

Vervang NAAM, VERMOGEN en de weer-entity (`weather.forecast_home`, `weather.buienradar`, …) door de echte
entity-id's en test elke template eerst met `ha_eval_template`.

- **Accu met alleen een vermogen**: helper `integration` (Integraal, Riemann-som, methode links), bron het
  laadvermogen, eenheidsprefix k, tijdseenheid uur → kWh-teller "Accu geladen"; net zo voor het ontlaadvermogen.
  Is er één vermogen dat negatief wordt bij ontladen (of juist bij laden: kijk naar de staat tijdens het laden), maak
  dan eerst de twee template-sensoren hierboven (positief en negatief deel) en daarna de twee integralen. Zulke
  tellers beginnen vandaag; voor een nieuwe accu is dat geen bezwaar.

Neem de eenheid van het bronvermogen over (kW of W). Voor panelen met alleen een kWh-teller: helper
`derivative`, bron de kWh-teller, tijdseenheid uur, eenheidsprefix k: dat geeft kW. Controleer daarna
met `ha_get_state` dat de nieuwe sensor een getal toont, en gebruik zijn entity-id.

## Stap 4: het adres van HA

`HA_URL` is het adres waarmee **de Windows-pc** HA bereikt. Gebruik bij voorkeur het IP-adres op het
thuisnetwerk met poort, bv. `http://192.168.1.20:8123` (`ha_get_overview` → base_url, of vraag het
adres dat de gebruiker in zijn browser gebruikt). Niet `homeassistant.local`: Docker kan dat vaak niet
vinden. Een https-adres van buitenaf (Nabu Casa, DuckDNS) werkt ook.

## Stap 4b: tarieven en prijzen naar HA via MQTT (optioneel)

Met MQTT zet de app de tarieven van het contract en de sync-status als sensoren in HA (apparaat
"Energiecontract", `sensor.energiecontract_*`), bv. voor de kosten in het energiedashboard. Ook de prijs per uur
met het eigen contract, vandaag en morgen: `sensor.energiecontract_stroomprijs` en `_terugleverprijs`. Daarmee kan
HA zelf kiezen wanneer de auto of een thuisaccu laadt (zie stap 7). Zonder MQTT werkt
de app ook; vraag of hij dit wil. Nee of twijfel: `MQTT_HOST`, `MQTT_USER` en `MQTT_PASSWORD` blijven leeg.

Wil hij het:
1. Controleer dat er een broker is: de integratie `mqtt` (`ha_get_integration`) en meestal de add-on
   Mosquitto broker. Geen van beide: laat MQTT dan weg (installeren van een add-on hoort niet bij deze klus).
2. `MQTT_HOST` = het IP-adres van HA uit stap 4, zonder `http://` en zonder poort (de add-on luistert op 1883).
3. **Mosquitto laat niemand toe zonder login.** Zonder `MQTT_USER`/`MQTT_PASSWORD` meldt de app "de broker
   weigert de verbinding". Laat hem een aparte HA-gebruiker maken: Instellingen → Personen → **Persoon
   toevoegen**, naam "energie-app", **Mag inloggen** aan, gebruikersnaam `energie-app`, een wachtwoord,
   **Alleen lokaal inloggen** aan, géén beheerder. `MQTT_USER=energie-app`; het wachtwoord typt hij zelf in
   Kladblok achter `MQTT_PASSWORD=` (nooit in de chat).

## Stap 5: het instellingenbestand

Geef de gebruiker het hele bestand in één codeblok. Het bevat alleen de verbinding; het token blijft leeg. Zonder
MQTT blijven de drie MQTT-regels leeg.

```
HA_URL=http://192.168.1.20:8123
HA_TOKEN=
MQTT_HOST=
MQTT_USER=
MQTT_PASSWORD=
```

Heeft hij een **dynamisch contract** en wil hij de werkelijke prijzen van zijn leverancier (stap 7, Tarieven), dan
komt er een regel `ENEVER_TOKEN=` bij. Dat token maakt hij zelf, gratis, op https://enever.nl/token-aanmaken/ (alleen
voor persoonlijk gebruik; de app blijft ruim onder de 250 verzoeken per maand). Ook dat typt hij zelf in Kladblok,
nooit in de chat. Geen dynamisch contract of twijfel: weglaten, het kan later altijd nog.

Leg dan uit hoe hij een token maakt: in HA linksonder op zijn naam (profiel) → tabblad **Beveiliging**
→ onderaan **Langlevende toegangstokens** → **Token aanmaken**, naam "energie-app" → kopiëren. Het
token is maar één keer te zien; hij plakt het straks in Kladblok achter `HA_TOKEN=`. Met MQTT typt hij daar ook
het wachtwoord van de HA-gebruiker achter `MQTT_PASSWORD=`.

## Stap 6: installeren op de pc

Laat de gebruiker **PowerShell** openen (Start → typ "PowerShell" → Enter; geen beheerder nodig) en
deze regel plakken:

```
irm https://raw.githubusercontent.com/eclaassens/energie-installatie/main/installeer.ps1 | iex
```

Het script:
1. Controleert Docker Desktop en biedt aan het te installeren. Daarna: pc herstarten, Docker Desktop
   openen, voorwaarden accepteren (inloggen hoeft niet), en de regel opnieuw plakken.
2. Opent Kladblok: alles vervangen door jouw codeblok, het token achter `HA_TOKEN=` plakken (en met MQTT
   het wachtwoord achter `MQTT_PASSWORD=`), opslaan, Kladblok sluiten.
3. Test de verbinding met HA, haalt de app op en opent http://localhost:8000.

Meldingen van het script en wat je dan doet:

| Melding | Oplossing |
|---|---|
| "weigert het token (401)" | nieuw token maken, regel opnieuw plakken, kiezen voor aanpassen |
| "niet bereikbaar vanaf deze pc" | HA_URL controleren (IP, poort 8123, http of https) |
| "Docker draait niet" | Docker Desktop openen en wachten op "Engine running" |
| Docker Desktop vraagt om WSL of virtualisatie | de aanwijzing van Docker Desktop volgen (soms een Windows-update of herstart) |
| "MQTT_HOST staat aan, maar MQTT_USER is leeg" | de HA-gebruiker uit stap 4b maken en invullen, of MQTT_HOST leeg maken |

Instellingen later aanpassen (bv. MQTT): dezelfde regel in PowerShell nog eens plakken en kiezen voor
aanpassen. Het script start de app daarna opnieuw met de nieuwe instellingen.

## Stap 7: na de installatie

Beheer (rechtsboven, of onderaan op een telefoon) heeft vijf onderdelen: Status, Tarieven, Instellingen, Sensoren en
Data. Loop ze met de gebruiker door, in deze volgorde:

1. **Beheer → Sensoren**: per meting de sensor uit stap 2 kiezen in de keuzelijst; een meting die hij niet heeft op
   **— geen —**. Bij een nieuwe installatie staat alles nog op **— geen —**; tot er sensoren gekozen zijn, meet de
   app niets. Staat er bij een oudere installatie iets met "(niet in HA)" achter, dan bestaat die sensor niet in
   deze HA: kies de goede of **— geen —**. Daarna **Bewaren**. De app verbindt dan opnieuw met HA en haalt jaren aan
   uurstatistiek op; dat duurt een paar minuten. Onder elke sensor staat daarna tot wanneer er uurwaarden en minuten
   zijn. Lukt de keuzelijst niet (HA even onbereikbaar), dan zijn het tekstvakken: typ dan de entity-id.
   **Beheer → Instellingen**: zonnepanelen (kWp) en gascorrectie uit stap 2, **Bewaren**.
2. **Tarieven**: Nu vraagt eerst om de tarieven van het huidige contract, bij Beheer → Tarieven. Vraag de gebruiker
   om een foto of schermafbeelding van zijn jaarnota of contractbevestiging en vertel per veld wat hij
   invult:

   | Veld | Eenheid | Let op |
   |---|---|---|
   | Normaaltarief, daltarief | €/kWh | leveringstarief **incl.** energiebelasting en btw; één tarief → beide hetzelfde |
   | Gastarief | €/m³ | incl. energiebelasting en btw |
   | Terugleverkosten / terugleververgoeding | €/kWh | 0 als het contract ze niet heeft |
   | Vaste leveringskosten stroom / gas | €/jaar | maandbedrag × 12 |
   | Netbeheerkosten stroom / gas | €/jaar | maandbedrag × 12 |
   | Vermindering energiebelasting | €/jaar | als **positief** bedrag |
   | Contractkorting | €/jaar | welkomstkorting e.d., anders 0 |

   "Geldig vanaf" staat standaard op de eerste dag met meetgegevens; laat dat zo. Een nieuw contract
   komt later als nieuwe periode (Beheer → Tarieven → **Nieuwe periode**; een periode wijzigen of verwijderen:
   **Bekijken** op die rij). Heeft hij oudere jaarnota's (zeker met historie uit stap 8), dan rekent de app vroegere
   jaren anders met de prijzen van nu. Voeg dan elk contract, ook het huidige, toe als nieuwe periode met zijn eigen
   startdatum; de volgorde maakt niet uit (de periode waarin die datum valt, loopt tot de dag ervoor). Zet daarna in de
   eerste periode (Bekijken) de tarieven van het contract dat gold op de eerste dag met meetgegevens.

   **Aangekondigde prijswijziging** (mail of brief van de leverancier met nieuwe tarieven vanaf een datum): voeg
   die meteen toe als nieuwe periode met die datum als "Geldig vanaf", ook als die datum nog moet komen. Tot die dag
   rekent de app, en krijgt HA via MQTT, gewoon het tarief van vandaag; bij Contract staat dan "jij: … , vanaf
   <datum> …". Alleen de vooruitblik (blijven zitten volgend jaar) rekent al met de nieuwe prijzen. Staan er twee
   wijzigingen in één mail (bv. per 1 december en per 1 januari), voeg dan beide toe.

   **Dynamisch contract** (prijs per uur): kies in het venster **Dynamisch**. Dan vult hij geen prijzen per kWh en m³
   in, maar de **opslag** van de leverancier op de marktprijs (stroom, gas) en de **inhouding** op teruglevering (vaak
   0). Vaste kosten, netbeheer en de vermindering energiebelasting blijven zoals in de tabel. Wil hij de prijzen die
   zijn leverancier werkelijk rekent (inclusief afronding en belasting), kies dan bij **Prijzen van de leverancier
   (enever.nl)** zijn leverancier. Dat werkt alleen met een eigen, gratis token van enever.nl (zie stap 5);
   zonder token rekent de app gewoon met markt + opslag. Achter sommige namen staat "(alleen stroom)" of
   "(alleen gas)": enever heeft voor die leverancier maar één van de twee prijzen, en de andere rekent de app met
   markt + opslag. Vul de opslagen dus altijd in. Teruglevering is altijd markt − inhouding (daar heeft enever geen
   prijs voor). De app werkt met prijzen per uur; rekent de leverancier per kwartier, dan is dat een benadering.
3. **Thuisaccu**: met de accusensoren staat bij Verbruik een tabblad **Accu**: geladen, ontladen, rendement,
   laadtoestand en wat de accu oplevert met en zonder saldering. Op Nu gaat de accuvraag dan over een accu erbij.
   Bij Verbruik → Stroom laat **Eigen verbruik** zien wat het huis gebruikte: van het net, rechtstreeks van de zon
   en (met accusensoren) uit de accu.
   **Reken met marktprijzen** (op Nu, Contract en Accu; één keuze voor de hele app): "zoals nu" rekent een dynamisch
   contract op het niveau van de laatste 30 dagen, zoals een vast aanbod van vandaag geprijsd is; "van het afgelopen
   jaar" laat zien waar je uitkomt als de markt terugzakt. Vaste tarieven veranderen niet mee. Na een periode met hoge
   prijzen lopen die ver uiteen; noem beide en zeg op welke basis een bedrag staat.
4. **Aanbiedingen** (wat overstappen scheelt): dat kan de gebruiker zonder Claude, in de app. Wijs hem op
   **Contract → Aanbod vastleggen**:
   - **Bladwijzerknop**: onder Aanbod vastleggen staat "Knop voor je browser" met de knop **→ Energie-app**. Laat hem die
     naar de bladwijzerbalk van zijn browser slepen (bladwijzerbalk tonen: Ctrl+Shift+B). Op gaslicht.com opent hij bij
     een aanbod **Hoe is dit bedrag opgebouwd?** en klikt de bladwijzer: de app opent met het aanbod ingevuld, hij kijkt
     het na en klikt **Vastleggen**.
   - **Plakken**: werkt de knop niet, dan kopieert hij die pagina (Ctrl+A, Ctrl+C) en plakt hem bovenaan het venster
     Aanbod vastleggen.
   - Doe het voor het goedkoopste vaste en het goedkoopste dynamische aanbod; op **Nu** staat wat ze per jaar schelen.
     Een aanbod is één dag geldig.
   Het installatiescript zet ook de Claude-skill `energie-aanbod` neer (in `.claude\skills` in de gebruikersmap), voor wie
   het liever via Claude doet.
5. **MQTT** (als het aan staat): bij Beheer → Status → Home Assistant (MQTT) op **Nu publiceren** en dan **Vergelijk met
   wat HA nu heeft**: alle berichten gelijk. In HA verschijnt het apparaat "Energiecontract".

   **Laden op goedkope uren** (auto, thuisaccu): die keuze maakt HA zelf, de app levert de prijzen.
   `sensor.energiecontract_stroomprijs` is de prijs van dit uur met het contract van de gebruiker: bij een vast
   contract dal of normaal volgens de meter, bij een dynamisch contract de day-ahead + opslag + energiebelasting.
   `sensor.energiecontract_terugleverprijs` is wat een teruggeleverde kWh oplevert, zonder saldering (die stopt op
   1-1-2027). In de attributen staan alle uren van vandaag en morgen (morgen vanaf ongeveer 13:00) in dezelfde vorm
   als de Nordpool-integratie: `today`, `tomorrow`, `raw_today`/`raw_tomorrow` met `start`, `end` en `value`, en
   `tomorrow_valid`. De macro *cheapest energy hours* (HACS) en de meeste prijsgrafieken lezen dat zonder
   omrekenen. Bouw zo'n automatisering alleen als de gebruiker erom vraagt, en na een "ja" op het voorstel. Een
   voorbeeld voor de auto: een template-binary-sensor die aan staat als dit uur bij de N goedkoopste uren van
   `raw_today` hoort (gelijke prijzen tellen allemaal mee, dus bij een vast contract precies de daluren). De vroegere
   `binary_sensor.energiecontract_goedkoop_uur` bestaat sinds 17-11-2026 niet meer; de app haalt hem bij het
   opstarten uit HA. Gebruikt een automatisering hem nog, zet die dan om naar zo'n eigen sensor.

   Meldingen:

   | Melding | Oplossing |
   |---|---|
   | "weigert de verbinding … MQTT_USER en MQTT_PASSWORD ontbreken" | HA-gebruiker maken (stap 4b), invullen via het script |
   | "weigert gebruiker … klopt niet" | gebruikersnaam of wachtwoord nakijken; de gebruiker moet bestaan en mag niet uitgeschakeld zijn |
   | "geen antwoord van de broker" of "kan niet publiceren naar …" | draait de Mosquitto-add-on? klopt het IP-adres (zonder http en poort)? |
5. **Maandbedrag** (op Nu): het termijnbedrag en de startdatum van het afrekenjaar, van de jaarnota.
6. **Bijwerken**: dezelfde regel in PowerShell nog eens plakken en op de vraag om de instellingen aan te passen
   Enter geven. De gegevens blijven bewaard. De app kijkt elke 6 uur of er een nieuwe versie is en toont dan bovenin
   een melding met deze regel; Beheer → Status → **Versie** laat zien welke versie draait. (Een installatie van vóór
   16 november 2026 kent die melding nog niet: één keer zo bijwerken, daarna wel.)
   Een oudere installatie heeft de sensoren, `PV_KWP` en `GAS_CORRECTIE` nog in `.env`. Dat blijft werken: Beheer toont
   die waarden. Wijzigen gaat voortaan in Beheer (dat gaat voor `.env`); de oude regels mogen blijven staan.
7. **Een sensor vervangen**: verdwijnt een gekozen sensor uit HA (integratie weg, hernoemd), dan meldt de app dat na
   de volgende sync: de stip bovenin wordt oranje ("Niet meer in Home Assistant: …"), Beheer → Status heeft een kaart
   met een link, en bij Beheer → Sensoren staat het onder die sensor. Zoek dan met de gebruiker een opvolger (stap 2)
   en kies die bij Sensoren. De nieuwe sensor krijgt de geschiedenis van de oude van vóór zijn eigen begin; de
   dagcijfers worden daarna opnieuw berekend. Hetzelfde bij een nieuwe P1-koppeling of slimme meter. Bij de thuisaccu
   gaat er niets mee: een andere sensor is daar een andere accu.

## Stap 8: oudere verbruikshistorie (optioneel)

De app begint bij de eerste dag met meterstanden in HA. Heeft de gebruiker oudere cijfers (export van
mijnenergiedata.nl / slimmemeterportal, de leverancier, een spreadsheet met meterstanden), dan kunnen die erbij
via de importmap. **Het formaat bepaalt waar het terechtkomt; alleen deze twee tellen mee in de dagcijfers:**

| Kolommen | Wat | Telt mee in |
|---|---|---|
| `ts,afname_dal,afname_normaal,terug_dal,terug_normaal` | stroom: **verbruik** in kWh per interval (kwartier, uur of dag) | Verbruik, Kosten, Nu |
| `ts,gas` | gas: **verbruik** in m³ per interval (uur of dag) | idem |
| `entity_id,ts,value` | minuutdata van één sensor (herstel van gaten) | alleen de minuutgrafiek van een dag, **niet** de dagcijfers |

Regels:
- **Verbruik, geen meterstanden**: het verschil tussen twee opeenvolgende standen. Een stand van 00:00 op dag D
  is het begin van dag D.
- **Alle kolommen gevuld**, anders valt de rij weg. Geen teruglevering → `0`. Dal én normaal zijn nodig; met alleen
  één tarief ontbreekt de helft.
- **`ts` met tijdzone**. Voor dagcijfers: 12:00 Nederlandse tijd, bv. `2022-01-01T12:00:00+01:00` (zomer `+02:00`);
  dan valt de rij nooit op een andere dag (gas schuift de app 2 uur op).
- Een **dag met een stroom- of gasmeterstand in HA gebruikt altijd HA**; de import vult alle andere dagen. Alleen de
  meterstanden uit stap 2 (Beheer → Sensoren) tellen (afname, teruglevering, gas). Een dag waarop HA alleen temperatuur heeft (bv. een
  thermostaat die al langer in HA zit) krijgt de historie en houdt die temperatuur. Er is geen ondergrens om te
  verleggen: oudere dagen komen er vanzelf voor.
- **0,0 met bron Home Assistant** bij Beheer → Data betekent: voor die dag is nog geen historie ingelezen (de dag bestaat
  door bv. de temperatuur). Het is geen teken dat de import geweigerd wordt; lees die periode gewoon in.
- **Sluit de periodes aan** tot de eerste dag met een HA-meterstand (`ha_get_history` of de statistiek van de
  meter-sensoren). Een bestand dat een paar dagen doorloopt in de HA-periode kan geen kwaad: die dagen houden HA.
- Elk bestand telt één keer (op inhoud). Meer bestanden mag (bv. per jaar); een tijdstip dat er al is, wordt niet
  overschreven. Een fout in een al ingelezen periode herstel je dus niet met een nieuw bestand.

Voorbeeld:
```
ts,afname_dal,afname_normaal,terug_dal,terug_normaal
2022-01-01T12:00:00+01:00,4.123,6.210,0,0
2022-07-01T12:00:00+02:00,2.050,3.400,1.200,5.800
```

Zet het bestand (naam vrij, `.csv`) in de app; de gebruiker plakt in PowerShell:
```
docker cp $env:USERPROFILE\Downloads\historie.csv energie-app:/app/data/import/
```
De app verwerkt het binnen een minuut en rekent de dagcijfers opnieuw uit. Controle: Beheer → **Data**,
kolom **bron** = Slimmemeterportal voor die maanden, en de totalen per jaar naast de bron van de gebruiker (spreadsheet,
jaarnota). Blijft er na de import een dag op 0,0 met bron Home Assistant, dan heeft HA die dag wel een meterstand die
niet oploopt (bv. een P1-meter die bleef hangen); zo'n dag gaat voor op de import. Noteer welke dagen en sensor en laat
de gebruiker dat aan de beheerder van de app melden.

De pc hoeft niet altijd aan te staan: de app haalt de uurcijfers later alsnog uit HA. Alleen
minuutdetails ouder dan ~10 dagen (zo lang bewaart HA ze) gaan verloren als de pc lang uit staat.
