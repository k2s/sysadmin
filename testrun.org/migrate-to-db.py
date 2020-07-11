#!/usr/bin/env python3

import sqlite3


conn = sqlite3.connect("/var/lib/mailadm2/mailadm.db")
cur = conn.cursor()



postfxdct = dict()

with open("/home/mailadm/postfix-users", "r") as postfile:
    postcontent = postfile.read()
    postlines = postcontent.splitlines()
    for line in postlines:
        words = line.split()
        postfxdct[words[0]] = [words[0], words[1], words[2], words[3]]

with open("/home/mailadm/userdb", "r") as userdbfile:
    userdbcontent = userdbfile.read()
    userlines = userdbcontent.splitlines()
    for line in userlines:
        words = line.split()
        if words[0] not in postfxdct:
            postfxdct[words[0]] = [words[0], words[1], words[2], words[3]]

with open("/home/mailadm/dovecot-users", "r") as dovefile:
    dovecontent = dovefile.read()
    dovelines = dovecontent.splitlines()

for line in dovelines:
    dovelist = line.split(":")
    addr = dovelist[0]
    try:
        hashpw = dovelist[1]
    except IndexError:
        continue
    homedir = "/home/vmail/testrun.org/" + addr
    if addr not in postfxdct:
        print("Only a dovecot user: " + addr)
        continue
    date = int(float(postfxdct[addr][1]))
    if postfxdct[addr][2] == "1d":
        ttl = 86400
        token_name = "oneday"
    elif postfxdct[addr][2] == "1w":
        ttl = 86400 * 7
        token_name = "oneweek"
    elif postfxdct[addr][2] == "52w":
        ttl = 86400 * 7 * 52
        token_name = "oneyear"
    elif postfxdct[addr][2] == "3650d":
        ttl = 86400 * 3650
        token_name = "tenyears"
    else:
        print("unrecognized token: " + postfxdct[addr][2])

    query = "INSERT INTO users (addr, hash_pw, homedir, date, ttl, token_name) VALUES ('%s','%s','%s',%s,%s,'%s');" \
        % (addr, hashpw, homedir, date, ttl, token_name)
    print(query)
    cur.execute(query)
execute = input("Write to database? [Y/n] ")
if execute == "n" or execute == "N":
    print("aborted.")
    exit(0)
conn.commit()
