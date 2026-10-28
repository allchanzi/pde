# fleetui — zadanie projektu

Stav: návrh na implementáciu. Tento dokument je uložený dočasne v PDE;
implementácia fleetui patrí do samostatného repozitára.

## Cieľ

Vytvoriť samostatnú terminálovú aplikáciu v Ruste na vizuálne nastavovanie,
spúšťanie a sledovanie workflow AI agentov Codex a Claude Code. Aplikácia musí
fungovať samostatne aj ako nástroj otvorený z PDE pre vybraný Git worktree.

Používateľ je skúsený vývojár. Potrebuje kontrolovať zadania, modely, oprávnenia,
výsledky a odovzdávanie práce medzi agentmi bez ručného prepínania a kopírovania
kontextu medzi terminálmi.

## Hlavný používateľský scenár

1. Používateľ vyberie v PDE projekt a worktree pre novú feature a otvorí AI tab.
2. Fleetui otvorí existujúce workflow alebo umožní vytvoriť nové.
3. Používateľ nastaví plánovacieho agenta: provider, model, zadanie a oprávnenia.
4. Spustí agenta a diskutuje s ním v terminálovom popupe priamo vo fleetui.
5. Agent pripraví plán. Workflow čaká na explicitné schválenie používateľom.
6. Používateľ schváli konkrétnu verziu plánu alebo ho vráti na dopracovanie.
7. Implementačný agent dostane schválený plán a pracuje v zvolenom worktree.
8. Po implementácii prebehnú kontroly: testy, security review a review použiteľnosti
   alebo ergonómie riešenia podľa typu zmeny.
9. Fleetui zobrazí výsledky, nálezy a neoverené časti. Používateľ rozhodne o
   ďalšej oprave alebo dokončení.

Používateľ môže pri jednotlivých agentoch zvoliť rôznych providerov a modely.
Modely ani ich dostupnosť nesmú byť predpokladané podľa roly alebo napevno
zakódované ako aktuálny zoznam.

## Hranice voči PDE

- PDE spravuje projekty, worktrees a vonkajšie terminálové sessions/taby.
- Fleetui spravuje AI workflow, agentov, ich procesy a terminálové popupy.
- Integrácia nesmie vyžadovať import interného kódu PDE ani čítanie jeho
  nedokumentovaných stavových súborov.
- PDE odovzdá explicitný pracovný adresár a voliteľne identifikátor workflow.
- Samostatné spustenie fleetui musí poskytovať rovnakú základnú funkcionalitu.
- Zellij a tmux môžu aplikáciu hostiť, nie sú podmienkou jej fungovania.
- Automatické vytváranie branchí a worktrees nie je súčasťou prvého MVP.

Navrhované rozhranie, ktoré sa má potvrdiť pri návrhu CLI:

```text
fleetui --cwd /path/to/worktree
fleetui --cwd /path/to/worktree --workflow feature-name
```

Workflow musí byť viazané na identitu repozitára a konkrétneho worktree.
Branch a aktuálny commit sú zaznamenaný kontext; samotný názov branche nie je
dostatočný jednoznačný identifikátor workflow.

## TUI a interakcia

- Prehľad zobrazuje kroky, závislosti, aktuálny stav a miesto vyžadujúce zásah.
- Výber kroku zobrazí konfiguráciu, vstupy, výsledky a históriu pokusov.
- Enter alebo klik na agenta otvorí jeho terminál v popupe vykreslenom fleetui.
- Opätovné otvorenie aktívneho agenta zobrazí ten istý proces a terminál.
- Skrytie popupu nezastaví agenta a nespustí nový proces.
- Zastavenie procesu je samostatná akcia s jasným výsledným stavom.
- Ovládanie klávesnicou je plnohodnotné; myš je doplnok.
- UI musí rozlíšiť klávesy smerujúce agentovi od ovládania fleetui. Používateľ
  musí vždy vidieť, ako opustiť režim terminálového vstupu.
- Popup musí podporovať resize, terminálové farby, kurzor a scrollback.
- Bežiace procesy nesmú blokovať vykresľovanie ani ovládanie aplikácie.

Ilustračný prehľad:

```text
Planner → Schválenie plánu → Implementátor
                                  │
                     ┌────────────┼────────────┐
                     ▼            ▼            ▼
                   Testy       Security     Ergonomika
                     └────────────┼────────────┘
                                  ▼
                            Vyhodnotenie
```

## Konfigurácia krokov

Každý krok má stabilné ID, názov, typ, závislosti a podmienku dokončenia.

Podporované typy:

