# csHarvester

csHarvester ist eine existdb-basierte Applikation (EXpath) zum bequemen Harvesten von Dateien im Correspondence Metadata Interchange Format. Im csHarvester können URLs von CMIF-Dateien eingegeben werden. Per Knopfdruck lädt die App die Dateien herunter und speichert sie in der Datenbank. Dabei validiert sie die Dateien gegen das CMIF-Schema und erstellt einen Report, der sowohl Validierungsfehler als auch eine Inhaltsübersicht enthält. Zu letzterem gehören Angaben, wieviele Briefe das Verzeichnis enthält und wieviele Personen und Orte mit welchen Normdaten-IDs ausgestattet sind. Alle Funktionen und Informationen sind über das Frontend der Applikation bequem zugänglich und ausführbar.

## Dateistruktur

Die Hauptfunktionen zum Harvesten liegen in der harvster.xql; alle Funktionen, die das Frontend der Applikation betreffen, sind in app.xql definiert. Im Hauptverzeichnis liegen die einzelnen Ansichten (als HTML-Templates), das Seitentemplate befindet sich in templates/page.html. Im Ordner data werden alle im Betrieb anfallenden Daten gespeichert: registrierte CMIF-URLs, CMIF-Dateien, das Logbuch, die einzelnen Reports sowie das CMIF-Schema, gegen das die Dateien validiert werden. Im git sind diese Ordner fast leer, sie füllen sich dann bei Benutzung der App.

## Set-Up

Zur Inbetriebnahme ist nur die Installation des XAR-Packages in eXistdb notwendig.

## Copyright

Developed by Stefan Dumont, dumont@bbaw.de

for the purpose of the project ["correspSearch - Connect scholarly editions of letters"](https://correspSearch.net) of the Berlin-Brandenburg Academy of Sciences and Humanities (BBAW), funded by the German Research Association (Deutsche Forschungsgesellschaft - DFG).

## License

Copyright (C) 2019–2022 Berlin-Brandenburg Academy of Sciences and Humanities.

csHarvester is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License v3 as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

csHarvester is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with csHarvester. If not, see http://www.gnu.org/licenses/.