import os
import requests
import mysql.connector
from mysql.connector import Error
from datetime import datetime
from requests.auth import HTTPBasicAuth

# --- CONFIGURATION VIA ENVIRONMENT VARIABLES ---
# Securely load credentials from the system environment. 
# Never hardcode passwords in this file.
SENAITE_URL = os.getenv("SENAITE_URL", "http://localhost:8080/senaite")
SENAITE_USER = os.getenv("SENAITE_USER", "admin")
SENAITE_PASSWORD = os.getenv("SENAITE_PASSWORD", "fallback_secure_password")

DB_CONFIG = {
    'host': os.getenv("DB_HOST", "localhost"),
    'database': os.getenv("DB_NAME", "senaite_db"),
    'user': os.getenv("DB_USER", "senaite_user"),
    'password': os.getenv("DB_PASSWORD", "fallback_db_password")
}

# Base API endpoint URL builder
SENAITE_API_URL = f"{SENAITE_URL.rstrip('/')}/@@API/senaite/v1"

AUTH = HTTPBasicAuth(SENAITE_USER, SENAITE_PASSWORD)
HEADERS = {
    "Accept": "application/json"
}

def parse_date(date_str):
    if not date_str:
        return None
    try:
        clean_str = date_str.split('+')[0].split('Z')[0]
        dt = datetime.fromisoformat(clean_str)
        return dt.strftime('%Y-%m-%d %H:%M:%S')
    except Exception:
        return None

def fetch_senaite_data(endpoint):
    all_records = []
    page = 1
    limit = 100
    
    while True:
        url = f"{SENAITE_API_URL}/{endpoint}?page={page}&limit={limit}"
        print(f"[i] API Request to: {url}")
        
        try:
            response = requests.get(url, headers=HEADERS, auth=AUTH, timeout=30)
            print(f"[i] API Status Code: {response.status_code}")
            
            if response.status_code == 404:
                print(f"[-] Endpoint '{endpoint}' returned 404. Stopping.")
                break
                
            response.raise_for_status()
            data = response.json()
            
            items = data.get('items', data.get('data', []))
            print(f"[+] Page {page}: {len(items)} raw items found.")
            
            if not items:
                break
                
            for index, light_item in enumerate(items):
                detail_url = light_item.get("api_url")
                
                if detail_url:
                    try:
                        detail_response = requests.get(detail_url, headers=HEADERS, auth=AUTH, timeout=30)
                        if detail_response.status_code == 200:
                            detail_json = detail_response.json()
                            
                            if 'items' in detail_json and isinstance(detail_json['items'], list) and len(detail_json['items']) > 0:
                                obj = detail_json['items'][0]
                            elif 'data' in detail_json:
                                obj = detail_json['data']
                            else:
                                obj = detail_json
                            
                            if isinstance(obj, dict) and 'uid' in obj:
                                all_records.append(obj)
                            else:
                                print(f"     [x] Warning: Invalid object structure in detail API.")
                    except Exception as detail_err:
                        print(f"     [x] Error fetching detail URL: {detail_err}")
                else:
                    all_records.append(light_item)

            if len(items) < limit:
                break
            page += 1
            
        except Exception as e:
            print(f"[-] Error in fetch_senaite_data for {endpoint}: {e}")
            break
            
    print(f"[=] Total successfully collected records for {endpoint}: {len(all_records)}")
    return all_records

def sync_table(cursor, table_name, columns, unique_key, items, extract_fn):
    if not items:
        print(f"[*] No items to sync for {table_name}.")
        return
        
    placeholders = ", ".join(["%s"] * len(columns))
    update_assignments = ", ".join([f"{col} = new.{col}" for col in columns if col != unique_key])
    query = f"INSERT INTO {table_name} ({', '.join(columns)}) VALUES ({placeholders}) AS new ON DUPLICATE KEY UPDATE {update_assignments}"
    
    records = []
    for item in items:
        try:
            rec = extract_fn(item)
            if rec: 
                records.append(rec)
        except Exception as extract_err:
            print(f"[-] Error mapping item lambda for {table_name}: {extract_err}")
            
    if records:
        try:
            cursor.executemany(query, records)
            print(f"[✓] {table_name} synchronized successfully. ({len(records)} rows)")
        except Exception as e:
            print(f"[-] Database error in {table_name}: {e}")
    else:
        print(f"[*] No records successfully parsed for {table_name}.")

