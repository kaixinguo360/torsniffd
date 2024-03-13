#!/usr/bin/env python3
# coding=utf-8
 
import os
import sys
import datetime
import redis

input_file = sys.argv[1]
redis_host=os.getenv('REDIS_HOST', 'localhost')
redis_port=int(os.getenv('REDIS_PORT', '6379'))

r = redis.StrictRedis(host=redis_host, port=redis_port, db=0)
now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:23]
c_all = 0
c_idt = 0
c_dup = 0

for line in open(input_file):
    if c_all % 1000 == 0:
        print(f"all {c_all}, idt {c_idt}, dup {c_dup}")
    c_all = c_all + 1
    t_hash = line.strip()
    if t_hash == '':
        continue
    if r.exists(t_hash):
        r.expire(t_hash, 36000)
        r.incr(t_hash)
        c_dup = c_dup + 1
        continue
    r.setex(t_hash, 36000, 1)
    c_idt = c_idt + 1

