-- Задача: 
-- 1. Используя сервис https://supabase.com/ нужно поднять облачную базу данных PostgreSQL.
select * from information_schema.tables; -- tables are shown

-- 2. Для доступа к данным в базе данных должен быть создан пользователь 
-- логин: netocourier
-- пароль: NetoSQL2022
-- права: полный доступ на схему public, к information_schema и pg_catalog права только на чтение, 
-- предусмотреть доступ к иным схемам, если они нужны. 

--DROP ROLE netocourier;
--REVOKE ALL PRIVILEGES ON DATABASE postgres FROM netocourier CASCADE;
--REVOKE ALL PRIVILEGES ON schema public FROM netocourier CASCADE;
--REVOKE ALL PRIVILEGES ON schema extensions FROM netocourier CASCADE;
--REVOKE ALL PRIVILEGES ON schema information_schema FROM netocourier CASCADE;
--REVOKE ALL PRIVILEGES ON schema pg_catalog FROM netocourier CASCADE;

CREATE ROLE netocourier WITH LOGIN PASSWORD 'NetoSQL2022';

ALTER ROLE netocourier CREATEROLE CREATEDB;

GRANT ALL PRIVILEGES ON DATABASE postgres TO netocourier WITH GRANT OPTION;

GRANT ALL ON schema public TO netocourier WITH GRANT OPTION;

grant all on schema extensions to netocourier;

GRANT USAGE ON schema information_schema TO netocourier;

GRANT USAGE ON schema pg_catalog TO netocourier;

/* 3. Должны быть созданы следующие отношения:

courier: --данные по заявкам на курьера
id uuid PK
from_place varchar --откуда
where_place varchar --куда
name varchar --название документа
account_id uuid FK --id контрагента
contact_id uuid FK --id контакта 
description text --описание
user_id uuid FK --id сотрудника отправителя
status enum -- статусы 'В очереди', 'Выполняется', 'Выполнено', 'Отменен'. По умолчанию 'В очереди'
created_date date --дата создания заявки, значение по умолчанию now() */

/* account: --список контрагентов
id uuid PK
name varchar --название контрагента */

/* contact: --список контактов контрагентов
id uuid PK
last_name varchar --фамилия контакта
first_name varchar --имя контакта
account_id uuid FK --id контрагента */

/* user: --сотрудники
id uuid PK
last_name varchar --фамилия сотрудника
first_name varchar --имя сотрудника
dismissed boolean --уволен или нет, значение по умолчанию "нет" */

select * from pg_available_extensions
where installed_version is not null;

-- 4. Для генерации uuid необходимо использовать функционал модуля uuid-ossp, который уже подключен в облачной базе.

-- CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- drop table courier cascade;

create table account
(
	id uuid not null default uuid_generate_v4 () primary key,
	"name" varchar (40) not null
);

create table contact
(
	id uuid not null default uuid_generate_v4 () primary key,
	last_name varchar (40) not null,
	first_name varchar (20) not null,
	account_id uuid references account (id)
);

create table "user"
(
	id uuid not null default uuid_generate_v4 () primary key,
	last_name varchar (40) not null,
	first_name varchar (20) not null,
	dismissed boolean not null default 'f'
);

-- 5. Для формирования списка значений в атрибуте status используйте create type ... as enum 

create type status as enum ('В очереди', 'Выполняется', 'Выполнено', 'Отменен');

create table courier (
	id uuid not null default uuid_generate_v4 () primary key,
	from_place varchar (80) not null,
	where_place varchar (80) not null,
	"name" varchar (80) not null,
	account_id uuid references account (id),
	contact_id uuid references contact (id),
	description text not null,
	user_id uuid references "user" (id),
	"status" status not null default 'В очереди',
	created_date date not null default now()
	);

