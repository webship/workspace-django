#!/usr/bin/env bash

# Django for the Webship Workspace: build a site, run manage.py on it, add its default accounts,
# and wire its step pack into the testing setup.
#
# Placed by `plugins.sh --install django` in core/scripts/plugins/django/functions/, where bootstrap
# sources it after the core's own functions. Everything runs in the project's container (DDEV by
# default), never on the host: the web image gets uv and the Python the site runs on, the site
# lives in a virtual environment of the project, the web container runs the Django server as a
# daemon, the router serves it at the project's address, and PostgreSQL is the container tool's
# database.
#
# Django is not a PHP platform and DDEV has no project type for it, so a Django project is
# recognised by a file (.ddev/config.django.yaml, written by the builder), and four names are the
# ones the core's tools look for:
#   set_django_users          the default accounts                (cmd-tools-add-users.sh <project> django)
#   add_django_users          create them in the site's database  (the same tool, and --add-users of the builder)
#   cancel_django_users       delete them                         (cmd-tools-cancel-users.sh <project> django)
#   testing_configure_django  the step pack in the testing stack  (cmd-tools-testing.sh <project>)

# The step pack a Django project is tested with, and the release line it is required at.
readonly DJANGO_STEPS_PACKAGE='@webship-js/django-steps';
readonly DJANGO_STEPS_VERSION='^2.0.0';

# Where the site lives in the web container: the virtual environment, the project that
# django-admin startproject makes, and the port the server listens on.
readonly DJANGO_ROOT='/var/www/html';
readonly DJANGO_SITE='mysite';
readonly DJANGO_PORT='8000';

# The release line the builder installs when --django-version is not given (the current stable
# line), the Python of the site, and the uv release that installs it in the web image.
readonly DJANGO_DEFAULT_LINE='6.1';
readonly DJANGO_PYTHON='3.13';
readonly DJANGO_UV_VERSION='0.13.7';

# The default accounts, the ones a scenario logs in as: a superuser, an editor (staff, in the
# group Editors: adds, changes, deletes and views the objects of the project's own apps) and a
# viewer (staff, in the group Viewers: views them). Accounts are configuration, created once on the
# site; a test suite never creates or deletes one. The superuser the builder creates with
# --install is the workspace account and is not in this list.
function set_django_users() {
  users=(administrator editor viewer);
  local user ;
  for user in "${users[@]}" ; do
    printf -v "user_${user}_name" '%s' "${user}" ;
    printf -v "user_${user}_mail" '%s' "${user}@example.com" ;
    printf -v "user_${user}_password" '%s' 'dD.123123ddd' ;
  done
  user_administrator_role='superuser' ;
  user_editor_role='editor' ;
  user_viewer_role='viewer' ;
}

# Is this folder a Django project of this plugin? The builder leaves .ddev/config.django.yaml in it.
function django_is_project() {
  local project_path="$1";
  [ -f "${project_path}/.ddev/config.django.yaml" ] && return 0 ;
  # On another runtime the plugin's claim, in the x-webship block (the core's rt_is_platform reads it).
  declare -f rt_is_platform > /dev/null && rt_is_platform "${project_path}" django ;
}

# The runtime of the project in this folder, or of a new build (--runtime, else the workspace's
# setting, else DDEV). A core without the runtime layer has DDEV only.
function django_runtime() {
  if declare -f runtime_of > /dev/null ; then runtime_of ; else echo 'ddev' ; fi
}

# The address of the site in this folder: https://<name>.ddev.site on DDEV, the runtime's own elsewhere
# (http://127.0.0.1:<port> on Docker Compose and Podman, the node's address and a port on Kubernetes).
function django_url() {
  if declare -f rt_url > /dev/null ; then rt_url ; else echo "https://${PROJECT_NAME}.ddev.site" ; fi
}

