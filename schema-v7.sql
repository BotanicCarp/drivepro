-- DRIVEPRO V7: календарь + график + исправление RLS recursion
create table if not exists public.instructor_working_hours(
 id uuid primary key default gen_random_uuid(),
 instructor_id uuid not null references public.instructors(id) on delete cascade,
 day_of_week smallint not null check(day_of_week between 0 and 6),
 start_time time not null default '07:00',
 end_time time not null default '19:00',
 lunch_start time not null default '12:00',
 lunch_end time not null default '13:00',
 active boolean not null default true,
 unique(instructor_id,day_of_week)
);
alter table public.instructor_working_hours enable row level security;
drop policy if exists "public read working hours" on public.instructor_working_hours;
create policy "public read working hours" on public.instructor_working_hours for select using(true);

create or replace function public.instructor_subscription_active(p_instructor_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.subscriptions s
 where s.instructor_id=p_instructor_id and s.status='active'
 and (s.expires_at is null or s.expires_at>now()));
$$;

drop policy if exists "student bookings insert" on public.bookings;
drop policy if exists "student bookings read" on public.bookings;
drop policy if exists "student bookings update" on public.bookings;

create policy "student bookings read" on public.bookings for select using(
 exists(select 1 from public.students st where st.id=bookings.student_id and st.profile_id=auth.uid())
);
create policy "student bookings insert" on public.bookings for insert with check(
 exists(select 1 from public.students st where st.id=bookings.student_id and st.profile_id=auth.uid())
 and public.instructor_subscription_active(bookings.instructor_id)
);
create policy "student bookings update" on public.bookings for update
using(exists(select 1 from public.students st where st.id=bookings.student_id and st.profile_id=auth.uid()))
with check(exists(select 1 from public.students st where st.id=bookings.student_id and st.profile_id=auth.uid()));

create unique index if not exists bookings_one_confirmed_slot
on public.bookings(instructor_id,starts_at) where status='confirmed';

alter table public.instructors add column if not exists display_name text;
update public.instructors i set display_name=coalesce(i.display_name,p.full_name,'Инструктор')
from public.profiles p where p.id=i.profile_id;
alter table public.instructors alter column display_name set default 'Инструктор';
drop policy if exists "instructors public read" on public.instructors;
create policy "instructors public read" on public.instructors for select using(true);
drop policy if exists "schools public read" on public.schools;
create policy "schools public read" on public.schools for select using(true);

-- Иван: Пн-Сб 07:00-19:00, обед 12:00-13:00; Вс выходной.
insert into public.instructor_working_hours(instructor_id,day_of_week,start_time,end_time,lunch_start,lunch_end,active)
select i.id,d.day_of_week,'07:00','19:00','12:00','13:00',d.day_of_week<>0
from public.instructors i cross join (values(0),(1),(2),(3),(4),(5),(6)) d(day_of_week)
where i.slug='ivan-petrov'
on conflict(instructor_id,day_of_week) do update set
start_time=excluded.start_time,end_time=excluded.end_time,
lunch_start=excluded.lunch_start,lunch_end=excluded.lunch_end,active=excluded.active;

create index if not exists bookings_instructor_date_idx on public.bookings(instructor_id,starts_at);
create index if not exists bookings_student_date_idx on public.bookings(student_id,starts_at);


-- Отзывы курсантов об инструкторах.
create table if not exists public.reviews(
 id uuid primary key default gen_random_uuid(),
 student_id uuid not null references public.students(id) on delete cascade,
 instructor_id uuid not null references public.instructors(id) on delete cascade,
 rating smallint not null check(rating between 1 and 5),
 text text not null check(char_length(trim(text)) between 5 and 500),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(student_id,instructor_id)
);
alter table public.reviews enable row level security;
drop policy if exists "reviews public read" on public.reviews;
create policy "reviews public read" on public.reviews for select using(true);
drop policy if exists "students create own reviews" on public.reviews;
create policy "students create own reviews" on public.reviews for insert with check(
 exists(select 1 from public.students st where st.id=reviews.student_id and st.profile_id=auth.uid())
);
drop policy if exists "students update own reviews" on public.reviews;
create policy "students update own reviews" on public.reviews for update
using(exists(select 1 from public.students st where st.id=reviews.student_id and st.profile_id=auth.uid()))
with check(exists(select 1 from public.students st where st.id=reviews.student_id and st.profile_id=auth.uid()));
drop policy if exists "students delete own reviews" on public.reviews;
create policy "students delete own reviews" on public.reviews for delete using(
 exists(select 1 from public.students st where st.id=reviews.student_id and st.profile_id=auth.uid())
);


-- Дополнительные поля для многослотовой записи.
alter table public.bookings add column if not exists lesson_type text not null default 'city'
  check(lesson_type in ('city','autodrome'));
