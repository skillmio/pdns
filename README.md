# Collaborative Sec (CoSec)

**Collaborative Sec (CoSec)** is a community-driven security initiative focused on sharing, curating, and maintaining high-quality threat-intelligence artifacts.
Its goal is to make basic security hygiene (anti-tracking, ad blocking, abuse mitigation) **simple, transparent, and reusable** across different systems and environments.

CoSec emphasizes:

* **Collaboration**: contributions from multiple maintainers and users
* **Minimalism**: block what matters, avoid unnecessary breakage
* **Portability**: easy integration into DNS, firewall, proxy, or application layers


## Blocked domains

A curated project to block **tracking, advertising, telemetry, and known abusive domains**.

The list is designed to reduce noise and unwanted traffic while preserving normal functionality as much as possible.

**Blocked Domains Over Time Graph**

![Blocked Domains Graph](https://raw.githubusercontent.com/skillmio/CoSec/master/files/blocked_domains_graph.png)

### How to use

The `blocked_domains` list can be used in multiple contexts, such as:

* DNS blockers (Pi-hole, AdGuard, Unbound, Bind, dnsmasq)
* Firewall or proxy rules
* Application-level filtering
* Hosts-file based blocking

**Typical usage pattern:**

**Option 1: Managed DNS (no local configuration)** 
1. Point on your host point to
* DNS: dns.skillmio.net
* DNS1: 102.213.34.98
* DNS2: 196.61.76.76
  
**Option 2: Self-managed integration**
1. Fetch the [`blocked_domains.txt`](https://raw.githubusercontent.com/skillmio/CoSec/master/blocked_domains.txt) list.
2. Load it into your blocking mechanism.
3. Apply reload / restart if required.
 
Explore more usage options at [https://skillmio.github.io/](https://skillmio.github.io/)

### How it's made

The final **blocked_domains** list is generated deterministically using three inputs:

* **external_blocked_domains**
  Trusted third-party blocklists (ads, trackers, known abuse sources)

* **candidate_domains**
  Domains identified by the community or maintainers for potential blocking

* **exempt_domains**
  Explicitly allowed domains to prevent breakage or false positives

The generation logic is:

> **blocked_domains = external_blocked_domains + candidate_domains − exempt_domains**

This ensures:

* External intelligence is respected
* Local or contextual threats are included
* Critical or legitimate domains remain accessible


## Banned IP's

A maintained list of **malicious or abusive IP addresses**, typically associated with scanning, brute-force attacks, spam, or other hostile activity.

This list is intended for **network-level enforcement**.

**Banned IP's Over Time Graph**

![Banned IP's Graph](https://raw.githubusercontent.com/skillmio/CoSec/master/files/banned_ips_graph.png)

### How to use

The `banned_ips` list can be applied to:

* Firewalls (iptables, nftables, firewalld)
* Routers or gateways
* Cloud security groups
* Intrusion prevention systems

**Typical usage pattern:**

1. Import the [`banned_ips`](https://raw.githubusercontent.com/skillmio/CoSec/master/banned_ips.txt) list.
2. Apply it as deny / drop rules.
3. Automate periodic updates.
4. Review logs for accidental blocks.

### How it's made

The **banned_ips** list is assembled from:


* Logs and abuse patterns
* Community reports and observations
* Manual validation by maintainers

Before inclusion:

* IPs are checked for consistency and recurrence
* Temporary or noisy IPs may be excluded

The objective is **accuracy over volume**: fewer IPs, higher confidence.

Explore more usage options at [https://skillmio.github.io/](https://skillmio.github.io/)

