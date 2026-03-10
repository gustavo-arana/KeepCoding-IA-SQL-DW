
/*	Introducción: 
La tabla Flights registra la información de vuelos en España (Origen/Destino) entre el periodo de 05-Jun-2021 al 17-Feb-2026, almacenando la actualización del estado del vuelo cada 6 horas desde su despuegue hasta su llegada.

En la información contenida encontramos fecha de salida/llegada (hora local/gtm), aerolinea, ticket, ruta, delay, estado fecha de creación y fecha de actualización, el id de la tabla es flight_row_id un campo autoincremental numerico, pero el id de la transaccion del vuelo se almacena en el campo unique_identifier.
*/


/*-------  # Enunciado 1
Explora el fichero flights y analiza:
1. Cuántos registros hay en total
2. Cuántos vuelos distintos hay
*/


select
	count(flight_row_id) as count_total_rows,
	count(distinct unique_identifier) as count_flights_unique,
	count(distinct airline_code) as count_unique_airlie_code,
	min(local_departure) as min_local_departure,
	max(local_departure) as max_local_departure
from flights;

/*	Interpretación: Existe un total de 1,209 registros en la tabla que pertenecen a 266 vuelos únicos registrados, de 25 aerolíneas que volaron a España entre el 05-Jun-2021 y 17-Feb-2026.
*/


--	3. Cuántos vuelos tienen más de un registro

with base_flight as (
	select 
		unique_identifier as unique_identifier,
		count(flight_row_id) as count_total_rows
	from flights
	group by 1
)
/*
Query de exploración para comprobar la cantidad de registros por vuelo
select *
from base_flight
order by count_total_rows desc;*/
select
	count(unique_identifier) as total_flights,
	round(avg(count_total_rows),0) as average_rows_per_flights,
	min(count_total_rows) as min_rows_per_flights,
	max(count_total_rows) as max_rows_per_flights
from base_flight
where count_total_rows > 1;


/*	Interpretación: Actualmente existen 250 vuelos que tienen mas de 2 registros de los 266 registrados, un 94% de los vuelos presentan alguna novedad sobre su hora programada de despegue y aterrizaje, donde existe un promedio de 5 registro por vuelo, siendo el vuelo AV-47-20211101-MAD-BOG con mas registros.
*/


/*-------  # Enunciado 2
Por qué hay registro duplicados para un mismo vuelo. Para ello, selecciona varios vuelos y
analiza la evolución temporal de cada vuelo.

1. Qué información cambia de un registro a otro
*/

select *
from flights;

with base_flight as (
	select
		flight_row_id,
		unique_identifier,
		local_departure,
		local_actual_departure,
		local_arrival,
		local_actual_arrival,
		gmt_departure,
		gmt_actual_departure,
		gmt_arrival,
		gmt_actual_arrival,
		departure_airport,
		arrival_airport,
		airline_code,
		delay_mins,
		arrival_status,
		created_at,
		updated_at
	from flights
), duplicated_flights as (
	select
		unique_identifier as unique_identifier,
		count(flight_row_id) as count_total_rows
	from flights		
	group by 1
	having count(flight_row_id) > 1
)
select *
from base_flight
where unique_identifier in (select unique_identifier from duplicated_flights);

/*	Interpretación: La tabla registra el estado del vuelo cada 6 horas, actualizando la información del despegue (departure), llegada (arrive) en su hora local y gmt, adicional cuando ha aterrizado, el vuelo registra el delay de con valores positivos si llego mas tarde de lo previsto o negativo 	si se anticipo a su llegada y la fecha de actualización updated_at.
*/

/*-------  # Enunciado 3
Evalúa la calidad del dato. La calidad del dato nos indica si la información es consistente,
completa, coherente y representa una realidad verosímil. Para ello debemos establecer
unos criterios:

1. La información de created_at debe ser única para cada vuelo aunque tenga más de un registro.	
*/
with flight_check_created_at as (
	select
		unique_identifier as unique_identifier,		
		count(flight_row_id) as count_total_rows,
		count(distinct created_at) as count_created_at
	from flights
	group by 1
	having count(distinct created_at) <> 1
) 	
select
	flight_row_id,
	unique_identifier,
	local_departure,
	created_at,
	updated_at,
	*
