# Weaver

Interactive process management system for node.js

# Installation

```bash
# Global
npm -g install weaver

# Local
npm install weaver
```

If you have chosen local installation, check your `PATH` environment variable. `npm` creates symlinks to
all binaries in `node_modules/.bin` hidden folder. So you may want to prepend it to `PATH`.

# Usage

	weaver [--port <number>] [--config <path>] [--debug]
	weaver [--port <number>] [--config <path>] upgrade
	weaver [--port <number>] <restart|stop> [[task|pid], ...]
	weaver [--port <number>] kill <signal> [[task|pid], ...]
	weaver [--port <number>] [--nocolor] status
	weaver [--port <number>] [--nocolor] dump
	weaver [--port <number>] monitor
	weaver [--port <number>] exit

# Commands

- `start`   Start daemon if it was not started before. Default command
- `upgrade` Change or re-read config file
- `restart` Restart all tasks, task group, task by pid
- `stop`    Stop all tasks, task group, task by pid
- `kill`    Send signal to task group or task by pid
- `status`  Show status for all tasks
- `dump`    Show current weaver configuration
- `monitor` Show log messages from running weaver
- `exit`    Stop all tasks and exit

# Options

	--config   Configuration file. Required to start daemon with predefined tasks
	--debug    Do not fork and give additional output. Makes sense only for start  [boolean]
	--nocolor  Do not use colors for output                                        [boolean]
	--help     Show help                                                           [boolean]
	--version  Show version                                                        [boolean]
	--port     Use specified port                                                  [default: 8092]

Also `WEAVER_PORT` and `WEAVER_DEBUG` environment variables can be used to set options, but
command line options have higher priority.

# Configuration example

```json
{
	"path": "..",
	"tasks": {
		"web": {
			"count": 2,
			"source": "lib/main.js",
			"persistent": false,
			"arguments": ["--web", "--port", [8001, 8002]],
			"watch": ["lib/**/*.js", "config/default.js", "config/local.json"],
			"env": {
				"NODE_ENV": "local"
			}
		},

		"worker": {
			"count": 1,
			"timeout": 2000,
			"source": "lib/main.js",
			"persistent": false,
			"arguments": ["--worker"],
			"watch": ["lib/worker/*.js"],
			"env": {
				"NODE_ENV": "local"
			}
		},

		"redis": {
			"count": 1,
			"source": "redis-cli",
			"executable": true,
			"arguments": ["monitor"]
		}
	}
}
```

With such config file weaver will run three processes and restart them when one of watched files is modified. Fourth process will
send commands from redis in monitor mode to log. Processes are organized in three groups and can be managed by group name.
For example to restart web processes you need to say

	weaver restart web

and to stop redis monitor

	weaver stop redis

Processes in the web group get different command line arguments but similar environment. By default tasks have access to `PATH`, `NODE_PATH` and `HOME`
environment variables. `NODE_PATH` is set automatically only when `executable` flag is not set.

Bash commands to start processes manually in same way as weaver does in example above

	NODE_ENV="local" node ../lib/main.js --web --port 8001
	NODE_ENV="local" node ../lib/main.js --web --port 8002
	NODE_ENV="local" node ../lib/main.js --worker
	redis-cli monitor

# Configuration file structure

- `path`       Path to working directory, relative to configuration file or absolute. Optional
- `tasks`      Task groups
- `count`      Task count for group
- `source`     Source file for task group
- `persistent` Restart task on unclean exit. Defaults to false. Boolean. Optional
- `executable` Source is executable itself and v8 instance is not needed to run it. Defaults to false. Boolean. Optional
- `arguments`  Arguments for tasks in task group. Nested array should have length equal to task count. Optional
- `env`        Environment variables for task group. Optional
- `watch`      Restart all tasks in task group when one of watched files was modified. Optional
- `timeout`    Timeout between SIGINT and SIGTERM for stop and restart commands. Defaults to 1000ms. Optional
- `cwd`        Task group working directory. Defaults to path. Optional
- `runtime`    Minimal runtime required for persistent task to be restarted after unclean exit

# Logs

Weaver will collect logs for you and send anything from subtasks stdout and stderr to udp4:localhost:8092 (or any other port of your choice).
In debug mode this functionality is disabled and logs are printed to stdout.
To do something with this logs you can use monitor mode

	weaver monitor

Or any other program capable to capture udp

	socat udp4-listen:8092 stdout

# Copyright and License

Copyright 2012-2014 Alexander Nazarov. All rights reserved.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.
