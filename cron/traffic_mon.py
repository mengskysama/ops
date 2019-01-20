#!/usr/bin/python3

# Add cron
# PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games
# */1 * * * * /usr/bin/python3 /opt/ops/traffic_mon.py


import re
import json
import datetime
import subprocess
import logging

sh = logging.StreamHandler()
logger = logging.getLogger('')
logger.addHandler(sh)
logger.setLevel(logging.INFO)

LOG_FILE = '/var/log/traffic_mon.log'
IF_NAME = 'eth0'
MAX_TX_TRANSFER_PER_MON = 900 * 1024 * 1024 * 1024


def get_ifconfig_info():
    p = subprocess.Popen('ifconfig', stdout=subprocess.PIPE, shell=True)
    if_config_output = p.stdout.read().decode('utf-8')
    p.stdout.close()

    ifs = {}
    for paragraph in if_config_output.split('\n\n'):
        ma = re.compile("^(\S+).*?inet addr:(\S+).*?Mask:(\S+).*?RX bytes:(\d+).*?TX bytes:(\d+)", re.MULTILINE|re.DOTALL)
        result = ma.match(paragraph)
        if result:
            ifs[result.group(1)] = {
                'IP': result.group(2),
                'MAC': result.group(3),
                'RX': int(result.group(4)),
                'TX': int(result.group(5)),
            }
    return ifs


def write_log(data):
    with open(LOG_FILE, 'w') as f:
        f.write(json.dumps(data))


def read_log():
    try:
        with open(LOG_FILE, 'r') as f:
            return json.loads(f.read())
    except FileNotFoundError:
        return None


def do_out_of_transfer():
    p = subprocess.Popen('iptables -L', stdout=subprocess.PIPE, shell=True)
    ret = p.stdout.readlines()
    p.stdout.close()
    ret = list(filter(lambda x: 'limitrxtx' not in x, ret))
    if ret:
        logger.info('already limit ...')
        return

    subprocess.call('iptables -A OUTPUT -m limit --limit 150/s -j ACCEPT  -m comment --comment limitrxtx', shell=True)
    subprocess.call('iptables -A OUTPUT -j DROP -m comment --comment limitrxtx', shell=True)
    subprocess.call('iptables -A FORWARD -m limit --limit 150/s -j ACCEPT  -m comment --comment limitrxtx', shell=True)
    subprocess.call('iptables -A FORWARD -j DROP -m comment --comment limitrxtx', shell=True)


def undo_out_of_transfer():
    logger.debug('undo_out_of_transfer begin ...')
    subprocess.call('iptables -D OUTPUT -j DROP -m comment --comment limitrxtx', shell=True)
    subprocess.call('iptables -D OUTPUT -m limit --limit 150/s -j ACCEPT  -m comment --comment limitrxtx', shell=True)
    subprocess.call('iptables -D FORWARD -j DROP -m comment --comment limitrxtx', shell=True)
    subprocess.call('iptables -D FORWARD -m limit --limit 150/s -j ACCEPT  -m comment --comment limitrxtx', shell=True)


def mon():
    log = read_log()
    info = get_ifconfig_info()

    m = datetime.datetime.now().month
    if not log or log['month'] != m:
        log = {IF_NAME: info[IF_NAME], 'month': datetime.datetime.now().month, 'monthly_traffic': 0}
        write_log(log)
        undo_out_of_transfer()
        return

    n = info[IF_NAME]['TX'] - log[IF_NAME]['TX']
    if n < 0:
        logger.warn('interface restart?')
        log[IF_NAME] = info[IF_NAME]
        write_log(log)
        return

    log['monthly_traffic'] += n
    write_log(log)
    logger.info('Monthly traffic: %s Gi' % str(log['monthly_traffic'] / 1024 / 1024 / 1024))

    if log['monthly_traffic'] > MAX_TX_TRANSFER_PER_MON:
        logger.warn('Traffic out of limit.')
        do_out_of_transfer()


if __name__ == '__main__':
    mon()
