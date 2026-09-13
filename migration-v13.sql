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
