#!/usr/bin/env python3
import json
import requests
import sys
from datetime import datetime, timedelta
from collections import defaultdict

# Configuration
WAZUH_API = "https://localhost:55000"
WAZUH_USER = "#########"
WAZUH_PASS = "#########"
TIME_WINDOW_MINUTES = 60
ALERT_FILE = "/var/ossec/logs/alerts/alerts.json"
DAY_THRESHOLD_OCTETS = 1_000_000_000   # 1GB limite du jour
NIGHT_THRESHOLD_OCTETS = 100_000_000   # 100MB limite de nuit/weekend
DAY_START_HOUR = 8
DAY_END_HOUR = 19

# Recuperer un token d'authentification
def get_token():
    r = requests.post(f"{WAZUH_API}/security/user/authenticate",
                      auth=(WAZUH_USER, WAZUH_PASS), verify=False)
    return r.json()["data"]["token"]

# retourne la limite en vigeur
def get_current_threshold():
    now = datetime.now()
    current_hour = now.hour
    current_weekday = now.weekday()  # 0=lundi, 6=dimanche

    # Weekend
    if current_weekday >= 5:
        return NIGHT_THRESHOLD_OCTETS, "weekend"

    # nuit semaine
    if current_hour < DAY_START_HOUR or current_hour >= DAY_END_HOUR:
        return NIGHT_THRESHOLD_OCTETS, "night"

    # jour semaine
    return DAY_THRESHOLD_OCTETS, "daytime"

#recuperer les evenements depuis 1h
def get_events(token):
    now = datetime.utcnow()
    one_hour_ago = now - timedelta(minutes=TIME_WINDOW_MINUTES)

    query = {
        "query": {
            "bool": {
                "must": [
                    {"term": {"rule.groups": "sophos"}},
                    {"term": {"decoder.name": "sophos-firewall"}},
                    {"range": {"timestamp": {
                        "gte": one_hour_ago.isoformat(),
                        "lte": now.isoformat()
                    }}}
                ]
            }
        }
    }

    headers = {"Authorization": f"Bearer {token}"}
    r = requests.post(f"{WAZUH_API}/events", json=query, headers=headers, verify=False)
    return r.json()

# somme des octets par adresse IP (ip source)
def analyze_exfiltration(events):
    ip_totals = defaultdict(lambda: {"total_octets": 0, "connections": 0, "destinations": set()})

    for event in events:
        src_ip = event.get("data", {}).get("src_ip", "unknown")
        octets_sent = int(event.get("data", {}).get("bytes_sent", 0))
        dst_ip = event.get("data", {}).get("dst_ip", "unknown")

        ip_totals[src_ip]["total_octets"] += octets_sent
        ip_totals[src_ip]["connections"] += 1
        ip_totals[src_ip]["destinations"].add(dst_ip)

    return ip_totals

#crer une alerte
def generate_alert(src_ip, data, threshold_octets, period_name):
    total_mb = data['total_octets'] / 1_000_000
    threshold_mb = threshold_octets / 1_000_000

    if period_name == "night":
        severity = "HIGH"
        level = 12
    elif period_name == "weekend":
        severity = "HIGH"
        level = 12
    else:
        severity = "MEDIUM"
        level = 9

    alert = {
        "timestamp": datetime.utcnow().isoformat(),
        "rule": {
            "id": "118725",
            "level": level,
            "description": f"{severity} - DATA EXFILTRATION [{period_name.upper()}]: "
                          f"{data['total_octets']:,} octets ({total_mb:.1f}MB) "
                          f"exfiltrated from {src_ip} to {len(data['destinations'])} destinations "
                          f"in the last {TIME_WINDOW_MINUTES} minutes "
                          f"across {data['connections']} connections "
                          f"(threshold: {threshold_mb:.0f}MB)"
        },
        "agent": {"name": "sophos-integration"},
        "data": {
            "src_ip": src_ip,
            "total_octets": data["total_octets"],
            "total_mb": round(total_mb, 2),
            "threshold_mb": round(threshold_mb, 2),
            "period": period_name,
            "connections": data["connections"],
            "destinations": list(data["destinations"]),
            "time_window_minutes": TIME_WINDOW_MINUTES
        }
    }

    with open(ALERT_FILE, "a") as f:
        f.write(json.dumps(alert) + "\n")

def main():
    try:
        threshold_octets, period_name = get_current_threshold()

        now = datetime.now()
        print(f"[{now.strftime('%Y-%m-%d %H:%M:%S')}]")
        print(f"  Period: {period_name}")
        print(f"  Threshold: {threshold_octets:,} octets ({threshold_octets/1_000_000:.0f}MB)")
        print(f"  Time window: {TIME_WINDOW_MINUTES} minutes")
        print()

        token = get_token()
        events_data = get_events(token)
        events = events_data.get("data", {}).get("hits", {}).get("hits", [])

        print(f"  Events found: {len(events)}")

        if len(events) == 0:
            print("  No events to analyze.")
            return

        ip_totals = analyze_exfiltration(events)

        alerts_generated = 0
        for src_ip, data in ip_totals.items():
            total_mb = data['total_octets'] / 1_000_000

            if data["total_octets"] >= threshold_octets:
                generate_alert(src_ip, data, threshold_octets, period_name)
                alerts_generated += 1
                print(f"ALERT: {src_ip} - {data['total_octets']:,} octets ({total_mb:.1f}MB) - EXCEEDS THRESHOLD")
            else:
                print(f"OK: {src_ip} - {data['total_octets']:,} octets ({total_mb:.1f}MB) - below threshold")

        print(f"\n  Total alerts generated: {alerts_generated}")

    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()