/* 6. Для возможности тестирования приложения необходимо реализовать процедуру insert_test_data(value), 
которая принимает на вход целочисленное значение.
Данная процедура должна внести:
value * 1 строк случайных данных в отношение account.
value * 2 строк случайных данных в отношение contact.
value * 1 строк случайных данных в отношение user.
value * 5 строк случайных данных в отношение courier.
- Генерация id должна быть через uuid-ossp
- Генерация символьных полей через конструкцию SELECT repeat(substring('абвгдеёжзийклмнопрстуфхцчшщьыъэюя',1,(random()*33)::integer),(random()*10)::integer);
Соблюдайте длину типа varchar. Первый random получает случайный набор символов из строки, второй random дублирует количество символов полученных в substring.
- Генерация булева типа происходит через 0 и 1 с использованием оператора random.
- Генерацию даты и времени можно сформировать через select now() - interval '1 day' * round(random() * 1000) as timestamp;
- Генерацию статусов можно реализовать через enum_range() */

drop procedure insert_test_data;

CREATE PROCEDURE insert_test_data(value int) AS $$
	declare x uuid; 
			y uuid;
			z uuid;
			w status;
	BEGIN
		-- insert into account
		FOR i IN 1..value*1
		LOOP 
			insert into account("name")
			select
			repeat(substring('абвгдеёжзийклмнопрстуфхцчшщьыъэюя',1,(random()*32+1)::integer),(random()*5+1)::integer)::varchar(40);
		end loop;
		--insert into contact
		for i in 1..value*2
		loop
			insert into contact(last_name, first_name, account_id)
			select
			repeat(substring('абвгдеёжзийклмнопрстуфхцчшщьыъэюя',1,(random()*32+1)::integer),(random()*5+1)::integer)::varchar(40),
			repeat(substring('абвгдеёжзийклмнопрстуфхцчшщьыъэюя',1,(random()*32+1)::integer),(random()*5+1)::integer)::varchar(20),
			id from account order by random() limit 1;
		end loop;
		-- insert into "user"
		for i in 1..value*1
		loop
			insert into "user"(last_name, first_name,dismissed)
			select
			repeat(substring('абвгдеёжзийклмнопрстуфхцчшщьыъэюя',1,(random()*32+1)::integer),(random()*5+1)::integer)::varchar(40),
			repeat(substring('абвгдеёжзийклмнопрстуфхцчшщьыъэюя',1,(random()*32+1)::integer),(random()*5+1)::integer)::varchar(20),
			random()::int::boolean;
		end loop;
		-- insert into courier
		for j in 1..value*5
		loop
			x:= id from account order by random() limit 1;
			y:= id from contact where account_id = x limit 1;
			z:= id from "user" order by random() limit 1;
			w:= * from (select unnest(enum_range(NULL::status)) as s) sub ORDER BY random() LIMIT 1;
			insert into courier(from_place, where_place, "name", account_id, contact_id, description, user_id,"status", created_date)
			select
			repeat(substring('абвгдеёжзийклмнопрстуфхцчшщьыъэюя',1,(random()*32+1)::integer),(random()*5+1)::integer)::varchar(80),
			repeat(substring('абвгдеёжзийклмнопрстуфхцчшщьыъэюя',1,(random()*32+1)::integer),(random()*5+1)::integer)::varchar(80),
			repeat(substring('абвгдеёжзийклмнопрстуфхцчшщьыъэюя',1,(random()*32+1)::integer),(random()*5+1)::integer)::varchar(80),
			x,
			y,
			repeat(substring('абвгдеёжзийклмнопрстуфхцчшщьыъэюя',1,(random()*32+1)::integer),(random()*5+1)::integer)::text,
			z,
			w,
			now() - interval '1 day' * round(random() * 1000) as timestamp;
		end loop;
	END;
$$ LANGUAGE plpgsql;

call insert_test_data(5000);

-- 7. Необходимо реализовать процедуру erase_test_data(), которая будет удалять тестовые данные
-- из отношений.

CREATE PROCEDURE erase_test_data() AS $$
	begin
		truncate account, contact, "user", courier;
	END;
$$ LANGUAGE plpgsql;

call erase_test_data();