- Agent: provider, model, zadanie, pracovný adresár, oprávnenia, vstupy a výstupy.
- Príkaz: program a argumenty, pracovný adresár, timeout a očakávaný exit status.
- Schválenie: konkrétny artefakt/verzia a explicitné rozhodnutie používateľa.

Príkazy majú byť reprezentované ako program a argumenty. Spustenie cez shell
musí byť explicitná voľba, nie automatická interpolácia používateľských dát.

Konfigurácia workflow je oddelená od runtime stavu a má verziu schémy. Zmena
konfigurácie počas behu nesmie potichu zmeniť už spustený pokus; nový pokus
použije konkrétny zaznamenaný snapshot konfigurácie.

## Orchestrácia a odovzdávanie práce

- Rozlišovať konfiguráciu kroku, konkrétny beh workflow a pokus kroku.
- Minimálne stavy: pending, ready, running, awaiting_approval, succeeded,
  failed, cancelled a interrupted. Schvaľovací krok podporuje aj rejected.
- Ukončenie CLI s nulovým exit statusom samo osebe nepotvrdzuje vecnú
  správnosť implementácie ani schválenie plánu.
- Každý typ kroku má explicitné pravidlo úspechu a zaznamenané dôkazy.
- Závislý krok sa spustí až po splnení svojich podmienok.
- Opakovanie vytvorí nový pokus a zachová predchádzajúci výsledok.
- Nová verzia plánu vyžaduje nové schválenie. Výsledky závislé od starých
  vstupov musia byť označené ako neaktuálne pred ďalším použitím.
- Ďalší agent dostáva explicitné artefakty: zadanie, schválený plán, referenciu
  na zmeny a výsledky kontrol. Celá konverzácia sa automaticky nekopíruje.
- Testovací krok zaznamená reálny príkaz, exit status a výstup. Tvrdenie agenta
  „testy prešli“ nie je náhradou za tento výsledok.
- Automatické slučky opráv a neobmedzené opakovanie nie sú súčasťou MVP.

## Konzistencia zmien a QA

- V MVP smie do daného worktree zapisovať najviac jeden implementačný agent.
- Paralelní revieweri prídu neskôr; musia hodnotiť rovnaký zachytený stav zmien.
- Zaznamenať commit aj necommitnutý diff; samotný HEAD neidentifikuje všetky
  zmeny v pracovnom strome.
- Pri zmene hodnoteného kódu označiť predchádzajúce kontroly ako neaktuálne.
- Read-only review musí vychádzať z reálne vynútiteľných oprávnení providera
  alebo izolácie, nie iba z textu promptu.
- Testy môžu vytvárať build artefakty; ich beh nesmie meniť hodnotený zdrojový
  stav bez detekcie a následného zneplatnenia výsledkov.

## Integrácia providerov

Pred implementáciou overiť aktuálnu oficiálnu dokumentáciu a lokálne dostupné
verzie Codex CLI a Claude Code. Nepredpokladať konkrétne prepínače ani rovnaké
schopnosti oboch providerov.

Každý adapter musí popísať podporu:

- spustenia v konkrétnom adresári a výberu modelu;
- interaktívneho behu v PTY;
- identifikácie a prípadného obnovenia konverzácie;
- štruktúrovaných udalostí alebo výstupov, pokiaľ sú dostupné;
- oprávnení, prerušenia a ukončenia procesu.

Interaktívna CLI session a programovo riadený beh môžu vyžadovať rozdielne
rozhrania. Ich kombináciu treba overiť prototypom. Nepoužívať rozpoznávanie
textov vykreslenej terminálovej obrazovky ako autoritatívny workflow protokol.
Ak provider neposkytuje spoľahlivý signál dokončenia alebo artefakt, MVP má
použiť explicitné potvrdenie používateľa a túto hranicu jasne zobraziť.

Prihlásenie zostáva v oficiálnych nástrojoch providerov. Fleetui neukladá kópie
credentials a nesmie automaticky vypínať ich sandbox alebo approval mechanizmy.

## Technický smer

- Samostatný repozitár `fleetui`, Rust a Ratatui.
- Oddeliť doménový model a scheduler od UI, provider adapterov, PTY a ukladania.
- Použiť existujúce knižnice pre PTY a terminálovú emuláciu; nevytvárať vlastný
  terminálový parser bez preukázanej potreby.
- Knižnice a ich vhodnosť overiť pred výberom v technickom prototype.
- Konfigurácia môže byť verzovaná s projektom; logy, konverzácie a runtime stav
  patria predvolene mimo repozitára a môžu obsahovať citlivé údaje.
