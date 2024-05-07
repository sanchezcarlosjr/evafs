INSERT INTO
    auth.users (
        instance_id,
        id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        recovery_sent_at,
        last_sign_in_at,
        raw_app_meta_data,
        raw_user_meta_data,
        created_at,
        updated_at,
        confirmation_token,
        email_change,
        email_change_token_new,
        recovery_token
    ) (
        select
            '00000000-0000-0000-0000-000000000000',
            uuid_generate_v4 (),
            'authenticated',
            'authenticated',
            'user' || (ROW_NUMBER() OVER ()) || '@example.com',
            crypt ('password123', gen_salt ('bf')),
            current_timestamp,
            current_timestamp,
            current_timestamp,
            '{"provider":"email","providers":["email"]}',
            '{}',
            current_timestamp,
            current_timestamp,
            '',
            '',
            '',
            ''
        FROM
            generate_series(1, 10)
    );


create or replace function auth.uid()
returns uuid
language sql stable
as $$
  select id from auth.users  LIMIT 1
$$;


insert into
  public.resources (
    name,
    meta,
    created_at,
    deleted,
    parent
  )
  (
    SELECT
      gen_random_uuid (),
      '{"label": "X"}',
      now(),
      false,
      (SELECT name FROM resources where random() < 0.01 LIMIT 1)
    FROM generate_series(1,10)
  );
