# DrivePro V13 — deployment

## Архитектура
- Frontend: HTML/CSS/JavaScript
- Database/Auth: Supabase
- Hosting: Vercel
- Local `server.py` больше не нужен для production.

## 1. Supabase
Выполните `migration-v13.sql` в Supabase SQL Editor.

В `config.js` уже указан Supabase URL и publishable key. Secret/service_role key в браузер добавлять нельзя.

## 2. GitHub
Создайте новый репозиторий и загрузите содержимое этой папки.

## 3. Vercel
1. Откройте Vercel.
2. Add New → Project.
3. Import Git Repository.
4. Выберите репозиторий DrivePro.
5. Framework Preset: Other.
6. Build Command: оставить пустым.
7. Output Directory: `.`.
8. Deploy.

## 4. Проверка
После Deploy:
- `/` — главная;
- `/i/ivan-petrov` — ссылка инструктора;
- `/s/drive-start` — ссылка школы.

`vercel.json` уже содержит rewrite для `/i/:slug` и `/s/:slug`, поэтому обновление страницы по персональной ссылке не должно давать 404.

## 5. Домен
Vercel → Project → Settings → Domains → Add Domain.

После подключения домена персональная ссылка будет выглядеть, например:
`https://drivepro.kz/i/ivan-petrov`

## 6. Важно для Supabase Auth
Если используется production-домен, в Supabase Auth → URL Configuration нужно указать production Site URL и Redirect URLs.

Не публикуйте service_role/secret key. Publishable/anon key предназначен для клиентского приложения при корректно настроенном RLS.