# On another runtime than DDEV (webship/workspace#841): the plugin's claim, Python at the site's version as the stack's
# own image, uv added to it (as on DDEV), and the Django server as the web container's own, once the build has made the
# site (.ready): the same server as DDEV's daemon, from the project's folder, on DJANGO_PORT. It starts once the
# database takes connections: on Kubernetes the web pod can start before the cluster's DNS and the database do (a
# cluster started again), and a server that cannot reach the database as it starts waits for a file to change.
function django_runtime_config() {
  local python="$1" ;
  rt_claim django || return 1 ;
  rt_stack python "${python}" || return 1 ;
  rt_web_build uv <<DOCKEREOF || return 1
# uv (${DJANGO_UV_VERSION}), as on DDEV: the builder makes the site's virtual environment with it.
ENV UV_LINK_MODE=copy
RUN arch="\$(uname -m)" \\
    && curl -sSfL "https://github.com/astral-sh/uv/releases/download/${DJANGO_UV_VERSION}/uv-\${arch}-unknown-linux-gnu.tar.gz" \\
       | tar -xz --strip-components=1 -C /usr/local/bin
DOCKEREOF
  rt_serve "${DJANGO_PORT}" "while [ ! -f ${DJANGO_SITE}/.ready ] ; do sleep 2 ; done ; until pg_isready -q -h db -U db ; do sleep 2 ; done ; cd ${DJANGO_SITE} && exec ../.venv/bin/python manage.py runserver --insecure 0.0.0.0:${DJANGO_PORT}" ;
}

# Go to the project a tool was asked about, or say why not.
function django_enter_project() {
  local project_path="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}";
  if [ ! -d "${project_path}" ] ; then
    echo "No project ${PROJECT_NAME} in ${WORKSPACE_ROOT}/${doc_name}." ;
    return 1 ;
  fi
  if ! django_is_project "${project_path}" ; then
    echo "${doc_name}/${PROJECT_NAME} is not a Django project of this plugin (it has no .ddev/config.django.yaml)." ;
    return 1 ;
  fi
  cd "${project_path}" || return 1 ;
}

# What the container tool is told about the site: the router sends the project's address to the
# Django server's port, the server runs as a daemon of the web container once the build has
# finished, and the web image gets uv and the Python of the site.
function django_write_ddev_config() {
  local project_path="$1" python="$2";
  mkdir -p "${project_path}/.ddev/web-build" || return 1 ;
  cat > "${project_path}/.ddev/config.django.yaml" <<YAMLEOF
# Django in this project. Written by the Django builder of the workspace; build again rather than
# editing by hand. The web container serves no files of its own: the router sends ports 80 and 443
# of the project's address to the Django server, which the web container runs as a daemon.
web_extra_exposed_ports:
  - name: django
    container_port: ${DJANGO_PORT}
    http_port: 80
    https_port: 443
web_extra_daemons:
  - name: django
    command: "bash -c 'while [ ! -f ${DJANGO_ROOT}/${DJANGO_SITE}/.ready ]; do sleep 2; done; cd ${DJANGO_ROOT}/${DJANGO_SITE} && exec ${DJANGO_ROOT}/.venv/bin/python manage.py runserver --insecure 0.0.0.0:${DJANGO_PORT}'"
    directory: ${DJANGO_ROOT}
web_environment:
  - PYTHONUNBUFFERED=1
YAMLEOF
  cat > "${project_path}/.ddev/web-build/Dockerfile.django" <<DOCKEREOF
# Python for the Django site, in the web image: uv (${DJANGO_UV_VERSION}), and the Python the site runs on,
# installed by uv. Written by the Django builder of the workspace. The image's own Python is too old
# for the current Django line on some releases of the container tool.
ENV UV_PYTHON_INSTALL_DIR=/opt/python
# The packages are copied into the project's virtual environment (the cache is on another file system).
ENV UV_LINK_MODE=copy
RUN arch="\$(uname -m)" \\
    && curl -sSfL "https://github.com/astral-sh/uv/releases/download/${DJANGO_UV_VERSION}/uv-\${arch}-unknown-linux-gnu.tar.gz" \\
       | tar -xz --strip-components=1 -C /usr/local/bin \\
    && uv python install ${python} \\
    && chmod -R a+rX /opt/python
DOCKEREOF
}