from flights
where unique_identifier in (select unique_identifier from flight_check_created_at);

/*	Interpretación: La información de la tabla no es 100% confiable ya que algunos registros no tienen fecha de created_at, lo cual corresponde a 569 registros de 1,209 un 47% de la información.
*/

-- 2. La información de updated_at deber ser igual o más que la información de created_at, lo que nos indica coherencia y consistencia

select
	count(flight_row_id) as count_rows_flights
from flights
where created_at is not null
	and updated_at is not null
	and updated_at < created_at;

/*	Interpretación: La información del campo updated_at es 100% confiable descartando los casos donde no se registra información en created_at y updated_at.
*/

/*-------  # Enunciado 4
El último estado de cada vuelo. Cada vuelo puede aparecer varias veces en el dataset, para avanzar con nuestro análisis necesitamos quedarnos solo con el último registro de cada vuelo.

*No vamos a descartar los registros de información en created_at y updated_at identificados como nulos,
vamos a realizar un analisis de donde podriamos recontruir la información y crear una vista con los registros actualizados.
*/

-- 	1. Para el caso de created_at el campo que puede contener esta información es local_departure, se deduce a raíz de las siguientes Querys.

-- Listamos todos los campos que contienen una fecha
select
	 flight_row_id,
	 unique_identifier,
	 local_departure,
	 local_actual_departure,
	 local_arrival,
	 local_actual_arrival,
	 gmt_departure,
	 gmt_actual_departure,
	 gmt_arrival,
	 gmt_actual_arrival,
	 delay_mins,
	 created_at,
	 updated_at
from flights;


/* Buscando una relacion de created_at con cada campo, se evidencia que el que mejor se relaciona es local_departure y se puede interpretar que el registro se crea un 24 horas antes del vuelo.*/

select
	 flight_row_id as flight_row_id,
	 unique_identifier as unique_identifier,
	 local_departure as local_departure,
	 created_at as created_at,
	 local_departure - interval '1 day' as new_created_at,
	 created_at - (local_departure - interval '1 day') as diff
from flights
where created_at is not null;

-- Se analiza la estimación de la fecha created_at a partir de esta logica y funciona, para los registros donde
-- no existe un nulo la diferencia es 00 y se evidencia que en local departure existen nulos.

select
 count(flight_row_id)
from flights
where created_at is not null;
-- Se obtienen 640 registros con información.

select
 count(flight_row_id)
from flights
where created_at is null;
-- Se obtienen 569 registros SIN INFORMACIÓN

-- Query limpia estimando el created_at
with base_flight as (
	select
		flight_row_id,
		unique_identifier,
		local_departure,
		local_actual_departure,
		local_arrival,
		local_actual_arrival,
		gmt_departure,
		gmt_actual_departure,
		gmt_arrival,
		gmt_actual_arrival,
		departure_airport,
		arrival_airport,
		airline_code,
		delay_mins,
		arrival_status,
		created_at,
		case
			when created_at is null then local_departure - interval '1 day'
			else created_at
		end as new_created_at,
		updated_at
	from flights
) 
select *
from base_flight;


-- 	2. Para el caso de update_at el campo que puede contener esta información es local_departure, por lo cual se ejecutan las siguientes Querys.

/* Pruebas donde se determina que la actualización del registro ocurre cada seis horas a partir del created_at, se identifica con el row_number su posición en la ventana y se multiplica en factores de 6 de acuerdo a su rn considerando restar 1.

**Se asume que los registros se insertaron en orden tomando como base el flight_row_id
*/

