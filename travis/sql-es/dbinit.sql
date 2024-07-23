CREATE USER IF NOT EXISTS 'boby'@'%' identified by 'heyPassW-!*20oRd';
GRANT ALL ON *.* TO 'boby'@'%' /*M!100401 identified by 'heyPassw-!*20oRd'*/ with grant option;
--
-- CREATE USER IF NOT EXISTS 'boby'@'localhost' identified by 'heyPassw-!*20oRd';
-- GRANT ALL ON *.* TO 'boby'@'localhost' /*M!100401 identified by 'heyPassw-!*20oRd'*/ with grant option;

CREATE DATABASE test2;