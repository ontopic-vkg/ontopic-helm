-- create database gitea;
-- create user gitea with encrypted password 'Phei8Vai';
-- grant all privileges on database gitea to gitea;
-- alter database gitea OWNER TO gitea;
---
create database internal;
grant all privileges on database internal to postgres;
alter database internal OWNER TO postgres;