# manage.py in the container, with the Python of the site's virtual environment.
function django_manage() {
  ddev exec -d "${DJANGO_ROOT}/${DJANGO_SITE}" "${DJANGO_ROOT}/.venv/bin/python manage.py $*" < /dev/null ;
}

# The release of Django the site runs.
function django_version() {
  ddev exec "${DJANGO_ROOT}/.venv/bin/python -c 'import django; print(django.get_version())'" < /dev/null 2>/dev/null | tr -d '\r' ;
}

# The pip requirement for a --django-version: a release line ("6.1": its latest release) or one
# release ("6.1.3"). Empty means the default line.
function django_requirement() {
  local version="${1:-${DJANGO_DEFAULT_LINE}}" ;
  if [[ "${version}" =~ ^[0-9]+\.[0-9]+$ ]] ; then
    echo "Django~=${version}.0" ;
  elif [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ; then
    echo "Django==${version}" ;
  else
    return 1 ;
  fi
}

# Wait until the Django server answers on its own port.
function django_wait() {
  local attempt code ;
  for attempt in $(seq 1 60) ; do
    code="$(ddev exec "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:${DJANGO_PORT}/admin/login/" < /dev/null 2>/dev/null | tr -d '\r')" ;
    case "${code}" in
      200|301|302) return 0 ;;
    esac
    sleep 2 ;
  done
  echo "The Django server did not start; the end of its log:" ;
  if [ "$(django_runtime)" == 'ddev' ] ; then ddev exec "supervisorctl tail webextradaemons:django stderr" < /dev/null 2>/dev/null ;
  else ddev logs 2>/dev/null | tail -20 ; fi
  return 1 ;
}

# Start the Django server again (the daemon of the web container), and wait for it.
function django_restart() {
  if [ "$(django_runtime)" == 'ddev' ] ; then
    ddev exec "supervisorctl restart webextradaemons:django" < /dev/null || return 1 ;
  else
    # The server is the web container's own (rt_serve): the container starts again with it.
    ddev restart < /dev/null > /dev/null || return 1 ;
  fi
  django_wait ;
}

# Run a verb of django-site.py (settings, polls, seed, accounts <verb>) with the site's Python, in
# the folder of manage.py. The script is piped to the Python of the site, and the accounts travel
# as base64 of a JSON object, so no password is written into a file of the project and no quoting
# can break a value.
function django_site() {
  local script="${WORKSPACE_SCRIPTS}/plugins/django/django-site.py" rows="" user name mail password role payload ;
  if [ ! -f "${script}" ] ; then
    echo "django-site.py is not in ${WORKSPACE_SCRIPTS}/plugins/django: install the plugin (plugins.sh --install django)." ;
    return 1 ;
  fi
  for user in "${users[@]}" ; do
    name="user_${user}_name"; mail="user_${user}_mail"; password="user_${user}_password"; role="user_${user}_role";
    rows="${rows}${!name}"$'\x1f'"${!mail}"$'\x1f'"${!password}"$'\x1f'"${!role}"$'\x1e' ;
  done
  payload="$(DJANGO_OWNER_NAME="${account_name}" DJANGO_OWNER_MAIL="${account_mail}" DJANGO_OWNER_PASS="${account_pass}" \
    DJANGO_ROWS="${rows}" python3 -c '
import base64, json, os
accounts = [dict(zip(("name", "email", "password", "role"), row.split("\x1f"))) for row in os.environ["DJANGO_ROWS"].split("\x1e") if row]
print(base64.b64encode(json.dumps({
    "owner": {"name": os.environ["DJANGO_OWNER_NAME"], "email": os.environ["DJANGO_OWNER_MAIL"], "password": os.environ["DJANGO_OWNER_PASS"]},
    "accounts": accounts,
}).encode()).decode())')" || return 1 ;
  ddev exec -d "${DJANGO_ROOT}/${DJANGO_SITE}" "DJANGO_SITE_ACCOUNTS=${payload} ${DJANGO_ROOT}/.venv/bin/python - $*" < "${script}" ;
}