with base as (
	select
		 flight_row_id,
		 unique_identifier,
		 local_departure,
		 local_arrival,
		 gmt_arrival,	 
		 delay_mins,
		 created_at,
		 updated_at,
		 created_at - updated_at as diff,
		 row_number() over(partition by unique_identifier order by flight_row_id asc) as rn		 
	from flights
	where created_at is not null
), base_estimated_updated_at as (
	select
		flight_row_id,
		unique_identifier,
		local_departure,
		local_arrival,
		gmt_arrival,
		delay_mins,
		created_at,
		updated_at,
		diff,
		rn,
		case
			when updated_at is null and rn = 1 then created_at 
			else created_at + (interval '1 hour' * ((rn-1)*6))
		end as new_updated_at
	from base
)
select 
	*,
	updated_at - new_updated_at as diff_updated_at
from base_estimated_updated_at;

/*Creación de la vista flight_completed que contendra la información del último registro del vuelo,
new_created_at y new_updated_at*/

drop view flight_completed;
create view flight_completed as
with base_flight as (
	--Trae los campos de flight, calcula el new_created_at y calcula la ventana.
	select
		flight_row_id as flight_row_id,
		unique_identifier as unique_identifier,
		local_departure as local_departure,
		local_actual_departure as local_actual_departure,
		local_arrival as local_arrival,
		local_actual_arrival as local_actual_arrival,
		gmt_departure as gmt_departure,
		gmt_actual_departure as gmt_actual_departure,
		gmt_arrival as gmt_arrival,
		gmt_actual_arrival as gmt_actual_arrival,
		departure_airport as departure_airport,
		arrival_airport as arrival_airport,
		airline_code as airline_code,
		delay_mins as delay_mins,
		arrival_status as arrival_status,
		created_at as created_at,
		case
			when created_at is null then local_departure - interval '1 day'
			when created_at is not null then created_at
			else NULL
		end as new_created_at,
		updated_at as updated_at,
		row_number() over(partition by unique_identifier order by flight_row_id asc) as rn
	from flights
), base_flight_completed as (
	--Calcula el uptated_at y el unique_identifier_rn, para identificar ese registro como si fuera una llave de la tabla ligado a la ventana.
	select
		flight_row_id as flight_row_id,
		unique_identifier as unique_identifier,
		concat(unique_identifier,'-',rn) as unique_identifier_rn,
		local_departure as local_departure,
		local_actual_departure as local_actual_departure,
		local_arrival as local_arrival,
		local_actual_arrival as local_actual_arrival,
		gmt_departure as gmt_departure,
		gmt_actual_departure as gmt_actual_departure,
		gmt_arrival as gmt_arrival,
		gmt_actual_arrival as gmt_actual_arrival,
		departure_airport as departure_airport,
		arrival_airport as arrival_airport,
		airline_code as airline_code,
		delay_mins as delay_mins,
		arrival_status as arrival_status,
		created_at as created_at,
		new_created_at as new_created_at,
		updated_at as updated_at,
		case
			when updated_at is null and rn = 1 then new_created_at
			when updated_at is null then new_created_at + (interval '1 hour' * ((rn-1)*6))
			when updated_at is not null then updated_at
			else NULL
		end as new_updated_at,
		rn as rn
	from base_flight
), base_flight_max_row as (
	/*Query que determina cual es unique_identifier_rn con maximo valor, que seria el registro mas actualizado
	calcula el unique_identifier_rn_calc por que si se trajera como dimension, tendriamos el max por unique_identifier_rn
	lo cual seria la misma tabla.
	*/
	select
		unique_identifier as unique_identifier,
		concat(unique_identifier,'-',max(rn)) as unique_identifier_rn_calc,
		max(rn) as max_rn
	from base_flight_completed
	group by 1
)
--Consulta final con la condición de unique_identifier_rn sea igual al unique_identifier_rn_calc, del CTE base_flight_max_row
select
	flight_row_id as flight_row_id,
	unique_identifier as unique_identifier,
	unique_identifier_rn as unique_identifier_rn,
	local_departure as local_departure,
	local_actual_departure as local_actual_departure,
	local_arrival as local_arrival,
	local_actual_arrival as local_actual_arrival,
	gmt_departure as gmt_departure,
	gmt_actual_departure as gmt_actual_departure,
	gmt_arrival as gmt_arrival,
	gmt_actual_arrival as gmt_actual_arrival,
	departure_airport as departure_airport,
	arrival_airport as arrival_airport,
	airline_code as airline_code,
	delay_mins as delay_mins,
	arrival_status as arrival_status,
	created_at as created_at,
	new_created_at as new_created_at,
	updated_at as updated_at,
	new_updated_at as new_updated_at,
	rn as rn	