- Stav ukladať priebežne tak, aby pád nepoškodil posledný platný záznam.
- MVP nevyžaduje daemon. Pri ukončení aplikácie s aktívnymi procesmi musí UI
  vysvetliť následok a ponúknuť návrat alebo riadené ukončenie.
- Po páde alebo reštarte nesmie aplikácia predstierať, že staré procesy bežia;
  neobnovené pokusy označí ako interrupted. História zostane dostupná.

## Míľniky

### M0 — technický prototyp terminálu a providerov

- Založiť samostatnú aplikáciu s minimálnou konfiguráciou jedného agenta.
- Overiť Codex CLI aj Claude Code v PTY a Ratatui popupe.
- Overiť vstup, resize, scrollback, skrytie a návrat do rovnakého procesu.
- Overiť ukončenie procesu vrátane jeho potomkov a správanie pri páde.
- Zdokumentovať podporované verzie a limity obnovovania a automatizácie.

Akceptácia: používateľ vedie interaktívnu konverzáciu s oboma providermi;
skrytie popupu zachová proces a opätovné otvorenie nevytvorí ďalší.

### M1 — minimálne použiteľné workflow

- Pevná postupnosť Planner → Schválenie → Implementátor → Testy → Reviewer.
- Konfigurácia providera a modelu pri agentových krokoch priamo v TUI.
- Editácia zadaní a testovacieho príkazu.
- Explicitné schválenie konkrétneho plánu.
- Ukladanie konfigurácie, stavov, artefaktov a histórie pokusov.
- Zobrazenie zlyhania, zrušenia a manuálne opakovanie kroku.

Akceptácia: na malom reálnom tickete implementátor nezačne pred schválením,
prevezme schválený plán a UI ukáže výsledok testov aj review. Opakovaný krok
zachová históriu a po reštarte sú dostupné uložené výsledky.

### M2 — dynamický editor a paralelné kontroly

- Pridávanie, editácia a odstraňovanie krokov a závislostí v TUI.
- Validácia grafu vrátane cyklov a neplatných referencií.
- Paralelné testovacie/review vetvy s nastaviteľným limitom súbehu.
- Security a ergonomické review s explicitným zadaním a rozsahom.
- Detekcia neaktuálnych vstupov a výsledkov.
- Súhrn nálezov a manuálne vrátenie práce implementátorovi.

Akceptácia: používateľ v TUI zostaví vetvené workflow, kontroly hodnotia rovnaký
stav kódu a neúspešná kontrola sa nestratí v celkovom výsledku.

### M3 — integrácia do PDE

- Pridať fleetui ako voliteľný nástroj a AI tab pre konkrétny workspace.
- Otvoriť ho v správnom adresári cez dohodnuté CLI rozhranie.
- Pri chýbajúcom nástroji zobraziť zrozumiteľnú informáciu.
- Zdokumentovať inštaláciu a kompatibilitu verzií.

Akceptácia: z PDE možno otvoriť fleetui pre vybraný worktree; rovnaké workflow
je dostupné aj pri samostatnom spustení fleetui.

## Mimo prvého MVP

- Cloudová služba, tímová spolupráca a vzdialené riadenie.
- Beh pokračujúci po ukončení fleetui cez vlastný daemon.
- Viac agentov súbežne zapisujúcich do jedného worktree.
- Automatický commit, merge, push, publikovanie alebo deployment.
- Vlastný modelový backend, MCP server, plugin systém a hooks framework.
- Automatický výber „najlepšieho“ modelu a garantovaný výpočet ceny.

## Validácia a definícia dokončenia

- Jednotkové testy pre stavové prechody, závislosti, schválenia, opakovanie
  a zneplatnenie výsledkov pri zmene vstupov.
- Integračné testy runnera s deterministickým falošným procesom: výstup,
  chyba, prerušenie a neočakávané ukončenie.
- Manuálne smoke overenie skutočných providerov, nezávislé od bežného CI.
- Kontroly formátovania, lint a relevantné Rust testy.
- Zdokumentované klávesy, požiadavky, miesto uloženia dát a známe obmedzenia.
- Pri reportovaní výsledkov presne rozlíšiť vykonané a nevykonané kontroly.

## Prvá implementačná úloha

Realizovať iba M0. Najprv overiť oficiálne rozhrania oboch CLI a navrhnúť
minimálnu architektúru PTY popupu. Nepokračovať automaticky do workflow enginu,
PDE integrácie ani paralelnej orchestrácie. Výstupom je spustiteľný prototyp,
overenie oboch agentov a krátky záznam technických rozhodnutí a obmedzení.
