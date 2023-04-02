-------------------------------------------------------------
-------------------------------------------------------------
/*
	predmet:	Testiranje i performanse sistema
	pripremio:	Aleksandar Janković
	datum:		31.03.2023.
*/
-------------------------------------------------------------
-------------------------------------------------------------
/*
	cilj skripte je da se služi kao pokazni primer backup procesa, da opiše vrste backup-a,
	da prikaže pregled razlike između vrsti backup-a, kao i da istakne neke dobre i loše strane istih
*/
-------------------------------------------------------------
-------------------------------------------------------------

/*
	Za potrebe backup-a kreiraćemo još jednu bazu (šemu)
	master_fon ćemo u ovom primeru posmatrati kao produkciono okruženje
*/

/*
	prilikom kreiranja backup-a potrebno je voditi računa o:
		1. strukturi podataka, kao i o programabilnom delu baze (šeme, procedure, sekvence, autorizacija, ...)
		2. samim podacima i objektima koji su vezani za podatke (tabele, view-ovi, trigeri)

	*** napomena: BITAN JE REDOSLED KOMANDI KOJI SE SMEŠTA U BACKUP script!!!
*/

/*
	Backup podataka se deli na 3 vrste:
		1. Full backup			- sadrži apsolutno sve što se nalazi u bazi u trenutku kreiranja backup fajla(ova)
								- ovaj backup je dovoljan da se odradi oporavak baze (kakav je bio u zabeleženom trenutku)
		2. Differential backup	- sadrži sve zabeležene izmene nad bazom od poslednjeg backup-a
								- potreban je poslednji full backup od koga se beleže izmene kako bi mogao da se odradi db recovery (oporavak)
		3. Incremental backup	- sadrži samo poslednje izmene
								- potreban je poslednji full backup i/ili poslednji differential backup
									od koga se beleže izmene kako bi mogao da se odradi db recovery (oporavak)

		- Differential backup	vs		Incremental backup
			jednom nedeljno					svakog dana
			jednom dnevno					svakog sata

		- razlika je u vremenskim intervalima u kojima se dešavaju
*/

