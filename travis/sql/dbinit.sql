CREATE USER IF NOT EXISTS 'boby'@'%' identified by 'heyPassword';
GRANT ALL ON *.* TO 'boby'@'%' /*M!100401 identified by 'heyPassword'*/ with grant option;

CREATE USER IF NOT EXISTS 'boby'@'localhost' identified by 'heyPassword';
GRANT ALL ON *.* TO 'boby'@'localhost' /*M!100401 identified by 'heyPassword'*/ with grant option;

CREATE DATABASE test2;