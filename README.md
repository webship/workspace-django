# @webship.co/workspace-django

Django for the [Webship Workspace](https://github.com/webship/workspace) dashboard: a builder that
makes a real Django site in a container (a plain project made with `django-admin startproject`, with
the polls app of the official tutorial on request), a manage.py tool for the sites it built, the
default accounts, the [Django admin step pack](https://github.com/webship/django-steps) wired into the
workspace's testing setup, and its AI items — two agents, a skill, a command and two prompts — each
listed in the workspace folder of its kind.

The workspace is container-based (DDEV by default): a Django site is a row like any other, so the
row menus the core draws (start, stop, launch, backup, clone, remove, tests) work on it unchanged. The
row's Users menu does not apply to a Django site: see [The default accounts](#the-default-accounts).

It is made from the reference platform plugin, `@webship.co/workspace-wordpress`, and runs its sites
the way the django CMS plugin (`@webship.co/workspace-django-cms`) runs its own.

## Use it

```bash
cd ~/workspace
bash core/scripts/plugins.sh --require @webship.co/workspace-django --with-needs   # npm install into the dashboard
bash core/scripts/plugins.sh --activate django --with-needs                         # plugins.django in settings.yml
bash core/scripts/plugins.sh --install django                                       # commands, functions, args, AI items
bash core/scripts/plugins.sh --configure django                                     # nothing to configure: it has no settings file
```

The same four steps are buttons on the dashboard's **Settings → Plugins** page. `--install` is
idempotent. `--uninstall` removes what it placed; an AI item you edited stays.

Everything the plugin carries lands in the folder it belongs to, when that folder is an active
workspace folder:

| What | Lands in |
| --- | --- |
| `cmd-django-project.sh`, `cmd-tools-django-manage.sh` | every active sites folder: `dev/`, `test/`, `sandboxes/`, `demos/` |
| The agents `django-site-builder`, `django-tester` | `ai-agents/` |
| The skill `django-scenarios` | `ai-skills/` |
| The command `/django-test` | `ai-commands/` |
| The prompts `django-build-and-test`, `django-scenarios-for-an-area` | `ai-prompts/` |

There they are listed like any other item of the folder, and installed into Claude Code from there.

## What it needs

A workspace starts empty, so the manifest says what else this plugin needs (`needs`):

- one sites folder, for the builder and the tool: `dev`, `test`, `sandboxes`, `demos` (`dev` is the one added when none is there). The folder also carries `cmd-tools-testing.sh` and the Users tools this plugin's hooks answer to.
- `ai-agents`, `ai-skills`, `ai-commands` and `ai-prompts`: the AI folders its agents, its skill, its command and its prompts are placed in.

`--require` says so, `--activate` and `--install` stop until the workspace has them, and `--with-needs` adds what is missing first:

```bash
bash core/scripts/plugins.sh --activate django --with-needs   # dev and the four AI folders are required, activated and installed first
bash core/scripts/plugins.sh --install django
```

Everything the builder runs for a site runs in the site's own container, through the container tool the workspace already needs: Python, the packages, `django-admin` and `manage.py` are the web container's. The plugin asks for no command of its own on the machine.

## What the package holds

| Path | What it is |
| --- | --- |
| `commands/cmd-django-project.sh` | The builder, in the Build list as **Django (startproject, polls)**, installed into every sites folder |
| `commands/cmd-tools-django-manage.sh` | manage.py for one site: what the site is, a command, an update within its release line, a restart, the default accounts |
| `scripts/functions/fun-django.sh` | The bash functions behind both, sourced by bootstrap once installed; the names the core's tools look for (`set_django_users`, `add_django_users`, `cancel_django_users`, `testing_configure_django`) |
| `scripts/args/arg-django.sh`, `arg-django-manage.sh` | Their argparse; the Build form draws the builder's flags from the first |
| `scripts/django-site.py` | Run with the site's Python in the project's container: the settings of the container, the polls app and its sample data, the accounts (the same script the step pack's test site is built with) |
| `scripts/POLLS-LICENSE` | The licence of the tutorial's polls app (BSD, from the Django documentation) |
| `testing/site.feature` | The first feature a Django site gets when testing is set up |
| `ai/agents/django-site-builder.md` | The agent that builds and maintains Django sites with these commands |
| `ai/agents/django-tester.md` | The agent that writes and runs scenarios with the Django admin step pack |
| `ai/skills/django-scenarios/` | The skill: the step pack's phrases by area, the traps found on a real site, three example features |
| `ai/commands/django-test.md` | The slash command `/django-test <site>`: set up, match every step, run, report |
| `ai/prompts/django-build-and-test.md`, `django-scenarios-for-an-area.md` | Two prompts: whole launch commands for a new session |
| `src/index.ts` | `register(api)`: what the assistant is told about Django here |
| `features/django.feature` | Scenarios for the dashboard's own browser suite |

The `workspacePlugin` block in `package.json` is the manifest the installer reads.

## What is different from a PHP platform

Django is a Python framework and DDEV has no project type for it. The plugin keeps the shape of the
reference and changes only this, the way the django CMS plugin does:

| | WordPress (the reference) | Django |
| --- | --- | --- |
| Project | `--project-type=wordpress`, nginx and PHP | `--project-type=generic --webserver-type=generic`: no web server of the container tool's own; the router sends the project's address to the Django server's port, and the web container runs the server as a daemon (`.ddev/config.django.yaml`) |
| Recognised by | The DDEV project type | The file `.ddev/config.django.yaml` |
| The language | PHP, in the web image | Python, in the web image: uv and the Python it installs (`.ddev/web-build/Dockerfile.django`); the packages in a virtual environment of the project (`.venv/`) |
| Database | The container tool's default, settings written by the tool | PostgreSQL 16 from the container tool; `site_settings.py` carries the container's own `db` / `db` / `db` |
| Getting the code | `wp core download` | `pip install Django` of the line asked for, then `django-admin startproject mysite` |
| Install | `wp core install` | `manage.py migrate`; with `--install` the workspace account is created as the superuser |
| Accounts | WP-CLI | `scripts/django-site.py`, run with the site's Python |
| Users menu of the row | Reads the project type | Does not apply (the type is `generic`): the manage.py tool's `--add-users`, or `cmd-tools-add-users.sh <name> django` |

## The commands

Run them from a sites folder. `--help` is safe on both.

### Build a site

```bash
cd ~/workspace/dev
bash cmd-django-project.sh mysite --install --add-users --polls
```

| Flag | What it does |
| --- | --- |
| `--install` | Give the site its superuser: the workspace account |
| `--add-users` | With `--install`: add the default accounts |
| `--polls` | Add the polls app of the official tutorial, registered in the admin with the features most projects use, and its sample data (5 categories, 4 tags, 24 questions) |
| `--django-version <x>` | A release line (`6.1`, the default and the current stable line; `5.2`, the long-term-support line) or one release, such as `6.1.3` |
| `--python-version <x>` | The Python of the site: `3.12`, `3.13` (the default) or `3.14` |
| `--launch` | Open the admin when it is ready |

The site answers at `https://mysite.ddev.site`, the admin at `/admin/`. It is what
`django-admin startproject mysite` makes, in the project's `mysite/` folder; what the builder adds to
its settings is in `mysite/mysite/site_settings.py` (the hosts and the proxy, the database, the
mailbox of the container, `DEBUG` off so that the site answers with its real pages: a missing page is
the 404 page, a refusal the 403 page). The server is `manage.py runserver --insecure`, which serves
the static files with `DEBUG` off. A project of the same name is deleted first.

A plain project has no page at its root: the address of the site answers 404, its admin is at `/admin/`.

With `--polls`, the polls app is the tutorial's (parts 1 to 8), registered in the admin with what most
projects use: fieldsets (one that folds), the inline choices (a table), `list_display`, `list_filter`,
`search_fields`, `date_hierarchy`, pages of 10, an action, a category (an autocomplete field, a
stacked inline of its questions, a protected relation), tags (a two-list selector) and a read-only
field. The step pack's features run on such a site.

### Work on a site

```bash
bash cmd-tools-django-manage.sh mysite                                  # version, packages, apps, accounts
bash cmd-tools-django-manage.sh mysite --run "showmigrations polls"     # any manage.py command
bash cmd-tools-django-manage.sh mysite --update                         # the latest release of its line, migrate, restart
bash cmd-tools-django-manage.sh mysite --restart                        # start the server again and wait for it
bash cmd-tools-django-manage.sh mysite --add-users                      # the default accounts
bash cmd-tools-django-manage.sh mysite --cancel-users                   # delete them
```

On a start or a restart the container tool may print "Unable to start web_extra_daemons" with
"supervisor.sock no such file": it asked before the web container was ready, and the container starts
the server by itself a moment later. `--restart` starts it again and waits until it answers.

### The default accounts

| Account | Address | What it is | Handle in the tests |
| --- | --- | --- | --- |
| `administrator` | `administrator@example.com` | a superuser | `administrator` |
| `editor` | `editor@example.com` | staff, in the group Editors: adds, changes, deletes and views the objects of the project's own apps | `editor` |
| `viewer` | `viewer@example.com` | staff, in the group Viewers: views them, nothing else | `viewer` |

Each account has the password of the workspace's other default lists. They are for local sites and
for tests; the site's superuser from `--install` is the workspace account and is never written into a
test.

**Manage them with the manage.py tool, not the row's Users menu.** The dashboard's Users menu picks
its actions by the project type, and a Django site's type is `generic`, so the menu offers no action
that applies to it. Use:

```bash
bash cmd-tools-django-manage.sh mysite --add-users     # add them, or give them back their password, address, staff status and group
bash cmd-tools-django-manage.sh mysite --cancel-users  # delete them
bash cmd-tools-add-users.sh mysite django              # the core's tool: the same list
bash cmd-tools-cancel-users.sh mysite django
```

Adding them again also gives the groups the permissions of the apps the project has now: after you
add an app of your own, run `--add-users` and the Editors and Viewers get its models too.

### Test a site

```bash
bash cmd-tools-testing.sh mysite                 # webship-js, the step pack, the users registry, a first feature
bash cmd-tools-testing.sh mysite --run           # run the suite in the container
bash cmd-tools-testing.sh mysite --run --path tests/features/site.feature
```

`cmd-tools-testing.sh` is the workspace's own. For a Django site it also adds
`@webship-js/django-steps` to `package.json`, lists its step definitions in `cucumber.js` after
webship-js's own, writes the users registry (the handles above, overridable with
`DJANGO_<HANDLE>_USERNAME`, `DJANGO_<HANDLE>_PASSWORD` and `DJANGO_<HANDLE>_EMAIL`), `adminPath`
(`/admin/`), `dataAdmin` (the handle the step pack makes and deletes its test objects as), the browser
messages that are no error of the site, and the tags that keep the pack's assertions that must fail
out of a normal run, places `tests/features/site.feature` when the project has none, and makes sure the
default accounts are on the site. Run it again and it adds what is missing and keeps what you changed.

The suite runs in the project's container, where the network changes of the host (another container
starting) do not cut the browser's requests.

A scenario of your own reads like this one, from the step pack's phrases (the skill
`django-scenarios` lists them by area); the objects it adds through the admin's forms are deleted
after it:

