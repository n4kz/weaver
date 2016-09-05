# Changelog

## 0.3.0

Released 2016-09-05

* Starting script now monitors for available TCP connection
* Configuration is passed only over established TCP connection
* Daemon finishes when tasks exit, not after longest timeout
* Refactored core classes (CoffeeScript now)
* Improved uncaughtException and error handling

## 0.2.3

Released 2016-08-15

* Fixed task restart during upgrade

## 0.2.2

Released 2016-07-22

* Fixed env variable expansion
* Allowed dots and dashes in task names

## 0.2.0

Released 2016-02-26

* Upgrade extends weaver configuration instead of replacing it
* Added drop command
* Fixed argument validation for kill command
* Fixed crash on broken executables

## 0.1.2

Released 2016-02-01

* JSON Schema validation for config file

## 0.1.1

Released 2014-02-07

* Fixed crash in monitor mode

## 0.1.0

Released 2014-01-29

* Monitor mode
* Messages on start and exit
* Uptime in status
* Use `weaver.json` from start directory if available
* Code cleanup and many minor fixes

## 0.0.11

Released 2013-06-27

* Use env variables `WEAVER_DEBUG` and `WEAVER_PORT`
* Configurable minimal uptime for persistent tasks to be restarted on error

## 0.0.10

Released 2013-03-26

* Fixes for node 0.10.x

## 0.0.9

Released 2013-03-16

* Fixed daemon path resolution

## 0.0.8

Released 2013-03-16

* Added version to `status` command output
* Removed `node-daemon` dependency

## 0.0.7

Released 2013-03-13

* Added uptime to `status` command output
* Added `dump` command
* Pass env variables to child processes

## 0.0.6

Released 2013-02-10

* Run executable files as child processes