/*
	1. Full backup - backup cele baze -> struktura + podaci

	- može se uraditi pomoću određenih alata
	prilikom izrade primera korišćeno je okruženje Microsoft SQL Server Managment Studio 2018
	
	postupak za backup:
		1) Binarni fajlovi - Microsoft se brine o njima
			- kliknite desni klik na bazu koju želite da backup-ujete
			- odaberite task
			- odaberite backup opciju
			- odaberite tip [full default / differential]
			- [opciono odaberite putanju gde ćete sačuvati fajl]
			- kliknite ok
		2) Generisanje skripti pomoću alata - imate pristup (source) kodu naredbama i njihovom redosledu
				- kliknite desni klik na bazu iz koje želite da "povučete" podatke
				- odaberite task
				- odaberite opciju Generate Scripts
				- next
				- odaberite da li želite da se generiše skripta za celu bazu ili samo za neke njene određene delove
				- next
				- odaberite način čuvanja skripte
				- Finish
				- primetićete da se razlikuje ovako generisan fajl od komandi koje smo mi korstili

	rezultat: backup baze u binarnom formatu - nemate kontrolu nad backupom

	ovim postupkom ste se odlučili da verujete vendoru baze i okruženju što se tiče backup-a
*/
/*
	Prvo se "izvlači" struktura iz sistema -> schema, user, sequence, table, synonym, view, procedure, function, ...
		- ručno sastavljanje i održavanje backup fajlova može biti korisno ako smo istu strukturi i poslovnu logiku
			razvijali u više različitih baza
		- preporuka prilikom pisanja ovakvih fajlova 
			- prilikom kreiranja DDL skripti držati se što je više moguće ANSI standarda
				jer je u tom slučaju potrebno vršiti najmanje izmena da bi skripte mogle da se izvrše 
		- prilikom kreiranja skripti za održavanje procedura ili definisanja korisnika moraće da se vrše 
			- izmene prilikom migracije iz sistema u sistem
			- ovaj nedostatak se ne može izbeci ako želimo da imamo poslovnu logiku što je više sličnu između baza
			- pojedini konstukti imaju drugačiju sintaksu
			- pojedini konstukti ne postoje u drugim bazama (database specific constuct)
				- na primer: prilikom kreiranja rekurzivnog / hijerarhijskog upita u Oracle bazama podataka
					od verzije 11.2 podržava sintaksu CONNECT BY - jednostavniji način pisanja ovakvih upita
					https://livesql.oracle.com/apex/livesql/file/tutorial_GQMLEEPG5ARVSIFGQRD3SES92.html
					ostale baze ne podržavaju ovakvu sintaksu - rekurzivni upit je potrebno pisati pomoću CTE
					konstrukta - ovo postoji i "proći će" u svim bazama, ali se opet sintaksa između njih razlikue
					https://www.postgresqltutorial.com/postgresql-tutorial/postgresql-recursive-query/
		- u slučaju da se projekat koristi za tačno određenu bazu bolje je koristiti već prikazani postupak
-----------------------------------------------------
	Nakon toga se "izvlače" podaci
		- pisanje insert into naredba (kao što je prikazano niže u primeru)
			prilikom kreiranja data backup-a je zapravo loš primer da se tako nešto uradi
			- takvi fajlovi će zauzimati više memorijskog prostora
			- kreiranje backup fajla će trajati duže kada je u pitanju manji skup podataka
				a biće besmislen u slučaju milionskih redova u podacima
			- učitavanje podataka će trajati duže -> jer će se izvršavati insert naredbe jedna po jedna u posebnim transkacijama

	Umesto toga iskoristićemo pomoć okruženja (većina okruženja ima ovu opciju)
	i exportovati (izvesti) podatke u .csv formatu
		+ ovaj format zauzima manje prostora nego prethodni
		+ brži je za učitavanje jer alati prilikom korišćenja import data opcije
			omogućavaju optimizovanije učitavanje podataka
		+ učitavanje podataka će trajati kraće
		+ ovo je često korišćen format za transport podataka u praksi

	Podaci se mogu export-ovati na sledeći način:
		1) Binarni fajlovi - Microsoft se brine o njima
			- kliknite desni klik na bazu iz koje želite da "povučete" podatke
			- odaberite task
			- odaberite opciju Export Data-tier Application 
			- next
			- dodelite ime fajlu
			- Save
		2)  kliknite desni klik na bazu iz koje želite da "povučete" podatke
			- odaberite task
			- odaberite opciju Export Data
			 više o tome: https://www.youtube.com/watch?v=TjuGTWuWt04
			- u okruženju Microsoft SQL Server Management Studio 18 - nisam uspeo da ponovim postupak
			 jer sam naišao na problem opisan na zvaničnom sajtu
			 https://learn.microsoft.com/en-us/answers/questions/634023/sql-server-excel-import-the-microsoft-ace-oledb-12
		
*/
------------------------------------------------------------------------
/*
	20032022_backup_ddl_master_fon.sql
*/
use master;

create database master_fon;

use master_fon;

create table studenti_i_predmeti (
	indeks				varchar(10) not null,
	student_ime			varchar(100) not null,
	student_prezime		varchar(100) not null,
	mesto				varchar(100) not null,
	ppt					varchar(100) not null,
	predmet_naziv		varchar(100) not null,
	broj_predavanja		int,
	ocena				int not null
);
/*
	20032022_backup_ddl_master_fon.sql END
*/
/*
	20032022_backup_dml_master_fon.sql
*/
insert into studenti_i_predmeti (indeks, student_ime, student_prezime, mesto, ppt, predmet_naziv, broj_predavanja, ocena)
						values('1234/2020', 'Pera', 'Perić', 'Beograd', '11000', 'Programiranje 1', 50, 8);
insert into studenti_i_predmeti (indeks, student_ime, student_prezime, mesto, ppt, predmet_naziv, broj_predavanja, ocena)
						values('1234/2020', 'Pera', 'Perić', 'Beograd', '11000', 'Programiranje 2', 50, 10);

