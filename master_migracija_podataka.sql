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
	cilj skripte je da se služi kao pokazni primer normalizacije sistema, migracije podataka iz nenormalizovanog sistema,
	pregled mogućih problema prilikom migracije podataka i opisavenj ETL procesa
	pregled CTE izraza
	pregled procedura i kursora
	testiranje migracije pomoću upita i procedura
*/
-------------------------------------------------------------
-------------------------------------------------------------
/*
	izvršiti zasebno ovaj deo koda
*/
SET IMPLICIT_TRANSACTIONS ON; 
/*	komanda koja nam omogućava da koristimo commit i rollback bez "eksplicitnih transakcija"
	ovde će se koristi implicitne transakcije
	- kako bismo mogli da koristimo komande commit i rollback van konteksta transakcije
		na primer insert komanda mora biti u okviru begin i end i da se završi sa commit naredbom
		kako bi izmene bile trajno sačuvane
	više o tome:
	transakcija: https://learn.microsoft.com/en-us/sql/t-sql/language-elements/transactions-transact-sql?view=sql-server-ver16
	implicitna transakcija: https://learn.microsoft.com/en-us/sql/t-sql/statements/set-implicit-transactions-transact-sql?view=sql-server-ver16
		
	eksplicitna transakcija: https://learn.microsoft.com/en-us/sql/t-sql/language-elements/begin-transaction-transact-sql?view=sql-server-ver16
		eksplicitna transkicja ima vidljivo u kodu i počinje sa BEGIN TRANSACTION i završava se sa COMMIT / ROLLBACK
*/

use master;



drop database if exists master_fon;

/*
	izvršiti zasebno ovaj deo koda
*/
create database master_fon;

/*
	izvršiti zasebno ovaj deo koda
*/
use master_fon;

/*
	nenormalizovana tabela - odavde kasnije mogu nastati pregledi pogodni za korisnika (view)
*/
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
		
