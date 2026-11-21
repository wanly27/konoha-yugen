# Выборы нового Хокаге — комплект сайта

## Что внутри
- `index.html`, `style.css`, `app.js` — сайт в стиле свитка.
- `config.js` — сюда вставляются URL и публичный ключ Supabase.
- `database.sql` — SQL для создания таблиц и правил доступа.

## 1. Настрой базу Supabase
1. Создай проект на https://supabase.com/
2. Открой SQL Editor → New query.
3. Открой `database.sql`, скопируй весь текст и выполни его.
4. Если основной кандидат не Минато Намикадзе, замени его имя в `database.sql` до выполнения.

## 2. Подключи сайт к Supabase
1. В Supabase открой Project Settings → API.
2. Скопируй Project URL и публичный `anon` или `publishable` key.
3. В `config.js` замени значения `SUPABASE_URL` и `SUPABASE_ANON_KEY`.
4. Укажи такое же имя основного кандидата в `FEATURED_CANDIDATE`.

Важно: никогда не вставляй в `config.js` `service_role` или secret key.

## 3. Опубликуй на GitHub Pages
1. Создай GitHub-репозиторий.
2. Загрузи в корень репозитория все пять файлов: `index.html`, `style.css`, `app.js`, `config.js`, `database.sql`.
3. Открой Settings → Pages.
4. В разделе Build and deployment выбери Deploy from a branch, ветку `main`, папку `/ (root)`, нажми Save.
5. Подожди публикации и открой выданный GitHub Pages адрес.

## 4. Где смотреть результаты
В Supabase → SQL Editor выполни:

```sql
select candidate_name, candidate_type, count(*) as votes
from public.votes
group by candidate_name, candidate_type
order by votes desc, candidate_name;
```

Посетители сайта не получают права читать таблицу голосов.

## 5. Как закрыть голосование
В Supabase SQL Editor:

```sql
update public.election_settings set voting_open = false where id = true;
```

Открыть снова:

```sql
update public.election_settings set voting_open = true where id = true;
```

## Важное ограничение
Сейчас правило «один голос» привязано к введённому игровому нику. Оно не доказывает, что человек действительно владеет этим аккаунтом: игрок может ввести чужой ник. Для честных выборов с подтверждением личности добавь проверку через Discord или одноразовые коды, которые проверяются серверной Edge Function. Не размещай секретные ключи в браузере.