insert into studenti_i_predmeti (indeks, student_ime, student_prezime, mesto, ppt, predmet_naziv, broj_predavanja, ocena)
						values('1235/2020', 'Ana', 'Anić', 'Beograd', '11000', 'Programiranje 2', 50, 8);
insert into studenti_i_predmeti (indeks, student_ime, student_prezime, mesto, ppt, predmet_naziv, broj_predavanja, ocena)
						values('1235/2020', 'Ana', 'Anić', 'Beograd', '11000', 'Ekonomija', 40, 9);
insert into studenti_i_predmeti (indeks, student_ime, student_prezime, mesto, ppt, predmet_naziv, broj_predavanja, ocena)
						values('1235/2020', 'Ana', 'Anić', 'Beograd', '11000', 'Matematika 1', 43, 6);
/*
	 20032022_backup_dml_master_fon.sql END
*/
------------------------------------------------------------------------

/*
	 21032022_backup_ddl_master_fon.sql
*/
use master;

create database master_fon;

use master_fon;

create table studenti_i_predmeti (
	indeks				varchar(10) not null,
	student_ime			varchar(100) not null,
	student_prezime		varchar(100) not null,
	mesto				varchar(100) not null,
	ppt					varchar(100) not null,
	predmet_naziv		varchar(100) not null,
	broj_predavanja		int,
	ocena				int not null
);

create table predmet (
	predmet_id			int primary key identity(1,1), -- identity <=> autoincrement
	predmet_naziv		varchar(100) not null,
	broj_predavanja		int
);
create table mesto (
	ppt					varchar(100) primary key,
	naziv				varchar(100) not null
);
create table student (
	indeks				varchar(10) primary key,
	student_ime			varchar(100) not null,
	student_prezime		varchar(100) not null,
	ppt					varchar(100) not null,
	constraint ppt_fk foreign key (ppt) references mesto(ppt)
);
create table ocene (
	indeks				varchar(10) not null,
	predmet_id			int not null,
	ocena				int not null,
	primary key(indeks, predmet_id),
	constraint ocena_check check (ocena > 5),
	constraint ocene_fk_student foreign key (indeks) references student(indeks),
	constraint ocene_fk_predmet_fk foreign key (predmet_id) references predmet(predmet_id)
);
create table student_slusa_predmet (
	indeks				varchar(10) not null,
	predmet_id			int not null,
	primary key(indeks, predmet_id),
	constraint ssp_fk_student_fk foreign key (indeks) references student(indeks),
	constraint ssp_fk_predmet_fk foreign key (predmet_id) references predmet(predmet_id)
);
/*
	 21032022_backup_ddl_master_fon.sql END
*/
/*
	 21032022_backup_dml_master_fon.sql
*/
insert into studenti_i_predmeti (indeks, student_ime, student_prezime, mesto, ppt, predmet_naziv, broj_predavanja, ocena)
						values('1234/2020', 'Pera', 'Perić', 'Beograd', '11000', 'Programiranje 1', 50, 8);
insert into studenti_i_predmeti (indeks, student_ime, student_prezime, mesto, ppt, predmet_naziv, broj_predavanja, ocena)
						values('1234/2020', 'Pera', 'Perić', 'Beograd', '11000', 'Programiranje 2', 50, 10);

insert into studenti_i_predmeti (indeks, student_ime, student_prezime, mesto, ppt, predmet_naziv, broj_predavanja, ocena)
						values('1235/2020', 'Ana', 'Anić', 'Beograd', '11000', 'Programiranje 2', 50, 8);
insert into studenti_i_predmeti (indeks, student_ime, student_prezime, mesto, ppt, predmet_naziv, broj_predavanja, ocena)
						values('1235/2020', 'Ana', 'Anić', 'Beograd', '11000', 'Ekonomija', 40, 9);
insert into studenti_i_predmeti (indeks, student_ime, student_prezime, mesto, ppt, predmet_naziv, broj_predavanja, ocena)
						values('1235/2020', 'Ana', 'Anić', 'Beograd', '11000', 'Matematika 1', 43, 6);
/*
	 21032022_backup_dml_master_fon.sql END
*/
------------------------------------------------------------------------