# Build a Django site from nothing: the container, the packages, the project, the database, with
# --polls the tutorial's app, and with --install its superuser.
function django_build() {
  trim_project_name ;
  local base_url runtime ;
  runtime="$(django_runtime)" ;
  if [ "${RUNTIME:-_none_}" != '_none_' ] && [ "${RUNTIME}" != "${runtime}" ] ; then
    echo "--runtime ${RUNTIME} needs a Webship Workspace with the container runtimes (webship/workspace#694): update the workspace, or build on DDEV." ;
    exit 1 ;
  fi
  if [ "${runtime}" != 'ddev' ] && ! declare -f rt_serve > /dev/null ; then
    echo "Django on ${runtime} needs a Webship Workspace whose runtimes take an application's own language and server (webship/workspace#841, core 1.0.32 or later): update the workspace, or build on DDEV." ;
    exit 1 ;
  fi
  case "${runtime}" in lando|docksal)
    echo "Django on ${runtime} waits for the language stacks there (webship/workspace#841, its next step): build on DDEV, Docker Compose, Podman or Kubernetes." ;
    exit 1 ;;
  esac
  local version="${DJANGO_VERSION:-${site_django_version:-${DJANGO_DEFAULT_LINE}}}" ;
  local python="${PYTHON_VERSION:-${site_python_version:-${DJANGO_PYTHON}}}" ;
  local project_path="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}" ;
  local requirement ;

  if ! requirement="$(django_requirement "${version}")" ; then
    echo "--django-version takes a release line (6.1, 5.2) or one release (6.1.3), not ${version}. Nothing was changed." ;
    exit 1 ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name} || exit 1 ;

  drop_database ;
  rm -rf "${PROJECT_NAME}" ;
  mkdir -p "${PROJECT_NAME}" ;
  cd "${project_path}" || exit 1 ;

  # A generic web server: no nginx and no PHP are started. The database is PostgreSQL.
  ddev config --project-type=generic --webserver-type=generic --docroot="" --project-name=${PROJECT_NAME} \
    --database=postgres:16 --nodejs-version=$(ddev_nodejs_version) || exit 1 ;
  if [ "${runtime}" == 'ddev' ] ; then
    django_write_ddev_config "${project_path}" "${python}" || exit 1 ;
  else
    django_runtime_config "${python}" || { echo "The site's stack could not be written through the runtime layer." ; exit 1 ; } ;
  fi
  # The address is the runtime's to say, once the project is configured: never a written ddev.site.
  base_url="$(django_url)" ;
  ddev_up start -y || exit 1 ;

  echo "Installing ${requirement} on Python ${python} in a virtual environment." ;
  ddev exec "uv venv --clear --seed --python ${python} ${DJANGO_ROOT}/.venv && uv pip install --python ${DJANGO_ROOT}/.venv/bin/python '${requirement}' 'psycopg[binary]'" < /dev/null \
    || { echo "The install of Django failed." ; exit 1 ; } ;

  # A plain project, as the tutorial makes it, and the settings of the container.
  ddev exec "rm -rf ${DJANGO_ROOT}/${DJANGO_SITE} && ${DJANGO_ROOT}/.venv/bin/django-admin startproject ${DJANGO_SITE}" < /dev/null \
    || { echo "django-admin startproject failed." ; exit 1 ; } ;
  users=() ;
  django_site settings || exit 1 ;
  if [ "${POLLS}" == 'yes' ] ; then
    django_site polls || exit 1 ;
    django_manage makemigrations polls || { echo "manage.py makemigrations failed." ; exit 1 ; } ;
  fi
  django_manage migrate --noinput || { echo "manage.py migrate failed." ; exit 1 ; } ;
  if [ "${POLLS}" == 'yes' ] ; then
    django_site seed || exit 1 ;
  fi

  touch "${project_path}/${DJANGO_SITE}/.ready" ;
  echo "Starting the Django server." ;
  django_restart || exit 1 ;

  if [ "${INSTALL}" == 'yes' ] ; then
    users=() ;
    django_site accounts owner || { echo "The superuser could not be created." ; exit 1 ; } ;

    if [ "${ADD_USERS}" == 'yes' ] ; then
      set_django_users ;
      add_django_users ;
      cd "${project_path}" || exit 1 ;
    fi

    echo "${doc_name} ${PROJECT_NAME} has been installed: Django $(django_version).";
    echo "Go to ${base_url}/admin/ and log in as ${account_name}";
  else
    [ "${ADD_USERS}" == 'yes' ] && echo "--add-users needs --install: the site has no superuser yet." ;
    echo "${doc_name} ${PROJECT_NAME} is ready, without a superuser: Django $(django_version).";
    echo "Give it one with: bash cmd-tools-django-manage.sh ${PROJECT_NAME} --run createsuperuser   (or build with --install)";
    echo "Go to ${base_url}/admin/";
  fi

  if [ "${LAUNCH}" == 'yes' ] ; then
    ddev launch /admin/ ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name};
}

