import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { spawnSync } from 'child_process';

// Compiled, these tests run from dist/tests, so the package root is one folder further up.
const PKG = fs.existsSync(path.join(__dirname, '..', 'package.json')) ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
const FUNCTIONS = path.join(PKG, 'scripts', 'functions', 'fun-django.sh');

// The cucumber.js webship-js scaffolds, as far as the testing hook reads it.
const SCAFFOLD = `module.exports = {
  default: {
    requireModule: ['tsx/cjs'],
    require: [
      'node_modules/webship-js/tests/step-definitions/**/*.js',          // Webship-js core step definitions.
      'tests/step-definitions/**/*.js',                                  // Your custom step definitions.
    ],
    paths: ['tests/features/**/*.feature'],
    worldParameters: {
      launchUrl: process.env.LAUNCH_URL || 'http://localhost:8080',
    },
  },
};
`;

/**
 * A project folder with the testing stack scaffolded, and the tooling folder the installer would have filled.
 * A Django project of this plugin has the builder's .ddev/config.django.yaml.
 */
function project(kind: 'django' | 'drupal') {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'django-plugin-'));
  const dir = path.join(root, 'dev', 'site1');
  fs.mkdirSync(path.join(dir, '.ddev'), { recursive: true });
  fs.writeFileSync(path.join(dir, '.ddev', 'config.yaml'), `name: site1\ntype: ${kind === 'django' ? 'generic' : 'drupal11'}\n`);
  if (kind === 'django') fs.writeFileSync(path.join(dir, '.ddev', 'config.django.yaml'), 'web_extra_daemons: []\n');
  fs.writeFileSync(path.join(dir, 'cucumber.js'), SCAFFOLD);
  fs.writeFileSync(path.join(dir, 'package.json'), JSON.stringify({ name: 'site1', devDependencies: { 'webship-js': '^2.0.6' } }, null, 2));
  const scripts = path.join(root, 'core', 'scripts');
  fs.mkdirSync(path.join(scripts, 'plugins', 'django'), { recursive: true });
  fs.copyFileSync(path.join(PKG, 'testing', 'site.feature'), path.join(scripts, 'plugins', 'django', 'site.feature'));
  fs.copyFileSync(path.join(PKG, 'scripts', 'django-site.py'), path.join(scripts, 'plugins', 'django', 'django-site.py'));
  return { root, dir, scripts };
}

/** Run bash with the plugin's functions sourced and `ddev` replaced by a recorder of its calls (and of what it reads on stdin). */
function bash(script: string, env: Record<string, string> = {}) {
  const fake = 'ddev() { echo "ddev $*" >> "${DDEV_LOG:-/dev/null}" ; if [ ! -t 0 ] ; then head -c 120 | sed "s/^/  stdin: /" >> "${DDEV_LOG:-/dev/null}" ; echo >> "${DDEV_LOG:-/dev/null}" ; fi ; return 0 ; }';
  return spawnSync('bash', ['-c', `${fake}\nsource ${FUNCTIONS}\n${script}`], { encoding: 'utf8', env: { ...process.env, ...env } });
}

/** The accounts a recorded call of django-site.py carried (the base64 of its JSON object). */
function payloadOf(line: string) {
  const m = line.match(/DJANGO_SITE_ACCOUNTS=(\S+)/);
  assert.ok(m, `the call carries the accounts: ${line}`);
  return JSON.parse(Buffer.from(m![1], 'base64').toString('utf8'));
}

test('the default accounts are a superuser, an editor and a viewer, with example addresses', () => {
  const r = bash('set_django_users ; for u in "${users[@]}" ; do n="user_${u}_name" ; m="user_${u}_mail" ; p="user_${u}_password" ; g="user_${u}_role" ; echo "${!n}|${!m}|${!p}|${!g}" ; done');
  assert.strictEqual(r.status, 0, r.stderr);
  const rows = r.stdout.trim().split('\n').map((l) => l.split('|'));
  assert.deepStrictEqual(rows.map((x) => x[0]), ['administrator', 'editor', 'viewer']);
  assert.deepStrictEqual(rows.map((x) => x[3]), ['superuser', 'editor', 'viewer']);
  for (const [name, mail, password] of rows) {
    assert.strictEqual(mail, `${name}@example.com`);
    assert.ok(password.length >= 10, 'long enough for the password rules of a new project');
  }
});

