# Director

* Workers need to be run as root to interract with CPI (Don't know how to solve this)
* Drain should use BPM
* Improve PATH environment variable
* NGINX proxy_temp path? (need to mkdir in pre-start, but its read-only otherwise)
* Console should use BPM
* Trigger DNS should use BPM
* CPIs that aren't `warden_cpi`

# Postgres

* Use BPM
* Daemonized Processes?

# Power DNS

* Use BPM (Don't know how to enable it)

# BPM

* runc package conflicts with garden, director is compilation vm