from base_flight_completed
where unique_identifier_rn in (select unique_identifier_rn_calc from base_flight_max_row)
order by flight_row_id;

-- Query de la vista
select *
from flight_completed;

-- Comprobamos la cantidad de registros
select 
	count(flight_row_id) as total_rows,
	count(distinct unique_identifier) as total_unique_flight
from flight_completed;

-- Comprobación de registros nulos en new_created_at/new_updated_at
select
	count(flight_row_id)
from flight_completed
where new_created_at is null
 	or new_updated_at is null;

/*-------  # Enunciado 5
Considerando que los campos local_departure y local_actual_departure son necesarios
para el análisis, valida y reconstruye estos valores siguiendo estas reglas:

	1. Si local_departure es nulo, utiliza created_at.
	2. Si local_actual_departure es nulo, utiliza local_departure. Si este también es nulo, utiliza created_at.

Crea dos nuevos campos:

● effective_local_departure
● effective_local_actual_departure	
*/

-- Se agregan los campos effective_local_departure y effective_local_actual_departure
select 
	flight_row_id as flight_row_id,
	unique_identifier as unique_identifier,
	local_departure as local_departure,
	local_actual_departure as local_actual_departure,
	local_arrival as local_arrival,
	local_actual_arrival as local_actual_arrival,
	new_created_at,
	new_updated_at,
	case
		when local_departure is not null then local_departure
		when local_departure is null then new_created_at
		else NULL
	end as effective_local_departure,
	case
		when local_actual_departure is not null then local_actual_departure
		when local_actual_departure is null and local_departure is not null
			then local_departure
		when local_actual_departure is null and local_departure is null
			then new_created_at
		else NULL
	end as effective_local_actual_departure
from flight_completed;


/*	Extra:
	Realiza las validaciones para los campos local_arrival y local_actual_arrival
*/

-- 1. Analizar los datos en local_arrival y local_actual_arrival
select
	flight_row_id as flight_row_id,
	unique_identifier as unique_identifier,
	local_departure as local_departure,
	local_actual_departure as local_actual_departure,
	local_departure - local_actual_departure as diff_departure,
	local_arrival as local_arrival,
	local_actual_arrival as local_actual_arrival,
	local_arrival - local_actual_arrival as diff_arrival,
	delay_mins as delay_mins,
	new_created_at,
	new_updated_at
from flight_completed
-- where local_arrival is null verificamos y local_arrival no tiene nulos
-- where delay_mins is null
where local_actual_arrival is null;

select
	distinct arrival_status
from flight_completed;
--where delay_mins is null --Result CX, DY, EY, NS, OT
--where delay_mins is not null --Result DY, EY, OT

/*2. Se evidencia que el local_actual_arrival esta relacionado con el local_arrival y el delay_mins, por lo que primero vamos a estimar el delay_mins para posterior sumar al local_arrival y crear la oclumna effective_local_actual_arrival*/

with base as (
	select
		*,		
		extract(minute from (local_departure - local_actual_departure))::integer as diff_departure,	
		local_actual_arrival - local_arrival as diff_arrival,
		case
			when delay_mins is not null then delay_mins
			when delay_mins is null and local_actual_departure is not null
				then extract(minute from (local_departure - local_actual_departure))::integer
			else 0
		end as new_delay_mins
	from flight_completed
) 
select 
	flight_row_id as flight_row_id,
	unique_identifier as unique_identifier,
	local_departure as local_departure,
	local_actual_departure as local_actual_departure,
	diff_departure as diff_departure,
	local_arrival as local_arrival,
	local_actual_arrival as local_actual_arrival,
	case
		when local_actual_arrival is not null then local_actual_arrival
		when local_actual_arrival is null then local_arrival + (interval '1 minute' * new_delay_mins)
		else NULL
	end as effective_local_actual_arrival,	
	delay_mins as delay_mins,
	new_delay_mins as new_delay_mins,
	new_created_at,
	new_updated_at