# Create the default accounts in the site's database. An account that is already there gets its
# password, address, staff status and group back. The list is loaded by the caller
# (set_django_users): the core's add_users, the builder, the manage.py tool.
function add_django_users() {
  django_enter_project || return 1 ;
  local user user_name user_mail user_password user_role ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail";
    user_password="user_${user}_password"; user_role="user_${user}_role";

    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo "      User mail: ${!user_mail}";
    echo "  User password: ${!user_password}";
    echo "      User role: ${!user_role}";
    echo " ================================================================= ";
  done
  django_site accounts add ;
  local status=$? ;
  cd ${WORKSPACE_ROOT}/${doc_name};
  return ${status} ;
}

# Delete the default accounts (never the workspace account). The admin's history of their actions
# goes with them.
function cancel_django_users() {
  django_enter_project || return 1 ;
  local user user_name ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name";
    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo " ================================================================= ";
  done
  django_site accounts cancel ;
  local status=$? ;
  cd ${WORKSPACE_ROOT}/${doc_name};
  return ${status} ;
}

# What cmd-tools-django-manage.sh does: the first of --run, --update, --restart, --add-users,
# --cancel-users that was asked for; with none of them, what the site is.
function django_manage_tool() {
  trim_project_name ;
  django_enter_project || exit 1 ;

  if ! ddev describe -j 2>/dev/null | grep -q '"status":"running"' ; then
    ddev start -y || exit 1 ;
  fi

  if [ ! "${RUN}" == '_none_' ] ; then
    # Unquoted on purpose: --run "showmigrations polls" is a command and its arguments.
    django_manage ${RUN} ;
    exit $? ;
  fi

  if [ "${UPDATE}" == 'yes' ] ; then
    local installed line ;
    installed="$(django_version)" ; line="$(echo "${installed}" | cut -d. -f1,2)" ;
    echo "Django ${installed} is installed." ;
    ddev exec "uv pip install --python ${DJANGO_ROOT}/.venv/bin/python --upgrade 'Django~=${line}.0'" < /dev/null || exit 1 ;
    django_manage migrate --noinput || exit 1 ;
    django_restart || exit 1 ;
    echo "Django $(django_version) is running." ;
  elif [ "${RESTART}" == 'yes' ] ; then
    django_restart || exit 1 ;
    echo "Django $(django_version) is running." ;
  elif [ "${ADD_USERS}" == 'yes' ] ; then
    set_django_users ;
    add_django_users ;
  elif [ "${CANCEL_USERS}" == 'yes' ] ; then
    set_django_users ;
    cancel_django_users ;
  else
    echo "${doc_name}/${PROJECT_NAME}: Django $(django_version) at $(django_url)/admin/" ;
    echo "" ; echo "Packages:" ;
    ddev exec "uv pip list --python ${DJANGO_ROOT}/.venv/bin/python 2>/dev/null | grep -i -E '^(django|psycopg)' | sed 's/^/   /'" < /dev/null ;
    echo "" ; echo "Apps:" ;
    django_manage shell -v 0 -c "\"from django.apps import apps; print('   ' + ', '.join(a.label for a in apps.get_app_configs()))\"" ;
    echo "" ; echo "Accounts:" ;
    users=() ;
    django_site accounts list ;
  fi
  cd ${WORKSPACE_ROOT}/${doc_name};
}

