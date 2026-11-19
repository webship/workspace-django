#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The name of the project: its folder, its DDEV project and its host name.')
parser.add_argument('-i', '--install',
                    action='store_true',
                    default=False,
                    help='Give the site its superuser: the workspace account.')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='With --install, add the default accounts (administrator, editor, viewer): the ones the test scenarios log in as.')
parser.add_argument('-p', '--polls',
                    action='store_true',
                    default=False,
                    help='Add the polls app of the official tutorial, registered in the admin with the features most projects use, and its sample data.')
parser.add_argument('-d', '--django-version',
                    default="",
                    help='A release line (6.1, 5.2) or one release (6.1.3); empty means the current stable line, 6.1. Example: --django-version 5.2')
parser.add_argument('--python-version',
                    default="",
                    choices=['3.14', '3.13', '3.12'],
                    help='The Python of the site, installed in the web image; empty means 3.13. Example: --python-version 3.12')
parser.add_argument('-l', '--launch',
                    action='store_true',
                    default=False,
                    help='Open the site in a browser when it is ready.')
ARGEOF