test('the accounts are written by the site script with the site\'s Python, in the folder of manage.py, never in a file', () => {
  const p = project('django');
  const log = path.join(p.root, 'ddev.log');
  const env = { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log, account_name: 'owner1', account_mail: 'owner1@example.com', account_pass: 'Owner-pass-1' };
  const r = bash('set_django_users ; add_django_users', env);
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const written = fs.readFileSync(log, 'utf8');
  const call = written.split('\n').find((l) => l.startsWith('ddev exec -d /var/www/html/mysite')) as string;
  assert.match(call, /\/var\/www\/html\/\.venv\/bin\/python - accounts add$/);
  assert.match(written, /stdin: """The Django test site/, 'the script goes in on stdin');
  const payload = payloadOf(call);
  assert.deepStrictEqual(payload.accounts.map((a: any) => [a.name, a.role]), [['administrator', 'superuser'], ['editor', 'editor'], ['viewer', 'viewer']]);
  assert.strictEqual(payload.owner.name, 'owner1');
  assert.deepStrictEqual(fs.readdirSync(p.dir).filter((f) => !['.ddev', 'cucumber.js', 'package.json'].includes(f)), [], 'no file with a password is left in the project');
});

test('cancelling the accounts deletes the default ones through the site script', () => {
  const p = project('django');
  const log = path.join(p.root, 'ddev.log');
  const r = bash('set_django_users ; cancel_django_users', { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log, account_name: 'owner1', account_mail: 'owner1@example.com', account_pass: 'x' });
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const call = fs.readFileSync(log, 'utf8').split('\n').find((l) => l.includes(' - accounts cancel')) as string;
  assert.ok(call, 'the cancel verb is called');
  assert.deepStrictEqual(payloadOf(call).accounts.map((a: any) => a.name), ['administrator', 'editor', 'viewer']);
});

test('a --django-version is a release line or one release', () => {
  const r = bash('for v in "" 6.1 5.2 6.1.3 latest 6 ; do django_requirement "$v" || echo "refused $v" ; done');
  assert.deepStrictEqual(r.stdout.trim().split('\n'), ['Django~=6.1.0', 'Django~=6.1.0', 'Django~=5.2.0', 'Django==6.1.3', 'refused latest', 'refused 6']);
});

test('the builder writes the container\'s files: the server as a daemon behind the router, and the Python of the site', () => {
  const p = project('django');
  const r = bash(`django_write_ddev_config ${p.dir} 3.12`);
  assert.strictEqual(r.status, 0, r.stderr);
  const config = fs.readFileSync(path.join(p.dir, '.ddev', 'config.django.yaml'), 'utf8');
  assert.match(config, /container_port: 8000\n\s+http_port: 80\n\s+https_port: 443/);
  assert.match(config, /manage\.py runserver --insecure 0\.0\.0\.0:8000/);
  const docker = fs.readFileSync(path.join(p.dir, '.ddev', 'web-build', 'Dockerfile.django'), 'utf8');
  assert.match(docker, /uv python install 3\.12/);
  assert.match(docker, /releases\/download\/0\.13\.7\/uv-\$\{arch\}-unknown-linux-gnu\.tar\.gz/);
});

test('the testing hook adds the step pack, the users registry, the admin\'s settings, the tags and a first feature, once', () => {
  const p = project('django');
  const log = path.join(p.root, 'ddev.log');
  const run = () => bash(`cd ${p.dir} && testing_configure_django ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log, account_name: 'owner1', account_mail: 'owner1@example.com', account_pass: 'x' });
  const r = run();
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const pkg = JSON.parse(fs.readFileSync(path.join(p.dir, 'package.json'), 'utf8'));
  assert.strictEqual(pkg.devDependencies['@webship-js/django-steps'], '^2.0.0');
  assert.strictEqual(pkg.devDependencies['webship-js'], '^2.0.6', 'what was there stays');
  const cucumber = fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8');
  const lines = cucumber.split('\n');
  const core = lines.findIndex((l) => l.includes('node_modules/webship-js/tests/step-definitions'));
  assert.strictEqual(lines[core + 1], "      'node_modules/@webship-js/django-steps/tests/step-definitions/**/*.js',", 'the pack is listed right after webship-js');
  assert.match(cucumber, /administrator: \{ username: process\.env\.DJANGO_ADMINISTRATOR_USERNAME \|\| 'administrator', password: process\.env\.DJANGO_ADMINISTRATOR_PASSWORD \|\| '[^']+', email: process\.env\.DJANGO_ADMINISTRATOR_EMAIL \|\| 'administrator@example\.com' \},/);
  assert.match(cucumber, /viewer: \{ username: process\.env\.DJANGO_VIEWER_USERNAME \|\| 'viewer'/);
  assert.match(cucumber, /dataAdmin: process\.env\.DATA_ADMIN \|\| 'administrator',/);
  assert.match(cucumber, /adminPath: process\.env\.ADMIN_PATH \|\| '\/admin\/',/);
  assert.match(cucumber, /tags: process\.env\.CUCUMBER_TAGS \|\| 'not @wip and not @must-fail',/);
  assert.match(cucumber, /ignore: 'Permissions policy violation: unload is not allowed\|net::ERR_NETWORK_CHANGED'/);
  // Still a module node can load, with the registry where webship-js reads it.
  const loaded = spawnSync(process.execPath, ['-e', `const c = require(${JSON.stringify(path.join(p.dir, 'cucumber.js'))}).default; console.log(JSON.stringify([c.require, Object.keys(c.worldParameters.users), c.tags, c.worldParameters.dataAdmin, c.worldParameters.users.editor.username, c.worldParameters.javascript.mode]))`], { encoding: 'utf8', env: { ...process.env, CUCUMBER_TAGS: '' } });
  assert.strictEqual(loaded.status, 0, loaded.stderr);
  const [requires, handles, tags, admin, username, mode] = JSON.parse(loaded.stdout);
  assert.strictEqual(requires.length, 3);
  assert.deepStrictEqual(handles, ['administrator', 'editor', 'viewer']);
  assert.match(tags, /not @must-fail/);
  assert.strictEqual(admin, 'administrator');
  assert.strictEqual(username, 'editor');
  assert.strictEqual(mode, 'warn');
  assert.ok(fs.existsSync(path.join(p.dir, 'tests', 'features', 'site.feature')));
  assert.match(fs.readFileSync(log, 'utf8'), / - accounts add$/m, 'a site with its superuser gets the default accounts');
  // Again, after a person changed the feature: nothing is doubled, nothing is reset.
  fs.writeFileSync(path.join(p.dir, 'tests', 'features', 'site.feature'), 'Feature: mine\n');
  assert.strictEqual(run().status, 0);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), cucumber);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'tests', 'features', 'site.feature'), 'utf8'), 'Feature: mine\n');
});

test('the testing hook leaves a project of another platform alone', () => {
  const p = project('drupal');
  const r = bash(`cd ${p.dir} && testing_configure_django ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1' });
  assert.strictEqual(r.status, 0);
  assert.strictEqual(r.stdout, '');
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), SCAFFOLD);
  assert.ok(!fs.existsSync(path.join(p.dir, 'tests')));
});

test('the manage.py tool refuses a project that is not a Django site of the plugin', () => {
  const p = project('drupal');
  const r = bash('PROJECT_NAME=site1 ; RUN="check" ; trim_project_name() { :; } ; django_manage_tool', { WORKSPACE_ROOT: p.root, doc_name: 'dev' });
  assert.strictEqual(r.status, 1);
  assert.match(r.stdout, /is not a Django project of this plugin/);
});

test('the first feature names no platform in a step, and no password', () => {
  const feature = fs.readFileSync(path.join(PKG, 'testing', 'site.feature'), 'utf8');
  const steps = feature.split('\n').filter((l) => /^\s*(Given|When|Then|And|But) /.test(l));
  assert.ok(steps.length >= 10);
  for (const s of steps) assert.doesNotMatch(s, /django|python/i, s);
  assert.doesNotMatch(feature, /dD\.123123ddd/);
  assert.doesNotMatch(feature, /createsuperuser|in the "Users" list with:/i, 'a suite never creates an account');
});

// ---- The runtimes: DDEV as before, and Docker Compose, Podman and Kubernetes through the core's language stacks (#841) ----

const ADDRESSES: Record<string, string> = { docker: 'http://127.0.0.1:41234', podman: 'http://127.0.0.1:41234', kubernetes: 'http://172.18.0.2:30080' };

/**
 * The builder in a throwaway workspace, with `ddev` replaced by a recorder (`ddev exec` answering the server's check
 * with 200), the site script by a stand-in, and the core's layer by stand-ins: `layer` is the runtime it answers with
 * (runtime_of, rt_url, rt_claim, rt_stack, rt_web_build, rt_serve), or '' for a core with no layer. `stacks` says
 * whether the layer has the language stacks (#841).
 */
function build(layer: string, env: Record<string, string> = {}, { stacks = true } = {}) {
  const p = project('django');
  fs.rmSync(p.dir, { recursive: true });
  const log = path.join(p.root, 'ddev.log');
  const address = ADDRESSES[layer] || '';
  const prelude = [
    `ddev() { echo "ddev $*" >> "${log}" ; [ "$1" == exec ] && [[ "$*" == *"curl -s -o /dev/null"* ]] && echo 200 ; [ -t 0 ] || cat > /dev/null ; return 0 ; }`,
    'trim_project_name() { :; } ; drop_database() { :; } ; ddev_nodejs_version() { echo 24 ; } ; ddev_up() { ddev "$@" ; } ; django_site() { echo "django_site $*" >> "$DDEV_LOG" ; }',
    layer ? `runtime_of() { echo "\${RUNTIME_ANSWER}" ; } ; rt_url() { [ "\${RUNTIME_ANSWER}" == ddev ] && echo "https://\${PROJECT_NAME}.ddev.site" || echo "${address}" ; } ; rt_claim() { echo "rt_claim $*" >> "${log}" ; } ; rt_is_platform() { return 1 ; }` : '',
    layer && stacks ? `rt_stack() { echo "rt_stack $*" >> "${log}" ; } ; rt_web_build() { echo "rt_web_build $1 <<< $(tr '\\n' '|')" >> "${log}" ; } ; rt_serve() { echo "rt_serve $1 [$2]" >> "${log}" ; }` : '',
    `source ${FUNCTIONS}`,
    'django_build',
  ].join('\n');
  const r = spawnSync('bash', ['-c', prelude], { encoding: 'utf8', env: { ...process.env, WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log,
    INSTALL: 'yes', ADD_USERS: 'no', POLLS: 'no', LAUNCH: 'no', DJANGO_VERSION: '6.1', PYTHON_VERSION: '3.13',
    RUNTIME: '_none_', RUNTIME_ANSWER: layer || 'ddev', account_name: 'owner1', account_mail: 'owner1@example.com', account_pass: 'Owner-pass-1234', ...env },
    stdio: ['ignore', 'pipe', 'pipe'] });
  const calls = fs.existsSync(log) ? fs.readFileSync(log, 'utf8').trim().split('\n').filter((c) => /^(ddev|rt_[a-z_]+) /.test(c)) : [];
  return { r, calls, dir: path.join(p.root, 'dev', 'site1') };
}

test('on DDEV the build is what it was: the same commands with the layer and without it, the server a daemon of DDEV\'s web container', () => {
  const without = build('');
  const withLayer = build('ddev');
  for (const b of [without, withLayer]) {
    assert.strictEqual(b.r.status, 0, b.r.stderr + b.r.stdout);
    assert.match(b.r.stdout, /Go to https:\/\/site1\.ddev\.site\/admin\/ and log in as owner1/);
    assert.ok(fs.existsSync(path.join(b.dir, '.ddev', 'config.django.yaml')) && fs.existsSync(path.join(b.dir, '.ddev', 'web-build', 'Dockerfile.django')));
    assert.ok(b.calls.includes('ddev exec supervisorctl restart webextradaemons:django'), 'the server restarted as DDEV\'s daemon');
  }
  assert.deepStrictEqual(withLayer.calls, without.calls);
  assert.ok(!withLayer.calls.some((c) => c.startsWith('rt_')), 'nothing through the layer on DDEV');
});

test('on Docker Compose, Podman and Kubernetes the site is claimed, Python is the stack\'s own image at the site\'s version, uv is added, and the server is the web container\'s own', () => {
  for (const runtime of Object.keys(ADDRESSES)) {
    const b = build(runtime, { RUNTIME: runtime });
    assert.strictEqual(b.r.status, 0, runtime + ': ' + b.r.stderr + b.r.stdout);
    assert.match(b.calls[0], /^ddev config --project-type=generic --webserver-type=generic --docroot= --project-name=site1 --database=postgres:16 /, runtime);
    assert.deepStrictEqual(b.calls.slice(1, 5).map((c) => c.split(' <<<')[0].split(' [')[0]), ['rt_claim django', 'rt_stack python 3.13', 'rt_web_build uv', 'rt_serve 8000'], runtime);
    assert.match(b.calls[3], /releases\/download\/0\.13\.7\/uv-/, `${runtime}: the uv of DDEV's build`);
    // Once the site is made, and once the database takes connections: a Kubernetes cluster started again can start the
    // web pod before its DNS and the database.
    assert.strictEqual(b.calls[4], 'rt_serve 8000 [while [ ! -f mysite/.ready ] ; do sleep 2 ; done ; until pg_isready -q -h db -U db ; do sleep 2 ; done ; cd mysite && exec ../.venv/bin/python manage.py runserver --insecure 0.0.0.0:8000]', runtime);
    assert.ok(b.calls.includes('ddev restart'), `${runtime}: the web container starts again with the server`);
    assert.ok(!b.calls.some((c) => c.includes('supervisorctl')), `${runtime}: no DDEV daemon`);
    assert.ok(!fs.existsSync(path.join(b.dir, '.ddev')), `${runtime}: nothing of DDEV's is written`);
    assert.ok(b.r.stdout.includes(`Go to ${ADDRESSES[runtime]}/admin/ and log in as owner1`), `${runtime}: ${b.r.stdout}`);
    assert.doesNotMatch(b.r.stdout, /ddev\.site/, runtime);
  }
});

test('--runtime is refused, before anything is made, without the layer, without its language stacks, and on Lando and Docksal for now', () => {
  const none = build('', { RUNTIME: 'docker' });
  assert.strictEqual(none.r.status, 1);
  assert.match(none.r.stdout, /--runtime docker needs a Webship Workspace with the container runtimes \(webship\/workspace#694\)/);
  const older = build('docker', { RUNTIME: 'docker' }, { stacks: false });
  assert.strictEqual(older.r.status, 1);
  assert.match(older.r.stdout, /Django on docker needs a Webship Workspace whose runtimes take an application's own language and server \(webship\/workspace#841, core 1\.0\.32 or later\)/);
  for (const runtime of ['lando', 'docksal']) {
    const r = build(runtime, { RUNTIME: runtime });
    assert.strictEqual(r.r.status, 1, runtime);
    assert.match(r.r.stdout, new RegExp(`Django on ${runtime} waits for the language stacks there`));
    assert.deepStrictEqual(r.calls, [], runtime);
  }
});

test('the builder takes --runtime; on another runtime the settings send the site\'s mail to the stack\'s Mailpit', () => {
  const args = fs.readFileSync(path.join(PKG, 'scripts', 'args', 'arg-django.sh'), 'utf8');
  assert.match(args, /parser\.add_argument\('--runtime',\s*dest='RUNTIME',\s*default="_none_",\s*choices=\['ddev', 'docker', 'podman', 'kubernetes', 'lando', 'docksal'\]/);
  // The settings the script really writes, for a project of manage.py's own shape, on DDEV and on a runtime.
  const written = (runtime: string): string => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'django-settings-'));
    fs.mkdirSync(path.join(dir, 'mysite'));
    fs.writeFileSync(path.join(dir, 'manage.py'), "os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'mysite.settings')\n");
    fs.writeFileSync(path.join(dir, 'mysite', 'settings.py'), 'DEBUG = True\n');
    const env: NodeJS.ProcessEnv = { ...process.env };
    if (runtime) env.WEBSHIP_RUNTIME = runtime; else delete env.WEBSHIP_RUNTIME;
    const r = spawnSync('python3', [path.join(PKG, 'scripts', 'django-site.py'), 'settings'], { cwd: dir, env, encoding: 'utf8' });
    assert.strictEqual(r.status, 0, r.stderr);
    const text = fs.readFileSync(path.join(dir, 'mysite', 'site_settings.py'), 'utf8');
    fs.rmSync(dir, { recursive: true, force: true });
    return text;
  };
  const ddev = written('');
  assert.match(ddev, /CSRF_TRUSTED_ORIGINS = \["https:\/\/\*\.ddev\.site", "http:\/\/\*\.ddev\.site"/, 'DDEV as before');
  assert.match(ddev, /SECURE_PROXY_SSL_HEADER = \("HTTP_X_FORWARDED_PROTO", "https"\)/);
  for (const runtime of ['docker', 'podman', 'kubernetes']) {
    const text = written(runtime);
    assert.doesNotMatch(text, /ddev\.site/, `${runtime}: nothing of ddev.site`);
    assert.doesNotMatch(text, /SECURE_PROXY_SSL_HEADER/, `${runtime}: no router in front, so no proxy header`);
    assert.match(text, /CSRF_TRUSTED_ORIGINS = \["http:\/\/localhost:8000", "http:\/\/127\.0\.0\.1:8000"\]/);
    assert.match(text, /"host": "mail", "port": 1025/, `${runtime}: the mail goes to the stack's Mailpit`);
  }
});