/* 8. На бэкенде реализована функция по добавлению новой записи о заявке на курьера:
function add($params) --добавление новой заявки
    {
        $pdo = Di::pdo();
        $from = $params["from"]; 
        $where = $params["where"]; 
        $name = $params["name"]; 
        $account_id = $params["account_id"]; 
        $contact_id = $params["contact_id"]; 
        $description = $params["description"]; 
        $user_id = $params["user_id"]; 
        $stmt = $pdo->prepare('CALL add_courier (?, ?, ?, ?, ?, ?, ?)');
        $stmt->bindParam(1, $from); --from_place
        $stmt->bindParam(2, $where); --where_place
        $stmt->bindParam(3, $name); --name
        $stmt->bindParam(4, $account_id); --account_id
        $stmt->bindParam(5, $contact_id); --contact_id
        $stmt->bindParam(6, $description); --description
        $stmt->bindParam(7, $user_id); --user_id
        $stmt->execute();
    }
Нужно реализовать процедуру add_courier(from_place, where_place, name, account_id, contact_id, description, user_id), 
которая принимает на вход вышеуказанные аргументы и вносит данные в таблицу courier
Важно! Последовательность значений должна быть строго соблюдена, иначе приложение работать не будет. */

-- drop procedure add_courier;

CREATE PROCEDURE add_courier(_from_place varchar(80), _where_place varchar(80), _name varchar(80), _account_id uuid, _contact_id uuid, _description text, _user_id uuid) AS $$
	begin
		insert into courier(from_place, where_place, "name", account_id, contact_id, description, user_id)
		values (_from_place, _where_place, _name, _account_id, _contact_id, _description, _user_id);
	END;
$$ LANGUAGE plpgsql;

/* 9. На бэкенде реализована функция по получению записей о заявках на курьера: 
static function get() --получение списка заявок
    {
        $pdo = Di::pdo();
        $stmt = $pdo->prepare('SELECT * FROM get_courier()');
        $stmt->execute();
        $data = $stmt->fetchAll();
        return $data;
    }
Нужно реализовать функцию get_courier(), которая возвращает таблицу согласно следующей структуры:
id --идентификатор заявки
from_place --откуда
where_place --куда
name --название документа
account_id --идентификатор контрагента
account --название контрагента
contact_id --идентификатор контакта
contact --фамилия и имя контакта через пробел
description --описание
user_id --идентификатор сотрудника
user --фамилия и имя сотрудника через пробел
status --статус заявки
created_date --дата создания заявки
Сортировка результата должна быть сперва по статусу, затем по дате от большего к меньшему.
Важно! Если названия столбцов возвращаемой функцией таблицы будут отличаться от указанных выше, 
то приложение работать не будет. */

create or replace function get_courier() returns table (id uuid, from_place varchar(80), where_place varchar(80), 
											"name" varchar(80), account_id uuid, account varchar(40),
											contact_id uuid, contact varchar(61), description text,
											user_id uuid, "user" varchar(61), "status" status, created_date date)
as $$
begin
	return query select 	
			cr.id, 
			cr.from_place, 
			cr.where_place, 
			cr."name", 
			cr.account_id, 
			a."name" account, 
			cr.contact_id,
			(c.last_name||' '||c.first_name)::varchar(61) contact,
			cr.description,
			cr.user_id,
			(u.last_name||' '||u.first_name)::varchar(61) "user",
			cr."status",
			cr.created_date
	from courier cr 
	left join account a on cr.account_id = a.id
	left join contact c on cr.contact_id = c.id
	left join "user" u on cr.user_id = u.id
	order by "status", created_date desc;
end;
$$ LANGUAGE plpgsql;

select * from get_courier();

/*10. На бэкенде реализована функция по изменению статуса заявки.
function change_status($params) --изменение статуса заявки
    {
        $pdo = Di::pdo();
        $status = $params["new_status"];
        $id = $params["id"];
        $stmt = $pdo->prepare('CALL change_status(?, ?)');
        $stmt->bindParam(1, $status); --новый статус
        $stmt->bindParam(2, $id); --идентификатор заявки
        $stmt->execute();
    }
Нужно реализовать процедуру change_status(status, id), которая будет изменять статус заявки. 
На вход процедура принимает новое значение статуса и значение идентификатора заявки.*/

