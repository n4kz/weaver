# Anub'seran

Interactive process management system for node.js

# Synopsis

Start with specified config file

	weaver --config test.json 

Re-read config

	weaver upgrade

View process status

	weaver status

Stop by pid or task name

	weaver stop 17345 17348

Restart by pid or task name

	weaver restart web

Stop all tasks and exit

	weaver exit
