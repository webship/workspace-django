#!/usr/bin/env bash

# Installed by the Django plugin (plugins.sh --install django); __WORKSPACE__ is the workspace it was installed into.
#
# manage.py of one Django site of this workspace, with the site's Python, in its container: say what
# the site is, run a command, update Django within its release line, restart the server, add or
# cancel the default accounts. Nothing here runs on the host.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Distribution.
distribution_name="django";

ARGPARSE_DESCRIPTION="Run manage.py of a Django site of __WORKSPACE__: status, a command, an update, a restart, the default accounts"
# The args file comes with the plugin: core/scripts/plugins/django/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/django/args/arg-django-manage.sh || exit 1 ;

shift $#;

django_manage_tool ;