create function change_status(_status status, _id uuid) returns void
as $$
begin
	update courier
	set "status" = _status
	where id = _id;
end;
$$ LANGUAGE plpgsql;

-- select change_status('Выполняется', '23cd1de9-4475-4b10-b31d-fa727d2269f4');

/*11. На бэкенде реализована функция получения списка сотрудников компании.
static function get_users() --получение списка пользователей
    {
        $pdo = Di::pdo();
        $stmt = $pdo->prepare('SELECT * FROM get_users()');
        $stmt->execute();
        $data = $stmt->fetchAll();
        $result = [];
        foreach ($data as $v) {
            $result[] = $v['user'];
        }
        return $result;
    }
Нужно реализовать функцию get_users(), которая возвращает таблицу согласно следующей структуры:
user --фамилия и имя сотрудника через пробел 
Сотрудник должен быть действующим! Сортировка должна быть по фамилии сотрудника.*/

select * from "user";

create or replace function get_users() returns table ("user" varchar(61))
as $$
begin
	return query select (last_name||' '||first_name)::varchar(61) "user" from "user"
	where dismissed = 'f'
	order by last_name;
end;
$$ LANGUAGE plpgsql;

select * from get_users();

/* 12. На бэкенде реализована функция получения списка контрагентов.
static function get_accounts() --получение списка контрагентов
    {
        $pdo = Di::pdo();
        $stmt = $pdo->prepare('SELECT * FROM get_accounts()');
        $stmt->execute();
        $data = $stmt->fetchAll();
        $result = [];
        foreach ($data as $v) {
            $result[] = $v['account'];
        }
        return $result;
    }
Нужно реализовать функцию get_accounts(), которая возвращает таблицу согласно следующей структуры:
account --название контрагента 
Сортировка должна быть по названию контрагента. */

select * from account;

create or replace function get_accounts() returns table (account varchar(40))
as $$
begin
	return query select "name" from account
	order by "name";
end;
$$ LANGUAGE plpgsql;

select * from get_accounts();

/* 13. На бэкенде реализована функция получения списка контактов.
function get_contacts($params) --получение списка контактов
    {
        $pdo = Di::pdo();
        $account_id = $params["account_id"]; 
        $stmt = $pdo->prepare('SELECT * FROM get_contacts(?)');
        $stmt->bindParam(1, $account_id); --идентификатор контрагента
        $stmt->execute();
        $data = $stmt->fetchAll();
        $result = [];
        foreach ($data as $v) {
            $result[] = $v['contact'];
        }
        return $result;
    }
Нужно реализовать функцию get_contacts(account_id), которая принимает на вход идентификатор контрагента и возвращает таблицу 
с контактами переданного контрагента согласно следующей структуры:
contact --фамилия и имя контакта через пробел 
Сортировка должна быть по фамилии контакта. Если в функцию вместо идентификатора контрагента передан null, нужно вернуть 
строку 'Выберите контрагента'. */

create or replace function get_contacts(_id uuid) returns table (contact varchar(61))
as $$
begin
	if _id is null then
		return query select 'Выберите контрагента'::varchar(61);
	else
		return query select (c.last_name||' '||c.first_name)::varchar(61) contact from account a
		left join contact c on a.id = c.account_id
		order by c.last_name;
	end if;
end;
$$ LANGUAGE plpgsql;

select get_contacts(null);

