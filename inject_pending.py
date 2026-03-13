import json
import subprocess
import time
import os

def inject_db():
    with open('unique_sms_formats.json', 'r', encoding='utf-8') as f:
        templates = json.load(f)

    # The hisaabmate database path on Android
    DB_PATH = '/data/data/com.cointally.app/databases/hisaabmate.db'

    print(f'Injecting {len(templates)} unique SMS messages as pending transactions...')

    # Check if we have su access or if we can run sqlite3
    try:
        res = subprocess.run(['adb', 'shell', 'su', '-c', 'ls'], capture_output=True, text=True, timeout=5)
        if res.returncode != 0:
            print("WARNING: Root access (su) might not be available or permitted. Database injection may fail.")
    except Exception as e:
        print(f"Failed to check root access: {e}")

    batch_size = 50
    date_ms = int(time.time() * 1000)
    
    for i in range(0, len(templates), batch_size):
        batch = templates[i:i+batch_size]
        
        # Construct a single SQL script to execute
        sql_lines = ['BEGIN TRANSACTION;']
        
        for item in batch:
            sender = item['sender'].replace("'", "''")
            body = item['text'].replace("'", "''")
            
            # Use fixed basic values so the UI parser can read the raw_title and raw_body
            sql_lines.append(f"INSERT INTO pending_transactions (amount, type, date, raw_title, raw_body, package_name, is_reconciled) VALUES (0, 'EXPENSE', {date_ms}, '{sender}', '{body}', 'com.android.mms', 0);")
            
            # Decrement date_ms slightly to preserve order
            date_ms -= 1000
        
        sql_lines.append('COMMIT;')
        sql_script = "\\n".join(sql_lines)
        
        # Write to a temp file
        with open('temp_inject.sql', 'w', encoding='utf-8') as f:
            f.write(sql_script)
            
        subprocess.run(['adb', 'push', 'temp_inject.sql', '/data/local/tmp/temp_inject.sql'], capture_output=True)
        
        # Execute sqlite3 as root
        # Read the file and execute it in sqlite3
        res = subprocess.run([
            'adb', 'shell', 
            'su', '-c', f'"sqlite3 {DB_PATH} < /data/local/tmp/temp_inject.sql"'
        ], capture_output=True, text=True)
        
        if res.returncode != 0:
            print(f'Error executing batch {i}: {res.stderr}')
        else:
            print(f'Successfully injected batch {i}-{i+len(batch)}')

    print('Injection complete.')
    if os.path.exists('temp_inject.sql'):
        os.remove('temp_inject.sql')

if __name__ == '__main__':
    inject_db()
