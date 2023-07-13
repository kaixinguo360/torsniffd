#!/usr/bin/env python3
# coding=utf-8
 
import os
import sys
import collections
import traceback
from datetime import datetime

import redis
from bencoder import bdecode

#envs = collections.defaultdict(lambda:None, os.environ)
max_file_count = 1000
input_file = sys.argv[1]
enable_redis=os.getenv('ENABLE_REDIS')
redis_host=os.getenv('REDIS_HOST', 'localhost')
redis_port=int(os.getenv('REDIS_PORT', '6379'))

r = redis.StrictRedis(host=redis_host, port=redis_port, db=0)

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
    if not enable_redis:
        return True
    try:
        if r.exists(t_hash):
            r.expire(t_hash, 3600)
            r.incr(t_hash)
            return False
        # Record uncached hash to redis
        r.setex(t_hash, 3600, 1)
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
def check_hash(t_hash):
    if not check_hash_with_redis(t_hash):
        return False
    if not check_hash_with_file(t_hash):
        return False
    return True


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
            now = str(datetime.timestamp(datetime.now()))[:14]
            #print(f"hash: {t_hash}")

            if not check_hash(t_hash):
                f_debug.write(f"{t_hash} {now} f\n")
                f_debug.flush()
                rm_torrent(torrent)
                continue

            # Record new hash to debug file
            f_debug.write(f"{t_hash} {now} p\n")
            f_debug.flush()

            with open(torrent, "rb") as t:
                meta_data = bdecode(t.read())

            meta_data = obj_decode(meta_data)
            meta_data = collections.defaultdict(lambda:None, meta_data)
            meta_info = meta_data['info']

            #keywords = set()
            keywords = [];
            t_node = {
                'name': meta_info['name'],
                'size': sizeof_fmt(meta_info['piece length'] * len(meta_info['pieces']) / 20),
                'length': meta_info['piece length'] * len(meta_info['pieces']) / 20,
                '_id': t_hash,
                'keywords': keywords,
            }

            keywords.append('n:' + meta_info['name'])
            
            if 'files' in meta_info:
                fs = {}
                fset = set()
                fcount = 0
                for i, file in enumerate(meta_info['files']):
                    #print(f"file[{i}].length: {file['length']}")
                    #print(f"file[{i}].path: {'/'.join(file['path'])}")
                    f_path = file['path']
                    f_name = file['path'][-1]
                    f_length = file['length']
                    fs_node = fs
                    for i in range(len(f_path) - 1):
                        dir_name = f_path[i]
                        if not dir_name in fs_node:
                            fs_node[dir_name] = {}
                        if fcount < max_file_count:
                            fcount = fcount + 1
                            keywords.append('d:' + dir_name)
                        fs_node = fs_node[dir_name]
                    if fcount < max_file_count:
                        fcount = fcount + 1
                        keywords.append('f:' + f_name)
                    fs_node[f_name] = f_length
                if fcount == max_file_count:
                    keywords.append('skip:' + str(len(meta_info['files']) - max_file_count))
                t_node['multifile'] = True
                t_node['files'] = fs
            else:
                t_node['multifile'] = False
                t_node['ext'] = meta_info['name'].split('.')[-1].lower()

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