from base;

--Query Final (Se crea la vista flight_completed_v2)
drop view flight_completed_v2;
create view flight_completed_v2 as
with base as (
	select
		*,		
		extract(minute from (local_actual_departure - local_departure))::integer as diff_departure,
		case
			when delay_mins is not null then delay_mins
			when delay_mins is null and local_actual_departure is not null
				then extract(minute from (local_actual_departure - local_departure))::integer
			else 0
		end as new_delay_mins
	from flight_completed
)
select
	flight_row_id as flight_row_id,
	unique_identifier as unique_identifier,
	case
		when local_departure is not null then local_departure
		when local_departure is null then new_created_at
		else NULL
	end as effective_local_departure,
	case
		when local_actual_departure is not null then local_actual_departure
		when local_actual_departure is null and local_departure is not null
			then local_departure
		when local_actual_departure is null and local_departure is null
			then new_created_at
		else NULL
	end as effective_local_actual_departure,
	local_arrival as effective_local_arrival,
	case
		when local_actual_arrival is not null then local_actual_arrival
		when local_actual_arrival is null then local_arrival + (interval '1 minute' * new_delay_mins)
		else NULL
	end as effective_local_actual_arrival,
	gmt_departure as gmt_departure,
	gmt_actual_departure as gmt_actual_departure,
	gmt_arrival as gmt_arrival,
	gmt_actual_arrival as gmt_actual_arrival,
	departure_airport as departure_airport,
	arrival_airport as arrival_airport,
	airline_code as airline_code,
	new_delay_mins as new_delay_mins,
	arrival_status as arrival_status,
	new_created_at as new_created_at,
	new_updated_at as new_updated_at
from base;

-- Query de la vista
select *
from flight_completed_v2;

-- Comprobamos la cantidad de registros
select 
	count(flight_row_id) as total_rows,
	count(distinct unique_identifier) as total_unique_flight
from flight_completed_v2;

-- Comprobación de registros nulos en los nuevos campos.
select
	count(flight_row_id)
from flight_completed_v2
where effective_local_departure is null
 	or effective_local_actual_departure is null
 	or effective_local_actual_arrival is null
 	or new_delay_mins is null;

/*-------  # Enunciado 6
Análisis del estado del vuelo. Haciendo uso del resultado del enunciado 4, analiza los estados de los vuelos.

1. Qué estados de vuelo existen	
*/

select
	distinct arrival_status
from flight_completed;

--2. Cuántos vuelos hay por cada estado
select
	distinct arrival_status,
	count(flight_row_id)
from flight_completed
group by 1
order by 2 desc;

-- ¿Podrías decir qué significa las siglas de cada estado?
-- Exploración

-- Validación Relacion del Flight Status con el Delay
select
	arrival_status as arrival_status,
	delay_mins as delay_mins,
	count(distinct unique_identifier) as count_flights
--from flights
from flight_completed
group by 1, 2
order by 1, 2;

--
select 
	unique_identifier,
	local_departure,
	local_actual_departure,
	local_arrival,
	local_actual_arrival,
	arrival_status,
	delay_mins
from flight_completed
where arrival_status = 'OT'
--	and (delay_mins in (5, 15)
--		or delay_mins is NULL);
;

-- Analisis de los datos por Arrival Status, donde el delay es NULL
select 
	*,
	local_departure - local_arrival as diff
--from flights
from flight_completed
--where arrival_status = 'CX'
where arrival_status = 'DY'
--where arrival_status = 'NS'
--where arrival_status is null
;

-- Analisis de los datos por status, airport y delay
select
	arrival_status,
	departure_airport,
	arrival_airport,
	airline_code,
	delay_mins