# The step pack in the testing stack of a Django project. The core's testing_configure calls this
# in the project folder once webship-js is scaffolded and before the dependencies are installed;
# for a project that is not one of this plugin's it changes nothing.
#
# It adds the pack to package.json, lists its step definitions in cucumber.js after webship-js's
# own, gives cucumber.js the tags that keep the pack's assertions that must fail out of a normal
# run, the path of the admin, the handle the test-object steps work as (dataAdmin), the browser
# messages that are no error of the site, and the users registry of the default accounts (a handle
# a scenario reads, mapped to an account; never the workspace account), and writes a first feature
# when the project has none of its own. Every part is skipped when it is already there, so a second
# run adds what the first missed and never resets a suite.
function testing_configure_django() {
  local project_path="$1";
  django_is_project "${project_path}" || return 0 ;
  if [ ! -f "${project_path}/cucumber.js" ] || [ ! -f "${project_path}/package.json" ] ; then
    echo "  Django: cucumber.js is not here yet — run the testing setup again once webship-js is scaffolded." ;
    return 1 ;
  fi

  echo "Adding the Django admin step pack (${DJANGO_STEPS_PACKAGE} ${DJANGO_STEPS_VERSION}).";
  set_django_users ;
  local registry="" user user_name user_mail user_password ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail"; user_password="user_${user}_password";
    registry="${registry}${user}|${!user_mail}|${!user_password}|${!user_name}"$'\n' ;
  done

  python3 - "${project_path}" "${DJANGO_STEPS_PACKAGE}" "${DJANGO_STEPS_VERSION}" 'DJANGO' "${registry}" <<'PYEOF' || return 1
import json, re, sys

project, pack, version, prefix, registry = sys.argv[1:6]

# package.json: the pack as a dev dependency, at the release line this plugin was proven on.
pkg_file = project + '/package.json'
pkg = json.load(open(pkg_file))
if pack not in pkg.get('dependencies', {}) and pack not in pkg.get('devDependencies', {}):
    pkg.setdefault('devDependencies', {})[pack] = version
    open(pkg_file, 'w').write(json.dumps(pkg, indent=4) + '\n')
    print('  package.json: %s %s' % (pack, version))

# cucumber.js: the pack's step definitions after webship-js's own, the tags of the pack's lane, and
# in worldParameters the admin's path, the test-object account, the browser messages to ignore and
# the users registry.
cucumber_file = project + '/cucumber.js'
src = open(cucumber_file).read()
before = src

if ('node_modules/%s/' % pack) not in src:
    line = "'node_modules/%s/tests/step-definitions/**/*.js'," % pack
    core = re.search(r"^([ \t]*)'node_modules/webship-js/tests/step-definitions/[^']*',.*$", src, re.M)
    opening = re.search(r"^([ \t]*)require:[ \t]*\[[ \t]*$", src, re.M)
    if core:
        src = src[:core.end()] + '\n' + core.group(1) + line + src[core.end():]
    elif opening:
        src = src[:opening.end()] + '\n' + opening.group(1) + '  ' + line + src[opening.end():]
    else:
        sys.exit("  cucumber.js has no require list this can add to. Add this line to it:\n    " + line)
    print('  cucumber.js: the step definitions of %s' % pack)

if not re.search(r"^[ \t]*tags:", src, re.M):
    default = re.search(r"^([ \t]*)default:[ \t]*\{[ \t]*$", src, re.M)
    if default:
        pad = default.group(1) + '  '
        block = [
            pad + "// The pack's assertions that must fail are no part of a normal run.",
            pad + "tags: process.env.CUCUMBER_TAGS || 'not @wip and not @must-fail',",
        ]
        src = src[:default.end()] + '\n' + '\n'.join(block) + src[default.end():]
        print('  cucumber.js: the tags that keep the assertions that must fail out of a normal run')

world = re.search(r"^([ \t]*)worldParameters:[ \t]*\{[ \t]*$", src, re.M)
if not world:
    sys.exit("  cucumber.js has no worldParameters block to add the users registry to.")
pad = world.group(1) + '  '
additions = []
if not re.search(r"^[ \t]*adminPath:", src, re.M):
    additions += [
        pad + "// Where the admin is on the site ('/admin/' as startproject sets it).",
        pad + "adminPath: process.env.ADMIN_PATH || '/admin/',",
    ]
if not re.search(r"^[ \t]*dataAdmin:", src, re.M):
    additions += [
        pad + "// The account the test-object steps make and delete the test objects as: a superuser of `users`.",
        pad + "dataAdmin: process.env.DATA_ADMIN || 'administrator',",
    ]
if not re.search(r"^[ \t]*javascript:", src, re.M):
    additions += [
        pad + "// Browser messages that are no error of the site: the 5.2 admin's unload listener, and a request lost",
        pad + "// when the network of the machine changed.",
        pad + "javascript: { mode: process.env.WEBSHIP_JS_ERROR_MODE || 'warn', levels: ['error'], ignore: 'Permissions policy violation: unload is not allowed|net::ERR_NETWORK_CHANGED', beforeScenario: false, afterScenario: true },",
    ]
if not re.search(r"^[ \t]*users:[ \t]*\{", src, re.M):
    rows = [r.split('|') for r in registry.splitlines() if r.strip()]
    additions += [
        pad + "// The users registry: a handle a scenario reads, mapped to an account of this site (the default",
        pad + "// accounts: cmd-tools-django-manage.sh --add-users). Override one with %s_<HANDLE>_USERNAME," % prefix,
        pad + "// %s_<HANDLE>_PASSWORD and %s_<HANDLE>_EMAIL." % (prefix, prefix),
        pad + "users: {",
    ]
    for handle, email, password, name in rows:
        env = '%s_%s' % (prefix, handle.upper())
        additions.append(pad + "  %s: { username: process.env.%s_USERNAME || '%s', password: process.env.%s_PASSWORD || '%s', email: process.env.%s_EMAIL || '%s' }," % (handle, env, name, env, password, env, email))
    additions.append(pad + "},")
    print('  cucumber.js: the users registry (%s)' % ', '.join(r[0] for r in rows))
if additions:
    src = src[:world.end()] + '\n' + '\n'.join(additions) + src[world.end():]

if src != before:
    open(cucumber_file, 'w').write(src)
PYEOF

  # A first feature, when the project has none for the site yet: the login page, each default
  # account, a refused login, the accounts the administrator sees and the editor is refused.
  local feature="${WORKSPACE_SCRIPTS}/plugins/django/site.feature" ;
  if [ -f "${feature}" ] && [ ! -f "${project_path}/tests/features/site.feature" ] ; then
    mkdir -p "${project_path}/tests/features" && cp "${feature}" "${project_path}/tests/features/site.feature" \
      && echo "  tests/features/site.feature: a first feature for the site" ;
  fi

  # The scenarios log in as the default accounts: make sure a site that has its superuser has them.
  if ( cd "${project_path}" && users=() && django_site accounts installed ) > /dev/null 2>&1 ; then
    if ( add_django_users > /dev/null 2>&1 ) ; then
      echo "  the default accounts are on the site (${users[*]})" ;
    else
      echo "  The default accounts could not be written: is the site running (ddev start in ${project_path})?" ;
    fi
  else
    echo "  The site has no superuser yet: the scenarios that log in need a site built with --install." ;
  fi
}
