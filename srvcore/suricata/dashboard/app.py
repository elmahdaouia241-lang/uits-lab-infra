#!/usr/bin/env python3
"""Suricata Dashboard (Flask) - affiche les dernieres alertes de /var/log/suricata/eve.json.

Execute par suricata-dashboard.service sur srvcore, port 5000 (ouvert uniquement au VLAN admin par UFW).
Lecture seule : aucune ecriture, aucune action sur Suricata.
"""
import json
import os
from collections import deque
from html import escape

from flask import Flask, jsonify

EVE_LOG = os.environ.get("EVE_LOG", "/var/log/suricata/eve.json")
MAX_ALERTS = int(os.environ.get("MAX_ALERTS", "20"))
SCAN_LINES = 5000  # on ne relit que la fin du fichier

app = Flask(__name__)


def latest_alerts():
    """Retourne les MAX_ALERTS alertes les plus recentes (la plus recente en premier)."""
    alerts = []
    try:
        with open(EVE_LOG, "r", encoding="utf-8", errors="replace") as fh:
            tail = deque(fh, maxlen=SCAN_LINES)
    except OSError:
        return alerts
    for line in reversed(tail):
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if event.get("event_type") != "alert":
            continue
        alert = event.get("alert", {})
        alerts.append({
            "time": event.get("timestamp", ""),
            "signature": alert.get("signature", "?"),
            "severity": alert.get("severity", 3),
            "src": event.get("src_ip", "?"),
            "dest": event.get("dest_ip", "?"),
            "proto": event.get("proto", ""),
        })
        if len(alerts) >= MAX_ALERTS:
            break
    return alerts


@app.route("/")
def index():
    rows = "".join(
        "<li><b>{sig}</b> | {src} -&gt; {dst} | sev {sev} | {time}</li>".format(
            sig=escape(a["signature"]), src=escape(a["src"]), dst=escape(a["dest"]),
            sev=int(a["severity"]), time=escape(a["time"][:19]))
        for a in latest_alerts()
    ) or "<li>Aucune alerte</li>"
    return (
        "<!doctype html><html lang='fr'><head><meta charset='utf-8'>"
        "<meta http-equiv='refresh' content='10'><title>Suricata Dashboard</title>"
        "<style>body{background:#111;color:#0f0;font-family:Arial,sans-serif;padding:24px}"
        "h1{color:#0fc}.box{border:1px solid #0a0;padding:16px}li{margin:8px 0}</style></head>"
        "<body><h1>Suricata Dashboard</h1><div class='box'><h2>Latest Alerts</h2>"
        "<ul>" + rows + "</ul></div></body></html>"
    )


@app.route("/api/alerts")
def api_alerts():
    return jsonify(latest_alerts())


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