from flight_completed
group by 1, 2, 3, 4, 5
order by 1, 2, 3, 4;

/* Conclusión de la pregunta: ¿Podrías decir qué significa las siglas de cada estado?
 Los datos son muy variables en todos los estados no se logro encontrar un patron,
 en algunos no estan las horas actuales, pero no es por la ruta de vuelo o fecha,
 los diferentes estados presentan las mismas faltas de información, no depende del vuelo o ruta, etc.
 Lo mas cercano seria:
 
 CX=todos los delay_mins son NULL.
 DY=El delay mins es positivo, vuelos que se retrasaron en su llegada.
 EY=El delay mins es negativo, vuelos que registraron su llegada mas pronto de su hora programada.*/
 
 
/*-------  # Enunciado 7
País de salida de cada vuelo. Tienes disponible un csv. con información de aeropuertos airports.csv. Haciendo uso del resultado del enunciado 4, analiza los aeropuertos de salida.
*/

-- Exploración de la tabla.
select *
from airports
limit 5;

-- 1. De qué país despegan los vuelos
-- Query donde se evidencia de que pais despegan los vuelos y la cantidad registrada.
select
	airp.country as country
from flight_completed as fli
left join airports as airp
	on fli.departure_airport = airp.airport_code
group by 1
order by 1;

-- 2. Cuántos vuelos despegan por país
-- Query donde se evidencia de que pais despegan los vuelos y la cantidad registrada.
select
	airp.country as country,
	count(fli.flight_row_id) as count_flights
from flight_completed as fli
left join airports as airp
	on fli.departure_airport = airp.airport_code
group by 1
order by 2 desc;

-- Extra: Validación de los vuelos que tienen Pais Nulo
select 
	fli.flight_row_id,
	fli.unique_identifier,
	fli.departure_airport,
	airp.country
from flight_completed as fli
left join airports as airp
	on fli.departure_airport = airp.airport_code
where airp.country is null;

-- Comprobación en la tabla de Airports de los Aeropuertos Nulos
with base as (
	select 
		distinct fli.departure_airport as airport
	from flight_completed as fli
	left join airports as airp
		on fli.departure_airport = airp.airport_code
	where airp.country is null
)
select *
from airports
where airport_code in (select airport from base);

/* Podemos evidenciar que algunos de los aeropuertos de salida de los vuelos registrados, no estan creados en la tabla de airports lo cual corresponden a 43, el pais que mas vuelos tiene es España con 131, con 1 vuelo Italia y Alemania*/

/*-------  # Enunciado 8
Delay medio y estado de vuelo por país de salida. Haciendo uso del resultado del enunciado 4, analiza el estado y el delay/retraso medio con el objetivo de identificar si existen países que pueden presentar problemas operativos en los aeropuertos de salida.

1. Cuál es el delay medio por país
2. Cuál es la distribución de estados de vuelos por país.

Extra:
Representa gráficamente la distribución de estados por país. Puedes dibujar un gráfico de
barras o representarlo como creas que mejor se visualiza.
*/

-- 1. Cuál es el delay medio por país
with base as (
	select
		flg.unique_identifier as unique_identifier,
		flg.effective_local_departure as effective_local_departure,
		flg.effective_local_actual_departure as effective_local_actual_departure,
		extract(minute from (flg.effective_local_actual_departure - flg.effective_local_departure))::integer as diff,
		flg.departure_airport as departure_airport,
		flg.arrival_status as arrival_status,
		apt.country as country
	from flight_completed_v2 as flg
	left join airports as apt
		on flg.departure_airport = apt.airport_code
		
), final as (
	select
		case
			when country is not null then country
			else 'Unknow'
		end as country,
		count(unique_identifier) as count_flights,
		min(diff) as min_delay,
		max(diff) as max_delay,
		round(avg(diff),0) as average_delay
	from base
	group by 1
)
select *
from final
order by 5 desc;