def main():
    try:
        print("[*] Connecting to MySQL Database...")
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor()
        
        # Temporarily disable foreign keys to safely allow batch syncing out of exact chronological order
        cursor.execute("SET FOREIGN_KEY_CHECKS = 0;")

        # 1. LAB DEPARTMENTS
        sync_table(
            cursor=cursor, 
            table_name='lab_departments', 
            columns=['uid', 'title', 'description', 'review_state', 'creator', 'created_date'], 
            unique_key='uid', 
            items=fetch_senaite_data('department'), 
            extract_fn=lambda item: (item.get('uid'), item.get('title'), item.get('description'), item.get('review_state'), item.get('author'), parse_date(item.get('created'))))
        
        # 2. INSTRUMENTS
        sync_table(
            cursor=cursor, 
            table_name='instruments', 
            columns=['uid', 'title', 'model', 'serial_number', 'manufacturer', 'calibration_expiry', 'review_state', 'creator', 'created_date'], 
            unique_key='uid', 
            items=fetch_senaite_data('instrument'), 
            extract_fn=lambda item: (item.get('uid'), item.get('title'), item.get('model'), item.get('serial_number'), item.get('manufacturer'), parse_date(item.get('calibration_expiry')), item.get('review_state'), item.get('creator', 'system'), parse_date(item.get('created'))))
        
        # 3. CALCULATIONS
        sync_table(
            cursor=cursor, 
            table_name='calculations', 
            columns=['uid', 'title', 'formula', 'description', 'creator', 'created_date'], 
            unique_key='uid', 
            items=fetch_senaite_data('calculation'), 
            extract_fn=lambda item: (item.get('uid'), item.get('title'), item.get('formula'), item.get('description'), item.get('creator', 'system'), parse_date(item.get('created'))))
        
        # 4. METHODS
        sync_table(
            cursor=cursor, 
            table_name='methods', 
            columns=['uid', 'title', 'instructions', 'instrument_uid', 'review_state', 'creator', 'created_date'], 
            unique_key='uid', 
            items=fetch_senaite_data('method'), 
            extract_fn=lambda item: (item.get('uid'), item.get('title'), item.get('instructions'), item.get('instrument', {}).get('uid') if isinstance(item.get('instrument'), dict) else item.get('instrument_uid'), item.get('review_state'), item.get('creator', 'system'), parse_date(item.get('created'))))
        
        # 5. ANALYSIS SERVICES (Recovered and completed)
        sync_table(
            cursor=cursor, 
            table_name='analysis_services', 
            columns=['uid', 'title', 'keyword', 'unit', 'department_uid', 'method_uid', 'calculation_uid', 'price', 'review_state', 'creator', 'created_date'], 
            unique_key='uid', 
            items=fetch_senaite_data('analysisservice'), 
            extract_fn=lambda item: (item.get('uid'), item.get('title'), item.get('keyword'), item.get('unit'), item.get('department', {}).get('uid'), item.get('method', {}).get('uid'), item.get('calculation', {}).get('uid'), item.get('price', 0.00), item.get('review_state'), item.get('creator', 'system'), parse_date(item.get('created'))))

        # Re-enable foreign key constraints
        cursor.execute("SET FOREIGN_KEY_CHECKS = 1;")
        conn.commit()
        print("[✓] Pipeline database sync transaction completed successfully!")

    except Error as db_err:
        print(f"[-] Database connection failed: {db_err}")
    finally:
        if 'conn' in locals() and conn.is_connected():
            cursor.close()
            conn.close()
            print("[*] MySQL connection closed cleanly.")

if __name__ == "__main__":
    main()
