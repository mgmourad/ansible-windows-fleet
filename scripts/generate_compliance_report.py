#!/usr/bin/env python3
"""
Generate HTML Compliance Report from Ansible JSON output.

Usage:
    ansible-playbook playbooks/compliance_check.yml --ask-vault-pass | tee /tmp/compliance.log
    python3 scripts/generate_compliance_report.py --input /tmp/compliance.json --output reports/compliance.html

Or parse from Ansible callback JSON:
    ANSIBLE_CALLBACKS_ENABLED=json ansible-playbook playbooks/compliance_check.yml \
        --ask-vault-pass -e "ansible_json_output=true" > /tmp/compliance.json
    python3 scripts/generate_compliance_report.py --input /tmp/compliance.json
"""

import argparse
import json
import os
from datetime import datetime
from pathlib import Path


def generate_html_report(data: dict, output_path: str) -> None:
    """Generate a styled HTML compliance report."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Fleet Compliance Report — {timestamp}</title>
    <style>
        body {{
            font-family: 'Segoe UI', Tahoma, sans-serif;
            max-width: 1000px;
            margin: 40px auto;
            padding: 0 20px;
            background: #1a1a2e;
            color: #eee;
        }}
        h1 {{ color: #00d4ff; border-bottom: 2px solid #00d4ff; padding-bottom: 10px; }}
        h2 {{ color: #ff6b6b; }}
        table {{
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }}
        th, td {{
            padding: 12px 15px;
            text-align: left;
            border-bottom: 1px solid #333;
        }}
        th {{ background: #16213e; color: #00d4ff; }}
        tr:hover {{ background: #16213e; }}
        .pass {{ color: #00ff88; font-weight: bold; }}
        .fail {{ color: #ff4444; font-weight: bold; }}
        .warn {{ color: #ffbb33; font-weight: bold; }}
        .meta {{ color: #888; font-size: 0.9em; }}
        .summary-box {{
            background: #16213e;
            padding: 20px;
            border-radius: 8px;
            margin: 20px 0;
            border-left: 4px solid #00d4ff;
        }}
    </style>
</head>
<body>
    <h1>🔒 Fleet Compliance Report</h1>
    <p class="meta">Generated: {timestamp} | Project: ansible-windows-fleet</p>

    <div class="summary-box">
        <h2>Summary</h2>
        <p>Hosts scanned: {len(data.get('hosts', []))}</p>
        <p>Report type: Compliance Scan (Read-Only)</p>
    </div>

    <h2>Host Details</h2>
    <table>
        <tr>
            <th>Host</th>
            <th>Missing Updates</th>
            <th>Local Admins</th>
            <th>DSC Status</th>
            <th>Overall</th>
        </tr>
"""

    for host in data.get("hosts", []):
        updates = host.get("missing_updates", 0)
        admins = host.get("admin_count", "N/A")
        dsc = host.get("dsc_status", "Unknown")
        overall = "PASS" if updates == 0 and dsc == "InDesiredState: True" else "NEEDS ATTENTION"
        css_class = "pass" if overall == "PASS" else "warn"

        html += f"""        <tr>
            <td>{host.get('name', 'Unknown')}</td>
            <td class="{'pass' if updates == 0 else 'fail'}">{updates}</td>
            <td>{admins}</td>
            <td>{dsc}</td>
            <td class="{css_class}">{overall}</td>
        </tr>
"""

    html += """    </table>

    <div class="summary-box">
        <h2>Recommendations</h2>
        <ul>
            <li>Hosts with missing updates should be patched during the next maintenance window.</li>
            <li>Review unauthorized admin accounts and remove if not needed.</li>
            <li>Ensure DSC is configured on all managed endpoints.</li>
        </ul>
    </div>
</body>
</html>"""

    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        f.write(html)
    print(f"Report generated: {output_path}")


def main():
    parser = argparse.ArgumentParser(description="Generate HTML compliance report")
    parser.add_argument("--input", default="/tmp/compliance.json", help="Input JSON file")
    parser.add_argument("--output", default="reports/compliance.html", help="Output HTML file")
    args = parser.parse_args()

    if os.path.exists(args.input):
        with open(args.input) as f:
            data = json.load(f)
    else:
        # Generate sample report for demonstration
        print(f"Input file {args.input} not found — generating sample report")
        data = {
            "hosts": [
                {"name": "win11-vm01", "missing_updates": 3, "admin_count": 2, "dsc_status": "InDesiredState: True"},
                {"name": "win11-vm02", "missing_updates": 0, "admin_count": 2, "dsc_status": "InDesiredState: True"},
                {"name": "winserver-vm01", "missing_updates": 7, "admin_count": 4, "dsc_status": "InDesiredState: False"},
            ]
        }

    generate_html_report(data, args.output)


if __name__ == "__main__":
    main()