/*
El pais que tiene una media con una media de retrasos mas alta es Estados Unidos y con menor valor Italia/Alemania, pero es importante considerar la cantidad de vuelos que registran (Solo 1 vuelo), por lo que no seria adecuadro asumir que todos los vuelos son tan exactos o con una media tan baja para todos los vuelos fuera de estos datos.

Adicional tenemos un apartado de desconocidos con datos muy variables, vuelos con un delay de -15 y 45.
*/


--2. Cuál es la distribución de estados de vuelos por país.
with base as (
	select
		flg.unique_identifier as unique_identifier,
		flg.effective_local_departure as effective_local_departure,
		flg.effective_local_actual_departure as effective_local_actual_departure,
		extract(minute from (flg.effective_local_actual_departure - flg.effective_local_departure))::integer as diff,
		flg.departure_airport as departure_airport,
		flg.arrival_status as arrival_status,
		apt.country as country
	from flight_completed_v2 as flg
	left join airports as apt
		on flg.departure_airport = apt.airport_code
		
), final as (
	select
		case
			when country is not null then country
			else 'Unknow'
		end as country,
		case 
			when arrival_status is not null then arrival_status
			else 'Unknow'
		end as arrival_status,
		count(unique_identifier) as count_flights,
		min(diff) as min_delay,
		max(diff) as max_delay,
		round(avg(diff),0) as average_delay		
	from base
	group by 1, 2
)
select *
from final
order by 1, 2;


/*Extra: Organizando los datos por estado y la cantidad de vuelos, podemos determinar que DY es el estado con mas vuelos a excepción de Italia/Germania pero debemos considerar que solo tienen un vuelo.
*/

with base as (
	select
		flg.unique_identifier as unique_identifier,
		flg.effective_local_departure as effective_local_departure,
		flg.effective_local_actual_departure as effective_local_actual_departure,
		extract(minute from (flg.effective_local_actual_departure - flg.effective_local_departure))::integer as diff,
		flg.departure_airport as departure_airport,
		flg.arrival_status as arrival_status,
		apt.country as country
	from flight_completed_v2 as flg
	left join airports as apt
		on flg.departure_airport = apt.airport_code
		
), base_group as (
	select
		case
			when country is not null then country
			else 'Unknow'
		end as country,
		arrival_status as arrival_status,
		count(unique_identifier) as count_flights,
		min(diff) as min_delay,
		max(diff) as max_delay,
		round(avg(diff),0) as average_delay		
	from base
	group by 1, 2
), final as (
	select 
		*,
		row_number() over(partition by country order by count_flights desc) as rn
	from base_group
)
select *
from final
where rn = 1;


/*-------  # Enunciado 9
El estado de vuelo por país y por época del año. Dado que no en todas las épocas del año las condiciones climatólogicas son iguales, analiza si la estaciones del año impactan en el delay medio por país. Considera la siguiente clasificación de meses del año por época:

● Invierno: diciembre, enero, febrero
● Primavera: marzo, abril, mayo
● Verano: junio, julio, agosto
● Otoño: septiembre, octubre, noviembre
*/

with base as (
	select
		flg.unique_identifier as unique_identifier,
		flg.effective_local_departure as effective_local_departure,
		flg.effective_local_actual_departure as effective_local_actual_departure,
		extract(minute from (flg.effective_local_actual_departure - flg.effective_local_departure))::integer as diff,
		flg.departure_airport as departure_airport,
		flg.arrival_status as arrival_status,
		apt.country as country,
		extract(month from flg.effective_local_departure)::integer as month
	from flight_completed_v2 as flg
	left join airports as apt
		on flg.departure_airport = apt.airport_code
		
), base_group as (
	select
		case
			when country is not null then country
			else 'Unknow'
		end as country,
		arrival_status as arrival_status,
		case
			when month in (12, 1, 2) then 'Invierno'
			when month in (3, 4, 5) then 'Primavera'
			when month in (6, 7, 8) then 'Verano'
			when month in (9, 10, 11) then 'Otoño'
			else 'Unknow'
		end as season,		
		count(unique_identifier) as count_flights,
		min(diff) as min_delay,
		max(diff) as max_delay,
		round(avg(diff),0) as average_delay		
	from base
	group by 1, 2, 3
), final as (
	select 
		*,
		row_number() over(partition by country order by count_flights desc) as rn
	from base_group
)
select 
	country,
	arrival_status,
	season,
	count_flights,
	average_delay,
	rn
