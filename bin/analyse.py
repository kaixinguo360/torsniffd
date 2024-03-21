#!/usr/bin/env python3
# coding=utf-8
 
import os
import sys
import collections
import traceback
from datetime import datetime

import redis
import pymysql
from bencoder import bdecode

#envs = collections.defaultdict(lambda:None, os.environ)
max_file_count = 1000
input_file = sys.argv[1]

redis_enabled=os.getenv('REDIS_ENABLED')
redis_expire=int(os.getenv('REDIS_EXPIRE', '86400'))
redis_host=os.getenv('REDIS_HOST', 'localhost')
redis_port=int(os.getenv('REDIS_PORT', '6379'))

mysql_enabled=os.getenv('MYSQL_ENABLED')
mysql_host=os.getenv('MYSQL_HOST', 'localhost')
mysql_port=int(os.getenv('MYSQL_PORT', '3306'))
mysql_user=os.getenv('MYSQL_USER')
mysql_passwd=os.getenv('MYSQL_PASSWORD')
mysql_db=os.getenv('MYSQL_DB')

r = redis.StrictRedis(host=redis_host, port=redis_port, db=0)
try:
    conn = pymysql.connect(host=mysql_host, port=mysql_port, user=mysql_user, passwd=mysql_passwd, db=mysql_db)
except:
    print('\n>>>>> Mysql Connect Failed! <<<<<\n', file=sys.stderr)
    traceback.print_exc(file=sys.stderr)
    sys.stderr.flush()

def dir_empty(dir_path):
    try:
        next(os.scandir(dir_path))
        return False
    except StopIteration:
        return True

def sizeof_fmt(num, suffix="B", factor=1024.0):
    for unit in ["", "K", "M", "G", "T", "P", "E", "Z"]:
        if abs(num) < factor:
            return f"{num:3.1f}{unit}{suffix}"
        num /= factor
    return f"{num:.1f}Yi{suffix}"

#def obj_decode(d: str | dict | list):
def obj_decode(d):
    if isinstance(d, bytes):
        try:
            d = d.decode()
        except:
            pass
    if isinstance(d, dict):
        new_dict = {}
        for k in d:
            item = obj_decode(d[k])
            k = obj_decode(k)
            new_dict[k] = item
        d = new_dict
    if isinstance(d, list):
        new_list = []
        for i in d:
            new_list.append(obj_decode(i))
        d = new_list
    return d

def rm_torrent(torrent):
    try:
        os.remove(torrent)
        p_dir = os.path.dirname(torrent)
        while True:
            if dir_empty(p_dir):
                os.rmdir(p_dir)
                p_dir = os.path.dirname(p_dir)
            else:
                break
    except Exception as e:
        traceback.print_exc(file=sys.stderr)
        pass

# Use redis to de-duplication (fast)
def check_hash_with_redis(t_hash):
    if not redis_enabled:
        return True
    try:
        if r.exists(t_hash):
            r.expire(t_hash, redis_expire)
            r.incr(t_hash)
            return False
        # Record uncached hash to redis
        r.setex(t_hash, redis_expire, 1)
        return True
    except Exception as e:
        return True

# Use hash.txt to de-duplication (slowly)
def check_hash_with_file(t_hash):
    try:
        if os.system(f"grep -q {t_hash} ./log/hash*") == 0:
            return False
        # Record new hash to txt file
        f_hash.write(f"{t_hash}\n")
        f_hash.flush()
        return True
    except Exception as e:
        print(e, file=sys.stderr)
        return False

# Check hash to de-duplication
def check_hash(t_hash, time=datetime.now()):
    if not check_hash_with_mysql(t_hash, time):
        return False
    if not check_hash_with_redis(t_hash):
        return False
    if not check_hash_with_file(t_hash):
        return False
    return True

# Use mysql to de-duplication
def check_hash_with_mysql(hash, time=datetime.now()):
    if not mysql_enabled:
        return True
    try:
        with conn.cursor() as c:
            #c.execute(f"select hash from torrent where hash = '{hash}'")
            #print(f"MYSQL: {c.fetchall()}", file=sys.stderr)
            time_str = now.strftime('%Y-%m-%d %H:%M:%S');
            sql = f"update torrent set num = num + 1, time = '{time_str}' where hash = '{hash}' and name is not null"
            line_count = c.execute(sql)
            conn.commit()
            return line_count == 0
    except Exception as e:
        return True

