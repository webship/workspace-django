#!/usr/bin/env bash

# workspace-name: Django (startproject, polls)

# Installed by the Django plugin (plugins.sh --install django); __WORKSPACE__ is the workspace it was installed into.
#
# Build a Django site in a container: a plain project made with django-admin startproject, at the
# current stable line or the one --django-version names, with the polls app of the official tutorial
# on request, at https://<name>.ddev.site. With --install the workspace account becomes its
# superuser; with --add-users it also gets the default accounts.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Distribution.
distribution_name="django";
distribution_title="Django";
distribution_webroot="";

ARGPARSE_DESCRIPTION="Build a ${distribution_title} project in __WORKSPACE__"
# The args file comes with the plugin: core/scripts/plugins/django/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/django/args/arg-django.sh || exit 1 ;

shift $#;

django_build ;
