/* Вопрос 1. В каких городах больше одного аэропорта? */
select city "Город", count(airport_code) "Число аэропортов" from airports
group by 1
having count(airport_code)>1


/* Вопрос 2. В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета? */
-- Логика: 1) находим код самолёты с максимальной дальностью, 
--         2) фильтруем аэропорты отправления и прибытия по этому коду и объединяем
--			Необходимо смотреть аэропорты отправления и прибытия, поскольку могут быть случаи без
--          обратного рейса. Маловероятно, но возможно).
--          Не применял CTE, поскольку хотел усилить показ использования требуемого вложенного запроса.
select distinct departure_airport "Искомые Аэропорты" from flights
where aircraft_code in 
						(
						select aircraft_code from aircrafts
						order by range desc
						limit 1
						) 
union
select distinct arrival_airport from flights
where aircraft_code in 
						(
						select aircraft_code from aircrafts
						order by range desc
						limit 1
						)

/* Вопрос 3. Вывести 10 рейсов с максимальным временем задержки вылета */
select *, actual_departure-scheduled_departure delay from flights
where actual_departure is not null
order by delay desc
limit 10

/* Вопрос 4. Были ли брони, по которым не были получены посадочные талоны? */
-- Логика: В таблице tickets все детали по бронированию, включая все ticket_no.
--         В таблице boarding_passes информация по выданным талонам, привязанным к ticket_no.
--         ticket_no уникальны и с другой стороны посадочные талоны выдают сразу даже на маршрут с
--         несколькими пересадками, поэтому для решения задачи flight_id не нужен и сджойнив слева по
--         ticket_no мы присоединим все существующие ticket_no из boarding_passes, а там где их нет будет null,
--         что и выбираем фильтрацией. Ответ: были брони, по которым не получены посадочные талоны.

select t.ticket_no from tickets t
left join boarding_passes bp on t.ticket_no =bp.ticket_no 
where bp.ticket_no is null

/* Вопрос 5.  Найдите количество свободных мест для каждого рейса, их % отношение к общему количеству мест в самолете. 
 Добавьте столбец с накопительным итогом - суммарное накопление количества вывезенных пассажиров из каждого аэропорта 
 на каждый день. Т.е. в этом столбце должна отражаться накопительная сумма - сколько человек уже вылетело из данного 
 аэропорта на этом или более ранних рейсах в течении дня */

with max_seats_by_model as -- CTE рассчитали число максимальной вместимости по каждой модели самолёта
	(
	select	s.aircraft_code,
			count(s.seat_no) max_seats
	from seats s 
	group by s.aircraft_code
	)
select 
	t.flight_no,
	t.departure_airport,
	t.actual_departure::date, -- показываем только дни
	t.total_passes_given,
	msm.max_seats - t.total_passes_given number_free_seats, 
	round((msm.max_seats - t.total_passes_given) / msm.max_seats :: numeric, 2) * 100 free_seats_ratio,
	sum(t.total_passes_given) over (partition by (t.departure_airport, t.actual_departure::date) -- окно: группируем по аэропорту отправления и дню
									order by t.actual_departure) "Cumulatively departed passangers" -- нарастающий итог по времени
from 
	( -- вложенный запрос для расчёта кол-ва выданных посадочных талонов и подтягивания необходимой информации
	select	f.flight_id,
			f.flight_no,
			f.aircraft_code,
			f.departure_airport,
			f.actual_departure,
			count(bp.boarding_no) total_passes_given
	from flights f 
	join boarding_passes bp on bp.flight_id = f.flight_id 
	where status in ('Departed', 'Arrived') -- выбираем рейсы которые или уже прибыли или вылетели
	--where f.actual_departure is not null -- другой вариант фильтра выбора рейсов
	group by f.flight_id 
	) t
join max_seats_by_model msm on msm.aircraft_code = t.aircraft_code

/* Вопрос 6. Найдите процентное соотношение перелетов по типам самолетов от общего количества   */
select model, round(num/total*100,2) ratio --рассчитали процентное соотношение от тотал
from aircrafts a
join 	-- соединили с таблицей, чтобы была видна модель самолёта
		(
		-- посчитали количество полётов на каждом типе самолётов по их коду и суммарное количество полётов
		select 	aircraft_code, 
				count(flight_id)::numeric num,
				(select count(flight_id)::numeric from flights) total --рассчитали тотал
		from flights
		group by aircraft_code
		) t
on a.aircraft_code = t.aircraft_code

