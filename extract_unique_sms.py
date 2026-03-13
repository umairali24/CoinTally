import csv
import re
import subprocess
import time
import json
import logging
from collections import OrderedDict

logging.basicConfig(level=logging.INFO, format='%(message)s')

def get_unique_templates(csv_path):
    unique_templates = OrderedDict()
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            sender = row['Contact']
            text = row['Content']
            
            # Normalize text down to its structure to find unique templates
            normalized = re.sub(r'\b\d+\b', '{N}', text)
            normalized = re.sub(r'\b\d{2}-\d{2}-\d{2,4}\b', '{D}', normalized)
            # handle dates like 02-Jun-25
            normalized = re.sub(r'\b\d{2}-[a-zA-Z]{3}-\d{2,4}\b', '{D}', normalized)
            normalized = re.sub(r'\b\d{2}:\d{2}:\d{2}\b', '{T}', normalized)
            normalized = re.sub(r'\b(?:\d{1,3},)?(?:\d{3},)*\d{3}(?:\.\d{2})?\b', '{AMT}', normalized)
            
            key = (sender, normalized)
            if key not in unique_templates:
                unique_templates[key] = (sender, text)
                
    return list(unique_templates.values())

def inject_sms(sender, text):
    # Escape quotes for adb shell
    # For windows cmd, we need to be careful with quotes
    # The safest way is to base64 encode or just use a helper if it gets too complex, 
    # but let's try a direct broadcast first
    
    sender_clean = sender.replace('"', '\\"').replace("'", "''")
    text_clean = text.replace('"', '\\"').replace("'", "''")
    
    # We can send a broadcast with action "android.provider.Telephony.SMS_RECEIVED"
    # Wait, Android blocks fake SMS_RECEIVED broadcasts to normal apps.
    # Instead, let's use the local db_helper to insert them directly over ADB?
    # Actually, HisaabMate uses flutter_notification_listener. 
    # To test TransactionParser easily on the device, the BEST way is to inject 
    # them straight into the 'pending_transactions' database table.
    pass

if __name__ == '__main__':
    csv_path = 'SMS_Backup.csv'
    templates = get_unique_templates(csv_path)
    logging.info(f"Found {len(templates)} unique SMS formats.")
    
    with open('unique_sms_formats.json', 'w', encoding='utf-8') as f:
        json.dump([{'sender': s, 'text': t} for s, t in templates], f, indent=2)
    
    logging.info("Saved unique formats to unique_sms_formats.json")