```gherkin
Feature: The editor files a question
  Scenario: A question in a category
    Given there is no "Readme test question" in the "Questions" list
    And I am a logged in user with the "editor" user
    When I open the add form of "Questions"
    And I set "Question text" to "Readme test question"
    And I set "Date published" to "now"
    And I choose "Science" in the "Category" autocomplete
    And I save the form
    Then the form should be saved
```

`tests/features/site.feature` passes on a site built with `--install --add-users`. The features of
the step pack, and the scenario above, pass on a site built with `--install --add-users --polls`.

## The AI items

`ai/` in the package holds one folder per kind, the manifest's `ai` block names each item, and
`--install` places it in the workspace folder of that kind.

| Kind | Item | Use it to |
| --- | --- | --- |
| Agent | `django-site-builder` | Build, update, restart, maintain or remove a Django site with the commands above, in containers only |
| Agent | `django-tester` | Set the testing stack up, look at the admin in the Playwright MCP browser first, write scenarios from the pack's steps and run them; it never creates an account in a suite and never writes a platform name into a step phrase |
| Skill | `django-scenarios` | Write a scenario from phrases that exist: the pack's steps by area, the handles of the users registry, the test objects, the traps found on a real site, and three features that pass on a site with the polls app |
| Command | `/django-test <site> [feature or @tag]` | Run the suite of a site from inside a session: set up when missing, match every step, run, report what failed and why |
| Prompt | `django-build-and-test` | Start a session that builds a site, says what it is, sets the testing stack up and runs the first feature |
| Prompt | `django-scenarios-for-an-area` | Start a session that writes and runs the scenarios of one area of the admin |

