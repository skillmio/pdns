# Skillmio DNS

**Skillmio DNS** is a **privacy-focused DNS service** used daily by **individuals and organizations** to block ads, trackers, phishing, malware, and invasive telemetry.

As a **byproduct** of this activity, we generate two high-quality blocklists:

* **`domain-blist`** – DNS domains for blocking
* **`ip-blist`** – IPs involved in malicious or abusive activity

These lists are derived from **real-world DNS traffic** and are continuously updated.

## Quick Highlights

* **Privacy-first DNS** – block ads & trackers network-wide
* **Threat intelligence blocklists** – domain & IP lists from real usage
* **Cross-platform** – Windows, Linux, macOS, Android, iOS, routers, firewalls
* **Supports secure DNS** – DNS-over-HTTPS (DoH) & DNS-over-TLS (DoT)
* **For everyone** – home, enterprise, on-prem, and cloud environments

## Public DNS

```
DNS-over-HTTPS (DoH) & DNS-over-TLS (DoT): dns.skillmio.net
dns1:
dns2:
```

## Getting Started

### Pi-hole

1. Add **Skillmio DNS** as a custom upstream server.
2. Enable automatic updates for blocklists if desired.

### Unbound / BIND

1. Configure as a recursive resolver with **dns.skillmio.net** as upstream.
2. Optionally, use `domain-blist` for local zone blocking.

### OPNsense / pfSense / Firewalls / fail2ban

1. Set DNS forwarding to **Skillmio DNS**.
2. Apply `ip-blist` to firewall rules for perimeter security.

## Use Cases

* Network-wide ad and tracker blocking
* Privacy-focused DNS filtering for individuals and organizations
* Phishing and malware protection
* Perimeter defense for public-facing services