/* 14. На бэкенде реализована функция по получению статистики о заявках на курьера: 
static function get_stat() --получение статистики
    {
        $pdo = Di::pdo();
        $stmt = $pdo->prepare('SELECT * FROM courier_statistic');
        $stmt->execute();
        $data = $stmt->fetchAll();
        return $data;
    }
Нужно реализовать представление courier_statistic, со следующей структурой:
account_id --идентификатор контрагента
account --название контрагента
count_courier --количество заказов на курьера для каждого контрагента
count_complete --количество завершенных заказов для каждого контрагента
count_canceled --количество отмененных заказов для каждого контрагента
percent_relative_prev_month -- процентное изменение количества заказов текущего месяца к предыдущему месяцу для каждого 
контрагента, если получаете деление на 0, то в результат вывести 0.
count_where_place --количество мест доставки для каждого контрагента
count_contact --количество контактов по контрагенту, которым доставляются документы
cansel_user_array --массив с идентификаторами сотрудников, по которым были заказы со статусом "Отменен" для каждого контрагента */
create or replace view courier_statistic as
	with dat as
	(select c.account_id account_id,
			c.id n_order, 
			c."status" c_status, 
			DATE_TRUNC('month', c.created_date) as order_month,
			c.where_place delivery_place,
			c.contact_id n_contact,
			c."name" doc_name,
			c.user_id user_id
	from courier c
	left join account a on c.account_id = a.id),
	--order by account_id, order_month),
	a1 as 
		(
	-- считаем среднее количество заказов на курьера по каждому контрагенту
		select 	account_id,  
				count(distinct n_order)/count(distinct user_id) count_courier
		from dat
		group by account_id
		),
	a2 as
		( 
	-- считаем завершённых заказов для каждого контрагента
		select 	account_id,
				count (distinct n_order) count_complete
		from dat
		where c_status = 'Выполнено'
		group by account_id
		),
	a3 as
		(
	-- считаем отменённых заказов для каждого контрагента
		select 	account_id,
				count (distinct n_order) count_canceled
		from dat
		where c_status = 'Отменен'
		group by account_id
		),
	-- preparation for percent_relative_prev_month calculation
	p as 
		(
		select 	account_id,
				count(distinct n_order) norders_cm
		from dat
		where order_month = DATE_TRUNC('month', now())
		group by account_id
		),
	p1 as 
		(
		select 	account_id,
				count(distinct n_order) norders_pm
		from dat
		where order_month = DATE_TRUNC('month', now() - interval '1' month)
		group by account_id
		),
	p2 as
		(
		select p.account_id, norders_cm, norders_pm
		from p
		left join p1 on p.account_id = p1.account_id
		),
	a4 as
		(
	--percent_relative_prev_month -- процентное изменение количества заказов ТЕКУЩЕГО!!! месяца к предыдущему месяцу для каждого 
	--контрагента, если получаете деление на 0, то в результат вывести 0.
		SELECT 	account_id,
				(case
					when norders_pm is null then 0
					when norders_pm is not null then norders_cm/norders_pm*100
				end) percent_relative_prev_month
		from p2
		),
	a5 as
		(
	--count_where_place --количество мест доставки для каждого контрагента
		select account_id, count(distinct delivery_place) count_where_place
		from dat
		group by account_id
		),
	a6 as
		(
	--count_contact --количество контактов по контрагенту, которым доставляются документы
		select account_id, count(distinct n_contact) count_contact
		from dat
		where doc_name is not null
		group by account_id
		),
	a7 as
		(
	-- cansel_user_array --массив с идентификаторами сотрудников, по которым были заказы со статусом "Отменен" 
	-- для каждого контрагента
		select account_id, array_agg(user_id) cansel_user_array
		from dat
		where c_status = 'Отменен'
		group by account_id
		)
	select 	a.id account_id,
			a."name" account,
			count_courier,
			count_complete,
			count_canceled,
			percent_relative_prev_month,
			count_where_place,
			count_contact,
			cansel_user_array
	from account a
	left join a1 on a.id = a1.account_id
	left join a2 on a.id = a2.account_id
	left join a3 on a.id = a3.account_id
	left join a4 on a.id = a4.account_id
	left join a5 on a.id = a5.account_id
	left join a6 on a.id = a6.account_id
	left join a7 on a.id = a7.account_id
;



