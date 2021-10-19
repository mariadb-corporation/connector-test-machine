CREATE USER IF NOT EXISTS 'boby'@'%' identified by 'heyPassw!#20-rd';
GRANT ALL ON *.* TO 'boby'@'%' /*M!100401 identified by 'heyPassw!#20-rd'*/ with grant option;

CREATE USER IF NOT EXISTS 'boby'@'localhost' identified by 'heyPassw!#20-rd';
GRANT ALL ON *.* TO 'boby'@'localhost' /*M!100401 identified by 'heyPassw!#20-rd'*/ with grant option;

CREATE DATABASE test2;