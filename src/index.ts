/**
 * Django for Webship Workspace: a platform plugin.
 *
 * What the package carries is placed by the installer from the manifest: the builder and the
 * manage.py tool in the sites folders, their functions and argparse under core/scripts/plugins/django/
 * (with django-site.py, which the builder runs with the site's Python), and its AI items (ai/ in this
 * package) in the folder of their kind: the agents in AI Agents, the skill in AI Skills, the command
 * in AI Commands, the prompts in AI Prompts. The dashboard needs nothing drawn for it: the builder is
 * in the Build list because it is a cmd-*-project.sh, the row menus are the core's, the AI items are
 * listed like any other. What register() adds is what the assistant is told.
 *
 * Everything the dashboard is asked for goes through `api`; this package requires nothing from the
 * dashboard's own files, so it can be installed from npm and removed without a trace.
 */

import type { PluginApi } from '@webship.co/workspace-plugin-api';

/** The plugin's name. A Django site is a generic DDEV project: the plugin knows it by .ddev/config.django.yaml. */
export const PLATFORM = 'django';

/** The commands the installer places in every sites folder. */
export const COMMANDS = ['cmd-django-project.sh', 'cmd-tools-django-manage.sh'];

/** The agents the installer places in the AI Agents folder. */
export const AGENTS = ['django-site-builder', 'django-tester'];

/** The skill the installer places in the AI Skills folder (a folder each, with its SKILL.md). */
export const SKILLS = ['django-scenarios'];

/** The slash command the installer places in the AI Commands folder. */
export const AI_COMMANDS = ['django-test'];

/** The prompts the installer places in the AI Prompts folder: each a whole launch command for a new session. */
export const PROMPTS = ['django-build-and-test', 'django-scenarios-for-an-area'];

/** What the assistant is told about Django in this workspace. */
export function assistantContext(): string {
  return [
    'Django (a plugin, @webship.co/workspace-django): a site is built with',
    '`bash cmd-django-project.sh <name> --install --add-users --polls` from a sites folder (dev, test, sandboxes, demos):',
    'a plain project made with django-admin startproject (the current stable line, or `--django-version 5.2` for the long-term-support line),',
    'with `--polls` the polls app of the official tutorial registered in the admin and its sample data,',
    'in a container like every other project: on DDEV (the default) a generic project, Python in the web image, the server as a daemon, PostgreSQL, its admin at https://<name>.ddev.site/admin/;',
    'with `--runtime docker`, `podman`, `kubernetes`, `lando` or `docksal` the core\'s Python stack, the server through rt_serve, PostgreSQL, its admin at the address the runtime gives (the row links it).',
    '`bash cmd-tools-django-manage.sh <name>` says what the site is; `--run "<command> <args>"` runs a manage.py command in it,',
    '`--update` updates Django within its line, `--restart` starts the server again,',
    '`--add-users` adds the default accounts (administrator, editor, viewer) and `--cancel-users` deletes them.',
    'The row\'s Users menu does not apply to a Django site (its project type is generic): use the manage.py tool for the accounts.',
    '`bash cmd-tools-testing.sh <name>` sets up webship-js with the Django admin step pack; `--run` runs the suite.',
    `For Django work, hand over to the agents ${AGENTS.map((a) => `\`${a}\``).join(' and ')}.`,
    `The plugin also places the skill ${SKILLS.map((a) => `\`${a}\``).join(', ')} (the step pack's phrases, by area) in ai-skills/,`,
    `the command ${AI_COMMANDS.map((a) => `\`/${a} <site>\``).join(', ')} in ai-commands/ and the prompts ${PROMPTS.map((a) => `\`${a}\``).join(' and ')} in ai-prompts/.`,
    'Never run python, pip or manage.py on the host for a project; the database settings in its site_settings.py are the container\'s own (db, db, db).',
  ].join(' ');
}

export function register(api: PluginApi): void {
  api.addAssistantContext(assistantContext);
}