After `--install` each is in its folder on the dashboard. **Install** there puts an agent, a skill
or a command into Claude Code (`~/.claude/agents`, `~/.claude/skills`, `~/.claude/commands`), or
from the command line:

```bash
cd ~/workspace/ai-agents   && bash cmd-tools-ai-items.sh django-tester --install
cd ~/workspace/ai-skills   && bash cmd-tools-ai-items.sh django-scenarios --install
cd ~/workspace/ai-commands && bash cmd-tools-ai-items.sh django-test --install
```

A prompt is not installed: it is the whole `claude …` launch command of a new session, and the
dashboard's **New screen** form lists it as a template. By hand, fill the placeholders in and run
the command of the file from the folder it names.

The items are written for any AI CLI, with Claude Code as the default shape: the frontmatter and
the file layout are Claude Code's, the body of each item is plain Markdown that names no tool or
feature of one CLI, a command says in words what its arguments are, and the text between the
triple quotes of a prompt can be given to another AI CLI as it is.

Every step phrase the items show is checked against the definitions of the step pack and of
webship-js (`tests/fixtures/step-definitions.txt`), and every command and flag against the
plugin's own.

## Develop it

```bash
npm install     # builds dist/ (TypeScript)
npm run lint
npm test        # the manifest, the commands, the AI items, the functions against a scaffolded project
```

CI runs the same on Node.js 24 and 26, parses every shell script, and runs the plugin's
`features/django.feature` against a dashboard with this plugin installed
(`webship/workspace/.github/workflows/plugin-browser-suite.yml`).