alter table public.bookings add column if not exists lesson_count smallint not null default 1
  check(lesson_count between 1 and 2);
alter table public.bookings add column if not exists booking_group_id uuid;

create index if not exists bookings_group_idx on public.bookings(booking_group_id);


-- Кабинет инструктора: закрытие отдельных 45-минутных слотов.
create table if not exists public.instructor_blocked_slots(id uuid primary key default gen_random_uuid(),instructor_id uuid not null references public.instructors(id) on delete cascade,starts_at timestamptz not null,reason text,created_at timestamptz not null default now(),unique(instructor_id,starts_at));
alter table public.instructor_blocked_slots enable row level security;
drop policy if exists "instructor read own blocked slots" on public.instructor_blocked_slots;
create policy "instructor read own blocked slots" on public.instructor_blocked_slots for select using(exists(select 1 from public.instructors i where i.id=instructor_blocked_slots.instructor_id and i.profile_id=auth.uid()));
drop policy if exists "instructor insert own blocked slots" on public.instructor_blocked_slots;
create policy "instructor insert own blocked slots" on public.instructor_blocked_slots for insert with check(exists(select 1 from public.instructors i where i.id=instructor_blocked_slots.instructor_id and i.profile_id=auth.uid()));
drop policy if exists "instructor delete own blocked slots" on public.instructor_blocked_slots;
create policy "instructor delete own blocked slots" on public.instructor_blocked_slots for delete using(exists(select 1 from public.instructors i where i.id=instructor_blocked_slots.instructor_id and i.profile_id=auth.uid()));
drop policy if exists "instructor read own bookings" on public.bookings;
create policy "instructor read own bookings" on public.bookings for select using(exists(select 1 from public.instructors i where i.id=bookings.instructor_id and i.profile_id=auth.uid()) or exists(select 1 from public.students st where st.id=bookings.student_id and st.profile_id=auth.uid()));
drop policy if exists "instructor update own bookings" on public.bookings;
create policy "instructor update own bookings" on public.bookings for update using(exists(select 1 from public.instructors i where i.id=bookings.instructor_id and i.profile_id=auth.uid())) with check(exists(select 1 from public.instructors i where i.id=bookings.instructor_id and i.profile_id=auth.uid()));
drop policy if exists "instructor read own working hours" on public.instructor_working_hours;
create policy "instructor read own working hours" on public.instructor_working_hours for select using(exists(select 1 from public.instructors i where i.id=instructor_working_hours.instructor_id and i.profile_id=auth.uid()));
drop policy if exists "instructor update own working hours" on public.instructor_working_hours;
create policy "instructor update own working hours" on public.instructor_working_hours for update using(exists(select 1 from public.instructors i where i.id=instructor_working_hours.instructor_id and i.profile_id=auth.uid())) with check(exists(select 1 from public.instructors i where i.id=instructor_working_hours.instructor_id and i.profile_id=auth.uid()));

-- DRIVEPRO V13: единая запись на 45/90 минут и защита от пересечений.
-- 1 академический час = 45 минут. 2 академических часа = 90 минут.

alter table public.bookings add column if not exists ends_at timestamptz;

-- Восстанавливаем конец старых записей до включения NOT NULL/ограничений.
update public.bookings
set ends_at = starts_at + make_interval(mins => coalesce(lesson_count,1) * 45)
where ends_at is null;

-- Старые версии создавали две строки для одного booking_group_id.
-- Оставляем одну запись с самым ранним starts_at.
delete from public.bookings b
where b.booking_group_id is not null
  and b.id in (
    select id from (
      select id,
             row_number() over(partition by booking_group_id order by starts_at, id) as rn
      from public.bookings
      where booking_group_id is not null
    ) q
    where q.rn > 1
  );

-- После удаления дублей пересчитываем конец оставшейся записи.
update public.bookings
set ends_at = starts_at + make_interval(mins => coalesce(lesson_count,1) * 45)
where booking_group_id is not null;

alter table public.bookings alter column ends_at set not null;
alter table public.bookings drop constraint if exists bookings_time_order_check;
alter table public.bookings add constraint bookings_time_order_check check(ends_at > starts_at);

-- Старый unique-index разрешал пересечение 07:00-08:30 с другой записью в 07:45.
drop index if exists public.bookings_one_confirmed_slot;

create extension if not exists btree_gist;

alter table public.bookings drop constraint if exists bookings_no_confirmed_overlap;
alter table public.bookings add constraint bookings_no_confirmed_overlap
exclude using gist (
  instructor_id with =,
  tstzrange(starts_at, ends_at, '[)') with &&
) where (status = 'confirmed');

create index if not exists bookings_instructor_range_idx
on public.bookings(instructor_id, starts_at, ends_at);