select	*
from	studenti_i_predmeti;
/*
	da bismo normalizovali tabele potrebno je da uocimo entitete koji se pojavljuju u tabeli studenti_i_predmeti
	to su sledeći entiteti:
			student, predmet, mesto, ocene,
			tabela koja prikazuje vezu između studenta i predmeta koji on sluša (student može da sluša više predmeta i predmet sluđa više studenata)
	
	Prilikom kreiranja tabela dobra praksa je da se tu definišu primarni ključ, spoljni ključevi, ograničenja, sekvence, trigeri - (objekti)
	Da bi ovakva scripta uopšte mogla da se izvrši nad nekom bazom (sistemom za upravljanje podataka),
		potrebno je da bude napisana u određenom redosledu. Redosled mora biti takav da se prvo kreiraju objekti koji su nezavisni
		a potom da se kreiraju zavisni objekti
*/
-------------------------------------------------------------
/*
	normalizacija sistema
*/
-------------------------------------------------------------
create table predmet (
	predmet_id			int primary key identity(1,1), -- identity <=> autoincrement
	predmet_naziv		varchar(100) not null,
	broj_predavanja		int
);
create table mesto (
	ppt					varchar(100) primary key default seq_name(),
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

-------------------------------------------------------------
/*
	migracija podataka
*/
-------------------------------------------------------------
/*
	proces migracije podataka - sada je potrebno prebaciti podatke iz nenormalizovan sistema u normalizovani
*/
/*	
	da bi se doslo do 3NF u procesu iznad tabela student je već kreirana, zbog toga se ne može koristi naredba
	select into - jer ona automatski kreira novu tabelu, a pošto je tabela već kreirana dobijamo grešku
	
	There is already an object named 'student' in the database.

	select	indeks, student_ime, student_prezime, ppt
	into	student
	from	studenti_i_predmeti;

	zbog toga ćemo koristiti CTE (Comon Table Expression) koji nam omogućava da kreiramo skupove podataka 
	na način na koji nama odgovaraju i da sa njima uradimo nešto, da ih prikažemo ili iskoristimo za insert podataka
	što ćemo sada i pokazati.
	
	poziv with statement-a se mora završiti sa nekom od sledećih naredbi: select, insert, update, delete
	cte strukture se mogu nadovezivati jedna na drugu do izvršenja neke od pomenutih obaveznih naredbi
	može se koristiti prilikom kreiranja view-a u okviru select naredbe
	ovakva struktura postoji samo u ram memoriji prilikom izvršenja upita
	opciono može sadržati nazive kolona (i mora sadržati nazive kolona prilikom kreiranja rekurzivnog upita)

	više o cte: https://learn.microsoft.com/en-us/sql/t-sql/queries/with-common-table-expression-transact-sql?view=sql-server-ver16
	više o insert i cte: https://learn.microsoft.com/en-us/sql/t-sql/statements/insert-transact-sql?view=sql-server-ver16
*/


/*
	primer CTE -> Select
*/
with test_select as (
	select	* 
	from	student
	where	lower(student_ime) like 'pera'
)
select	*
from	test_select
;

with test2 as (
	select * 
	from studenti_i_predmeti
	where lower(student_ime) like 'pera'
)
select	*
from	test2
where	ocena = 8

/*
	primer CTE -> Insert
*/
with mesta as (
	select	distinct ppt,
			mesto as naziv
	from	studenti_i_predmeti
) 
insert into mesto
select * from mesta;

select * from mesto 
GO

/*
	ovo je uprošćen primer, ali ovo su mesta prilikom koje je potrebno dublje analizirati podatke
	zbog loše strukture svesti na problem na problem ETL (Extract Transform Load)
	moguće je postojanje više vrenosti naziva mesta Beograd za istpi poštasnki broj: beograd, Beograd
	potrebno je voditi računa o ograničenjima - zato je gore neoprezno dodata ključna reč distinct, 
	da insert ne bi pao na primarnom ključu - 2 puta se jevalja mesto beograd, a ppt je primarni ključ u tabeli mesto
*/

/*
	migracija podataka o studentima
*/
with studenti as (
	select	distinct indeks,
			student_ime,
			student_prezime,
			ppt
	from	studenti_i_predmeti
)
insert into student
	select * from studenti;

/*
	migracija podataka o predmetima
*/
with predmeti as (
	select	distinct predmet_naziv,
			broj_predavanja
	from	studenti_i_predmeti
)
insert into predmet
	select * from predmeti;

/*
	migracija podataka o ocenama
*/
with ocene_w as (
	select	indeks,
			(select predmet_id from predmet p where p.predmet_naziv = studenti_i_predmeti.predmet_naziv) predmet_id,
			ocena
	from	studenti_i_predmeti
)
insert into ocene
	select * from ocene_w;

/*
	migracija podataka o predmetima i koji ih studenti slušaju
*/
with slusa as (
	select	indeks,
			(select predmet_id from predmet p where p.predmet_naziv = studenti_i_predmeti.predmet_naziv) predmet_id
	from	studenti_i_predmeti
)
insert into student_slusa_predmet
	select * from slusa;

	select * from student_slusa_predmet

	

/*
	kreiranje pogleda koji bi odgovarali korisniku
*/
create view studenti_i_ocene_po_predmetima as 
select	s.indeks,
		s.student_ime as ime,
		s.student_prezime as prezime,
		p.predmet_naziv as 'naziv predmeta',
		o.ocena
from	student s
join	student_slusa_predmet ssp
	on	s.indeks = ssp.indeks
join	predmet p
	on	ssp.predmet_id = p.predmet_id
join	ocene o
	on	o.indeks = s.indeks
	and o.predmet_id = p.predmet_id;



select * from studenti_i_ocene_po_predmetima;



-------------------------------------------------------------
/*
	mogući problemi prilikom migracije podataka i Extract Transform Load  procesa
*/
-------------------------------------------------------------

/*
	pronalaženje duplikata - studenti koji imaju 2 ili više ocena za isti predmet
*/

select	* 
from	studenti_i_predmeti
order by indeks, predmet_naziv;

select	indeks,
		student_ime,
		student_prezime,
		predmet_naziv
from	studenti_i_predmeti
group by indeks, student_ime, student_prezime, predmet_naziv
having count(1) > 1;

/*	duplikati za relaciju sudent
	kako bismo se uverili da upit pronalazi duplikate 
	možemo dodati još jedan red koji se odnosi na Peru Perića 
	koji je već položio predmet Programiranje 1 sa ocenom 8,
	dodaćemo red u kome je dobio ocenu 9
*/
insert into studenti_i_predmeti (indeks, student_ime, student_prezime, mesto, ppt, predmet_naziv, broj_predavanja, ocena)
						values('1234/2020', 'Pera', 'Perić', 'Beograd', '11000', 'Programiranje 1', 50, 9);



select	indeks,
		student_ime,
		student_prezime,
		predmet_naziv
from	studenti_i_predmeti
group by indeks, student_ime, student_prezime, predmet_naziv
having count(1) > 1;

select	* 
from	studenti_i_predmeti
where	indeks = '1234/2020' 
	and predmet_naziv = 'Programiranje 1';
/*
	sada dobijamo 1 red kao rezultat upita što znači 
	indeks		student_ime	student_prezime	predmet_naziv
	1234/2020	Pera		Peric			Programiranje 1
*/

/*
	dodaćemo još jedan red koji ima za cilj da pokaže da isto mesto ima različite nazive
*/
insert into studenti_i_predmeti (indeks, student_ime, student_prezime, mesto, ppt, predmet_naziv, broj_predavanja, ocena)
						values('1235/2020', 'Ana', 'Anić', 'Beeograd', '11000', 'Programiranje 1', 50, 9);

/*
	grupisanje studenata po mestu i broj redova - broj redova će biti veći od 1 u nekim slučajevima
	jer su podaci u nenormlaizovanoj tabeli redundantni - ponavljaju se, 
	u ovo slučaju zbog predmeta koje student sluša

*/
select	indeks,
		student_ime,
		student_prezime,
		ppt,
		mesto
		,count(*)
from	studenti_i_predmeti
group by indeks, student_ime, student_prezime, ppt, mesto;

/*
	grupisanje podataka po mestima iz kojih studenti dolaze
*/
select	ppt,
		mesto
from	studenti_i_predmeti
group by ppt, mesto;


/*
	ovo je imalo za cilj da pokže neki od načina kako se mogu pronaći duplikati
	nakon pronalaženja nepravilnosti potrebono je uvek detaljnije razmotriti same podatke
	redovi će biti obrisani kako bi se nastavilo sa testiranjem same migracije
	- definisanje primarnih ključeva će sprečiti pojavljivanje duplih vrednosti, jer je ppt primerni ključ
		na primer:	ppt		mesto
					11000	Beeograd
					11000	Beograd
	- takođe prilikom prebacivanja podataka korišćena je klauzula distinct 
	- ovo će raditi na ovako malom primeru
	- ali prilikom pisanja upita može biti loše korišćenje distinct klauzule 
		jer će "sakriti" postojanje duplihranih vrednosti za pojavljivanje predmeta
		na primer prilikom korišćenja podupita, 
		podupit mora da vrati tačno jednu vrednost	ako se koristi operator za poređenje '='
		- u slučaju da podupit vraća više vrednosti a koristi se '=' upit se neće izvršiti
*/

select	* 
from	studenti_i_predmeti
order by indeks, predmet_naziv; -- postoje duplirane vrednosti po predmetu

select * from student;

select	s.indeks,
		s.student_ime,
		s.student_prezime,
		s.ppt,
		ssp.predmet_id,
		p.predmet_naziv naziv_predmeta_iz_tabele_predmet,	-- zakomentarišite/otkomentarišite ovu liniju i spajanje sa tabelom predmet na dnu upita
		(	select	distinct sip.predmet_naziv				-- otkomentarišite/zakomentarišite ključnu reč distinct da vidite kako će se upit ponašati
			from	studenti_i_predmeti sip 
			where	sip.indeks = s.indeks 
				and	sip.predmet_naziv = (select p.predmet_naziv from predmet p 
													where p.predmet_id = ssp.predmet_id) ) naziv_predmeta_iz_tabele_studenti_i_predmeti
from	student s
join	student_slusa_predmet ssp
	on	s.indeks = ssp.indeks
join	predmet p
	on	ssp.predmet_id = p.predmet_id;

	select * from student_slusa_predmet
/*
	nepostojanje ključne reči distinct u podupitu upit vraća grešku
	Subquery returned more than 1 value. This is not permitted when the subquery follows =, !=, <, <= , >, >= or when the subquery is used as an expression.
	
	Ali ako dodamo ključnu reč distinct upit će se izvršiti
	Kada se u upitima koristi distinct, top 1, limit 1 to može značiti da možda model nije postaljen kako treba
	što je i bio slučaj sa nenormalizovanom tabelom
*/

/*
	pošto je ovo bio pokazni primer mogućih problema, obrisaćemo korumpirane redove
*/

select * from studenti_i_predmeti order by indeks, predmet_naziv;

delete from studenti_i_predmeti where indeks = '1235/2020' and mesto = 'Beeograd';
delete from studenti_i_predmeti where indeks = '1234/2020' and predmet_naziv = 'Programiranje 1' and ocena = 9;



-------------------------------------------------------------
/*
	testiranje migracije:
		1. testiranje broja redova
		2. testiranje razlike u podacima korišćenjem operatora except (u nekim bazama minus)
			(jedan smer)
				source_tabel
				except
				dest_tables
			unija (drugi smer)
				dest_tables
				except
				source_tabel

			koristi se unija kako bismo u jednom upitu videli razlike između oba smera, u slučaju da ih ima

		*** napomena - kod određenih sistema za upravljanje bazom podataka operator "except" se zove "minus"

		except vraća DISTINCT REDOVE!!!

		više o except komandi: https://learn.microsoft.com/en-us/sql/t-sql/language-elements/set-operators-except-and-intersect-transact-sql?view=sql-server-ver16
*/
-------------------------------------------------------------

/*
	testiranje će biti izvršeno na III načina:
	I - testiranje "čistim" SQL-om
	II - testiranje pomoću procedura
	III - testiranje pomoću C# unit testova

	tok testiranja će se bazirati na:
		1. proveri broja redova
		2. razlici u podacima između source i destination tabela
*/

-------------------------------------------------------------

/*
	I - testiranje "čistim" SQL-om
*/

select * from studenti_i_predmeti;
/*
	I - 1. testiranje broja redova 

		- pod predpostavkom da početni model nije korumpiran / da je čist 
		- da su podaci lepo sređeni i da nema neskalada među vrednostima (kao gorepomenuti primer beograd / Beograd, da nema duplih vrednosti, ...)
*/
select	count(*)
from	studenti_i_predmeti; -- 5

select	count(*)
from	studenti_i_ocene_po_predmetima; -- 5
/*
	ako smo prošli kroz proces normalicije to znači da od trenutnog seta podataka
	uvezivanjem tabela možemo doći do prvobitnog skupa podataka
		- isti broj redova
		- nema razlike među podacima iz prvobitne tabele i uvezanih podataka iz novog modela, kao i obrnuto
*/

/*
	I - 2. testiranje razlike u redovima između sorce i destination tabela

		- u našem primeru će source biti početna nenormalizovana tabela
		- a pošto smo normalizovali sistem potrebno je da spojimo podatke iz tabela kako bismo dobili prikaz
		- nakon toga ćemo pogledati uniju razlika između podataka
*/

select * from studenti_i_predmeti; -- source tabela

/*	formiranje destination prikaza 
		pošto ćemo koristiti destination dva puta
			- možemo ponovo iskoristiti CTE (biće pokazano)
			- možemo formirati view da bi sam test bio pregledniji
*/
select	s.indeks,
		s.student_ime,
		s.student_prezime,
		(select m.naziv from mesto m where m.ppt = s.ppt) as mesto,
		s.ppt,
		--ssp.predmet_id,
		p.predmet_naziv,
		p.broj_predavanja,
		o.ocena
from	student s
join	student_slusa_predmet ssp
	on	s.indeks = ssp.indeks
join	predmet p
	on	ssp.predmet_id = p.predmet_id
join	ocene o
	on  ssp.indeks = o.indeks
	and ssp.predmet_id = o.predmet_id;


/*
	pravljenje test slučaja - razlike u redovima između sorce i destination tabela
*/

with source as (
	select	indeks,
			student_ime,
			student_prezime,
			mesto,
			ppt,
			predmet_naziv,
			broj_predavanja,
			ocena
	from	studenti_i_predmeti
),
destination as (
	select	s.indeks,
			s.student_ime,
			s.student_prezime,
			(select m.naziv from mesto m where m.ppt = s.ppt) as mesto,
			s.ppt,
			--ssp.predmet_id,
			p.predmet_naziv,
			p.broj_predavanja,
			o.ocena
	from	student s
	join	student_slusa_predmet ssp
		on	s.indeks = ssp.indeks
	join	predmet p
		on	ssp.predmet_id = p.predmet_id
	join	ocene o
		on  ssp.indeks = o.indeks
		and ssp.predmet_id = o.predmet_id
),
source_minus_destination as (
	select 'source_minus_destination' direction, smd.* 
	from (
		select	s.*
		from	source s
		except	
		select	d.*
		from	destination d
	) smd
),
destination_minus_source as (
	select 'destination_minus_source' direction, dms.* 
	from (
		select	d.*
		from	destination d
		except	
		select	s.*
		from	source s
	) dms
)
select	*
from	source_minus_destination
union	
select	*
from	destination_minus_source;

/*
	*** napomena	- poželjno je dati alijas podupitu, jer neke baze to zahtevaju eksplicitno u određenim slučajevima
						dok neke ne zahtevaju -> zbog razlike bolje je uvek dati naziv podupitu (u primeru "smd" i "dms" )

	*** preporuka	- koristiti union u testiranju umesto union all
					- iz razloga što union all u pozadini prvo poziva union a onda uklanja duplikate

	dodavanjem kolone "destination", lakše ćemo zaključiti odakle dolazi red
	da bismo dobili dobar rezultat kolonu dodajemo tek nakon utvrđivanja razlike između source i destination tabela 
	(pitanje za studente - zašto se dodaje kolona nakon razlike, a ne u samom utvrđivanju razlike?)
*/

delete  from studenti_i_predmeti where indeks = '1235/2020' and predmet_naziv = 'Programiranje 1' and ocena = 9
-------------------------------------------------------------

/*
	II - testiranje pomoću procedura
*/

/*
	ideja je da se od testiranja pomoću "čistog" SQL-a kod izdvoji u procedure
	- procedure su fleksibilnije od samog SQL upita zbog toga što:
		- mogu imati parametre
		- mogu imati promenljive
		- mogu imati kontrolu toka izvršenja same procedure
		- konzolni ispis
		- itd.

	-> potrebno je napraviti procedure, a nakon njihovog kreiranja ih pozvati

	*** PL/SQL (Procedural Laguage for SQL) - ekstenzije (proširenja) SQL jezika u vendorima sistema za upravljanjem bazama podataka (skraćeno bazama podataka).
	PL/SQL - najzastupljeniji vendori:
				- MS SQL Server T-SQL 
				- ORACLE PLSQL
				- Postgres PLPGSLQ

	Ono što u programskim jezicima višeg nivoa nazivamo metodama ovde se deli na dva dela:
		1. procedure - metode koje ne vraćaju vrednost (void)
		2. funkcije - metode koje vraćaju vrednost
		
	više o procedurama:
		kreiranje procedure: https://learn.microsoft.com/en-us/sql/relational-databases/stored-procedures/create-a-stored-procedure?view=sql-server-ver16
		sintaksa kreiranja procedure: https://learn.microsoft.com/en-us/sql/t-sql/statements/create-procedure-transact-sql?view=sql-server-ver16

	* set nocount off; - u dokumentaciji možete pronaći: set nocount {ON | OFF};
															- ON - u delu messages se ne neće ispisati broj zahvaćenih redova CRUD upitima
															- OFF - biće prikazan broj redova
	
	pitanje: kada uključiti, a kada isključiti nocount?

*/

/*
	II - 1. testiranje broja redova
*/


create or alter procedure test as
--set nocount off;
	select	* 
	from	student 
	--where	student_ime = 'Ana'
;

execute test;

drop procedure test;

/*
	kreiranje procedure za proveru broja redova
*/
create or alter procedure check_rownumber as
set nocount off;
	declare @source_count int;
	declare @destination_count int;
 
	select @source_count = (select count(*) from studenti_i_predmeti);
	select @destination_count = (select count(*) from studenti_i_ocene_po_predmetima);

	if @source_count < @destination_count 
		print concat(N'Imate više redova u destination_tabelama: ',(@destination_count - @source_count), ' !');
	else if @destination_count < @source_count
		print concat(N'Imate više redova u souce_tabelama: ', (@source_count - @destination_count), ' !');
	else -- @destination_count = @source_count
		print N'Broj redova je uredu!';
;

execute check_rownumber;

/*
	kreiranje procedure za proveru razlike u redovima između sorce i destination tabela
*/
create or alter procedure check_row_diff as
set nocount on;
/* 
	da bismo mogli da koristimo CTE kojii smo vec napisali i ispitujemo redove - napravićemo kursor (pandam result set-u u javi ili c#)

	Kursor se u bazama podataka koristi kao struktura pomoću koje pristupamo redovima koji su rezultat izvršenja upita. 
	~~ Klasa iz objektnih jezika je entitet u BP, a kursor je lista.
	I u sintaksi stoji deklarišemo promenljivu kursor za upit.

	više o kursorima: https://learn.microsoft.com/en-us/sql/t-sql/language-elements/cursors-transact-sql?view=sql-server-ver16
*/
declare diff cursor for 
	with source as (
		select	indeks,
				student_ime,
				student_prezime,
				mesto,
				ppt,
				predmet_naziv,
				broj_predavanja,
				ocena
				--,ROW_NUMBER() over ( order by indeks)
		from	studenti_i_predmeti
	),
	destination as (
		select	s.indeks,
				s.student_ime,
				s.student_prezime,
				(select m.naziv from mesto m where m.ppt = s.ppt) as mesto,
				s.ppt,
				p.predmet_naziv,
				p.broj_predavanja,
				o.ocena
				--,ROW_NUMBER() over ( order by s.indeks, broj_predavanja)
		from	student s
		join	student_slusa_predmet ssp
			on	s.indeks = ssp.indeks
		join	predmet p
			on	ssp.predmet_id = p.predmet_id
		join	ocene o
			on  ssp.indeks = o.indeks
			and ssp.predmet_id = o.predmet_id
	),
	source_minus_destination as (
	select 'source_minus_destination' direction, smd.* 
		from (
			select	s.*
			from	source s
			except	
			select	d.*
			from	destination d
		) smd
	),
	destination_minus_source as (
		select 'destination_minus_source' direction, dms.* 
		from (
			select	d.*
			from	destination d
			except	
			select	s.*
			from	source s
		) dms
	)
	select	*
	from	source_minus_destination
	union
	select	*
	from	destination_minus_source; 
	-- diff cursor END

	declare @direction varchar(100);
	declare @indeks varchar(100);
	declare @student_ime varchar(100);
	declare @student_prezime varchar(100);
	declare @mesto varchar(100);
	declare @ppt varchar(100);
	declare @predmet_naziv varchar(100);
	declare @broj_predavanja int;
	declare @ocena int;
begin
	open diff;	-- open cursor 
	/*
		sintaksa if naredbe:
			if condition
				1 statement;
			[ else
				1 statement;]

		ako 
	*/
	if @@CURSOR_ROWS < 0
	begin
		print 'Nema razlike u redovima.';
		close diff;  
		deallocate diff;  
	end
	fetch next from diff; -- set cursor pointer to the first row

	print N'Ima razlike u redovima.';

	--print 'fetch status: '+cast(@@FETCH_STATUS as nvarchar);
	--if @@CURSOR_ROWS > 0
	--begin
	--	print concat(N'@@CURSOR_ROWS= ', @@CURSOR_ROWS);
	--end
	
	while @@FETCH_STATUS = 0  
	begin  
	   fetch next from diff
	   into			@direction,
					@indeks,
					@student_ime,
					@student_prezime,
					@mesto,
					@ppt,
					@predmet_naziv,
					@broj_predavanja,
					@ocena;
	    print concat('test ispis: ',
					@direction, ', ',
					@indeks, ', ',
					@student_ime, ', ',
					@student_prezime, ', ',
					@mesto, ', ',
					@ppt, ', ',
					@predmet_naziv, ', '
					,cast(@broj_predavanja as nvarchar), ', '
					,cast(@ocena as nvarchar));
	end;
  
	close diff;  
	deallocate diff;  
end
; -- check_row_diff END

execute check_row_diff;

select * from studenti_i_predmeti;

/*
	dodati novi red u source/destination tabelama da bi se videlo kako testovi rade
*/
insert into studenti_i_predmeti --(indeks	student_ime	student_prezime	mesto	ppt	predmet_naziv	direction	broj_predavanja	ocena
values ('1235/2020',	'Ana',	'Anic',	'Beeeograd',	'11000',	'Programiranje 1',	55,	15);