# Save hash and name to mysql database
def save_to_mysql(hash, size, name, time=datetime.now()):
    if mysql_enabled:
        try:
            with conn.cursor() as c:
                sql = f"select name from torrent where hash = '{hash}'"
                c.execute(sql)
                old_record = c.fetchone()
                if old_record:
                    if not old_record[0]:
                        sql = f"update torrent set size = '{size}', name = {conn.escape(name)} where hash = '{hash}'"
                        c.execute(sql)
                        conn.commit()
                    #else:
                    #    print(f"MYSQL: skip {hash}", file=sys.stderr)
                else:
                    time_str = now.strftime('%Y-%m-%d %H:%M:%S');
                    sql = f"insert into torrent (hash, time, num, size, name, ctime) values ('{hash}', '{time_str}', 1, '{size}', {conn.escape(name)}, '{time_str}')"
                    c.execute(sql)
                    conn.commit()
        except Exception as e:
            raise e

with open('./log/debug.txt', 'a') as f_debug, \
    open('./log/hash.txt', 'a') as f_hash, \
    open(input_file) as pipe:
    while True:
        try:
            torrent = pipe.readline().strip()
            if torrent == '':
                continue

            #print(f"torrent: {torrent}")
            t_hash = torrent.split('/')[-1].split('.')[0]
            now = datetime.now()
            now_timestamp = str(datetime.timestamp(now))[:14]
            #print(f"hash: {t_hash}")

            if not check_hash(t_hash, now):
                f_debug.write(f"{t_hash} {now_timestamp} f\n")
                f_debug.flush()
                rm_torrent(torrent)
                continue

            # Record new hash to debug file
            f_debug.write(f"{t_hash} {now_timestamp} p\n")
            f_debug.flush()

            with open(torrent, "rb") as t:
                meta_data = bdecode(t.read())

            meta_data = obj_decode(meta_data)
            meta_data = collections.defaultdict(lambda:None, meta_data)
            meta_info = meta_data['info']

            #keywords = set()
            keywords = [];

            t_name = meta_info['name.utf-8'] if 'name.utf-8' in meta_info else meta_info['name']
            t_node = {
                'name': t_name,
                'size': sizeof_fmt(meta_info['piece length'] * len(meta_info['pieces']) / 20),
                'length': meta_info['piece length'] * len(meta_info['pieces']) / 20,
                '_id': t_hash,
                'keywords': keywords,
            }

            keywords.append('n:' + t_name)
            
            if 'files' in meta_info:
                fs = {}
                fset = set()
                fcount = 0
                for i, file in enumerate(meta_info['files']):
                    #print(f"file[{i}].length: {file['length']}")
                    #print(f"file[{i}].path: {'/'.join(file['path'])}")
                    f_path = file['path.utf-8'] if 'path.utf-8' in file else file['path']
                    f_name = f_path[-1]
                    f_length = file['length']
                    fs_node = fs
                    for j in range(len(f_path) - 1):
                        dir_name = f_path[j]
                        if fcount < max_file_count:
                            keywords.append('d:' + dir_name)
                        if not dir_name in fs_node:
                            fs_node[dir_name] = {}
                        fs_node = fs_node[dir_name]
                    fs_node[f_name] = f_length
                    if fcount < max_file_count:
                        fcount = fcount + 1
                        keywords.append('f:' + f_name)
                    elif fcount == max_file_count:
                        keywords.append('skip:' + str(len(meta_info['files']) - max_file_count))
                t_node['multifile'] = True
                t_node['files'] = fs
            else:
                t_node['multifile'] = False
                t_node['ext'] = t_name.split('.')[-1].lower()

            if 'comment' in meta_data:
                t_node['comment'] = meta_data['comment']
                keywords.append('comment:' + str(meta_data['comment']))
            if 'created by' in meta_data:
                t_node['author'] = meta_data['created by']
                keywords.append('author:' + str(meta_data['created by']))
            if 'creation date' in meta_data:
                t_node['ctime'] = meta_data['creation date']
            if 'announce' in meta_data:
                t_node['announce'] = meta_data['announce']

            keywords = list(dict.fromkeys(keywords))
            keywords = '\x00'.join(keywords).replace('\t', ' ').replace('\x00', '\t').replace('\n', '\\n')
            t_node['keywords'] = keywords

            print(f"{t_hash}\ts:{t_node['size']}\t{keywords}")

            save_to_mysql(hash=t_hash, size=t_node['size'], name=t_name, time=now)

            #import pprint
            #pp = pprint.PrettyPrinter(indent=2)
            #pp.pprint(t_node)

            rm_torrent(torrent)

        except FileNotFoundError as e:
            pass

        except Exception as e:
            if 't_hash' not in dir():
                t_hash = '0000000000000000000000000000000000000000'
            print(t_hash + '\terror:' + str(e).replace('\n', '\\n'))
            traceback.print_exc(file=sys.stderr)
            pass

        sys.stdout.flush()
        sys.stderr.flush()

