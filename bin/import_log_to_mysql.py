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
c_fail = 0
c_idt = 0
c_dup = 0
c_dup_no_name = 0

def run_per_line(hash, size, name):
    global c_idt, c_dup, c_dup_no_name
    with conn.cursor() as c:
        c.execute(f"select name from torrent where hash = '{hash}'")
        r = c.fetchone()
        if r:
            c_dup = c_dup + 1
            old_name = r[0]
            if old_name is not None:
                return
            c_dup_no_name = c_dup_no_name + 1
            sql = f"update torrent set size = '{size}', name = {conn.escape(name)} where hash = '{hash}'"
            c.execute(sql)
            conn.commit()
            #print(f"MYSQL: {sql}")
        else:
            c_idt = c_idt + 1

for line in open(input_file):
    try:
        if c_all % 1000 == 0:
            print(f"all {c_all}, fail {c_fail}, idt {c_idt}, dup {c_dup} ({c_dup_no_name})")
        c_all = c_all + 1
        line = line.strip()
        m = re.match(r'^([a-z0-9]{40})\ts:([^\t]+)\tn:([^\t]+)(\t.*)?$', line, re.I)
        if not m:
            c_fail = c_fail + 1
            continue
        t_hash = m.group(1)
        t_size = m.group(2)
        t_name = m.group(3)
        #print(t_hash, t_size, t_name)
        run_per_line(t_hash, t_size, t_name)
    except Exception as e:
        traceback.print_exc(file=sys.stderr)
        sys.stderr.flush()
        raise e
        continue