/* Вопрос 7. Были ли города, в которые можно добраться бизнес - классом дешевле, чем эконом-классом в рамках перелета?  */
with 	business as (
		select tf.flight_id, amount, city from ticket_flights tf
		left join flights f on tf.flight_id = f.flight_id
		left join airports a on f.aircraft_code = a.airport_code 
		where fare_conditions = 'Business'), -- выбрали только Бизнес
		economy as (
		select tf.flight_id, amount, city from ticket_flights tf
		left join flights f on tf.flight_id = f.flight_id
		left join airports a on f.aircraft_code = a.airport_code 
		where fare_conditions = 'Economy') -- выбрали только Эконом
select b.city
from business b
left join economy e on b.flight_id = e.flight_id --присоединили все эконом тикеты по номеру полёта
where b.amount<e.amount -- отфильтровали тикеты стоимостью в экономе больше чем стоимость в бизнесе

--ОТВЕТ: городов, в которые можно добраться в бизнес классе стоимостью дешевле чем стоимость билетов в экономе НЕТ

/* Вопрос 8. Между какими городами нет прямых рейсов?  */

-- создали представление из всех текущих действующих пар городов отправления и прибытия 
create or replace view current_pairs_cities as
select distinct (pair) 
		from
			(	
			select concat(a1.city,' ', a2.city) pair from flights f
			left join airports a1 on f.departure_airport = a1.airport_code
			left join airports a2 on f.arrival_airport = a2.airport_code 
			union -- позволит также не только образовать все, в том числе зеркальные пары, но и удалить дублирующие пары
			select concat(a1.city,' ', a2.city) pair from flights f
			left join airports a1 on f.departure_airport = a1.airport_code
			left join airports a2 on f.arrival_airport = a2.airport_code 
			) t;
		
-- Steps:
-- 1. создаём все возможные пары из существующих в списках пар ородов и исключаем одинаковые в парах
-- 2. исключаем те пары городов, которые являются действующими, используя представление
-- 3. расплитовали пары в отдельные столбцы по городам

		select 	split_part(all_pairs,' ',1) first_city, -- Шаг 3
		split_part(all_pairs,' ',2) second_city -- Шаг 3
			from
			( -- Шаг 1
			select 	concat(dp,' ',aa) all_pairs  -- выбираем все пары за иcключением пар из одинаковых аэропортов
			from 	(select distinct (a.city) dp
					from flights f
					left join airports a on f.departure_airport = a.airport_code) f1, -- декартовое произведение
					(select distinct (a.city) aa 
					from flights f
					left join airports a on f.departure_airport = a.airport_code) f2
			where dp!=aa -- удалили пары, состоящие из одинаковых аэропортов
			except select * from current_pairs_cities -- Шаг 2: удалили действующие пары из всех возможных пар
			) t

/* Вопрос 9. Вычислите расстояние между аэропортами, связанными прямыми рейсами, сравните с допустимой максимальной 
   дальностью перелетов в самолетах, обслуживающих эти рейс */
-- d = arccos {sin(latitude_a)*sin(latitude_b) + cos(latitude_a)*cos(latitude_b)*cos(longitude_a - longitude_b)}, 
-- где latitude_a и latitude_b — широты, longitude_a, longitude_b — долготы данных пунктов, 
-- d — расстояние между пунктами измеряется в радианах длиной дуги большого круга земного шара.
-- Расстояние между пунктами, измеряемое в километрах, определяется по формуле:
-- L = d·R, где R = 6371 км — средний радиус земного шара.


select 	departure_airport_name, arrival_airport_name, max_distance,
		round(6371*acos(sin(departure_latitude)*sin(arrival_latitude)+
					cos(departure_latitude)*cos(arrival_latitude)*cos(departure_longitude-arrival_longitude))) distance
from
	(
	-- вывели список всех прямых перелётов вместе с координатами и дальностью самолётов, обслуживающих рейсы
	select 	a3.airport_name departure_airport_name,
			radians(a3.longitude) departure_longitude,
			radians(a3.latitude) departure_latitude,
			a2.airport_name arrival_airport_name, 
			radians(a2.longitude) arrival_longitude,
			radians(a2.latitude) arrival_latitude,
			range max_distance
	from flights f
	left join aircrafts a -- присоединили таблице с информацией по максимальной дальности
	on f.aircraft_code = a.aircraft_code 
	left join airports a2 on f.arrival_airport = a2.airport_code -- присоединили таблицу с названием аэропорта прибытия
	left join airports a3 on f.departure_airport = a3.airport_code -- присоединили таблицу с названием аэропорта отправления
	group by a3.airport_name, -- оставили уникальные прямые перелёты с учётом уникальности дальности перелётов по моделям самолётов
			a3.longitude,     -- модели самолётов в условии задачи не требуются, поэтому оставили только дальность
			a3.latitude,
			a2.airport_name, 
			a2.longitude,
			a2.latitude,
			range
	-- having departure_airport > arrival_airport не применяем для удаления зеркальных перелётов, 
	-- поскольку в обратную сторону может лететь другая модель самолёта с другой дальностью
	) t



