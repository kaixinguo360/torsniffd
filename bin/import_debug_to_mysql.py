#!/usr/bin/env python3
# coding=utf-8
 
import os, sys, traceback
import re
from datetime import datetime
import pymysql

input_file = sys.argv[1]
mysql_enabled=os.getenv('MYSQL_ENABLED')
mysql_host=os.getenv('MYSQL_HOST', 'localhost')
mysql_port=int(os.getenv('MYSQL_PORT', '3306'))
mysql_user=os.getenv('MYSQL_USER')
mysql_passwd=os.getenv('MYSQL_PASSWORD')
mysql_db=os.getenv('MYSQL_DB')

try:
    conn = pymysql.connect(host=mysql_host, port=mysql_port, user=mysql_user, passwd=mysql_passwd, db=mysql_db)
except:
    print('\n>>>>> Mysql Connect Failed! <<<<<\n', file=sys.stderr)
    traceback.print_exc(file=sys.stderr)
    sys.stderr.flush()
    exit(1)

c_all = 0
c_idt = 0
c_dup = 0
c_dup_update = 0

def run_per_line(hash, time):
    global c_idt, c_dup, c_dup_update
    with conn.cursor() as c:
        time_str = time.strftime('%Y-%m-%d %H:%M:%S');
        c.execute(f"select time from torrent where hash = '{hash}'")
        r = c.fetchone()
        if r:
            c_dup = c_dup + 1
            old_time = r[0]
            if t_time <= old_time:
                return
            c_dup_update = c_dup_update + 1
            sql = f"update torrent set time = '{time_str}' where hash = '{hash}'"
            c.execute(sql)
            conn.commit()
            #print(f"MYSQL: {sql}")
        else:
            c_idt = c_idt + 1
            sql = f"insert into torrent (hash, time, num, size, name, ctime) values ('{hash}', '{time_str}', 1, null, null, '{time_str}')"
            c.execute(sql)
            conn.commit()
            #print(f"MYSQL: {sql}")

for line in open(input_file):
    try:
        if c_all % 1000 == 0:
            print(f"all {c_all}, idt {c_idt}, dup {c_dup} ({c_dup_update})")
        c_all = c_all + 1
        line = line.strip()
        m = re.match(r'^([a-z0-9]{40})\s([0-9]+)\.[0-9]+\s([a-z])$', line, re.M|re.I)
        if not m:
            continue
        t_hash = m.group(1)
        t_time = datetime.fromtimestamp(int(m.group(2)))
        t_new = True if m.group(3) == 'p' else False
        #print(t_hash, t_time_str, t_new)
        run_per_line(t_hash, t_time)
    except Exception as e:
        traceback.print_exc(file=sys.stderr)
        sys.stderr.flush()
        raise e
        continue