from final
--where rn = 1
order by country, rn;

/*El clima si puede generar retrasos e impactar el delay medio por pais, la mayoria son afectados por las epocas de Otoño/Invierno que suelen ser epocas de lluvias y tormentas. 

Pero para el caso de Paises Bajos tiene un buen registro de puntulalidad entre 5 - 8 minutos de retraso, existe un outlier de un vuelo en invierno de 23 minutos de retraso lo cual impacta su media.
*/


/*-------  # Enunciado 10
Frecuencia de actualización de los vuelos. Volviendo al análisis de la calidad del dataset, explora con qué frecuencia se registran actualizaciones de cada vuelo y calcula la frecuencia media de actualización por aeropuerto de salida.
*/

with base as (
	select
		flight_row_id as flight_row_id,
		unique_identifier as unique_identifier,
		created_at as created_at,
		updated_at as updated_at,
		lag(updated_at) over(partition by unique_identifier order by updated_at asc) as after_updated_at,
		(updated_at - lag(updated_at) over(partition by unique_identifier order by updated_at asc)) as diff,
		departure_airport
	from flights
), base_frequency as (
	select
		unique_identifier,
		departure_airport,
		(extract(EPOCH from diff)::integer/3600) diff_hours
		--Ayuda: StackOverflow https://es.stackoverflow.com/questions/382539/como-calcular-las-horas-entre-fechas-en-postgresql
	from base
)
select
	departure_airport as departure_airport,
	round(avg(diff_hours),0) as avg_diff_hours
from base_frequency
group by departure_airport;

--Respuesta: El promedio de actualización de por vuelo es de 6 horas y es igual para todos los aeropuertos.

/*-------  # Enunciado 11
Consistencia del dato. El campo unique_identifier identifica el vuelo y se construye con: aerolínea, número de vuelo, fecha y aeropuertos. Para cada vuelo (último snapshot), comprueba si la información del unique_identifier es consistente con las columnas del dataset.

1. Crea un flag is_consistent.
2. Calcula cuántos vuelos no son consistentes.
3. Usando la tabla airlines, muestra el nombre de la aerolínea y cuántos vuelos no consistentes tiene.
*/
with base as (
	select
		flight_row_id,
		unique_identifier,
		split_part(unique_identifier, '-', 1) as airline_split,
		split_part(unique_identifier, '-', 2) as flight_number,
		split_part(unique_identifier, '-', 3) as ticket,
		split_part(unique_identifier, '-', 4) as departure_airport_split,
		split_part(unique_identifier, '-', 5) as arrival_airport_split,
		local_departure,
		replace(substr(cast(local_departure as text),1,10),'-','') as local_departure_text,
		airline_code as airline_code,
		departure_airport as departure_airport,
		arrival_airport as arrival_airport
	from flights
), base_consistent as (
	select
		unique_identifier,
		case
			when airline_code <> airline_split then False
			when departure_airport <> departure_airport_split then False
			when arrival_airport <> arrival_airport_split then False
			else True
		end as is_consistent
	from base
)
select
	is_consistent as is_consistent,
	count(distinct unique_identifier) as total_flights
from base_consistent
group by 1;
/*
--Query para analizar las diferencias
select 
	unique_identifier,
	airline_split,
	airline_code,
	departure_airport_split,
	departure_airport,
	arrival_airport_split,
	arrival_airport
from base
where unique_identifier in (select unique_identifier from base_consistent where is_consistent = False);*/

--2. Calcula cuántos vuelos no son consistentes.
--Respuesta: 15 Vuelos no tienen la información consistente e identificando las diferencias se presenta en los tres campos (airline_code, departure_airport y arrival_airport).