#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The Django project in this workspace.')
parser.add_argument('-r', '--run',
                    default="_none_",
                    help='A manage.py command to run in the site, with its arguments. Example: --run "showmigrations polls"')
parser.add_argument('-u', '--update',
                    action='store_true',
                    default=False,
                    help='Update Django to the latest release of its line, migrate, and restart the server.')
parser.add_argument('--restart',
                    action='store_true',
                    default=False,
                    help='Start the server again, and wait for it.')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='Add the default accounts. An account that is already there gets its password, address, staff status and group back.')
parser.add_argument('-c', '--cancel-users',
                    action='store_true',
                    default=False,
                    help='Delete the default accounts (never the workspace account).')
ARGEOF
