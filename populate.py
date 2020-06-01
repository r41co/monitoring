#!/usr/bin/env python

import json

if __name__ == '__main__':
    try:
        cfg = json.load(open('config.json'))
    except Exception as e:
        print(e)

    if 'nodes' in cfg:
        for node in cfg['nodes']:
            labels = cfg['nodes'][node]['labels']  + [ node, 'all' ]
            output = open('jobs/%s' % node, 'w')
            for label in labels:
                if label in cfg['jobs']:
                    for job in cfg['jobs'][label]:
                        output.write(job['url'] + "\n")
            output.close()
