---
description: Test the admin of a Django site of the Webship Workspace with webship-js and the Django admin step pack — set the testing stack up when it is missing, match every step, run the suite (or one feature, or one tag) in the site's container, and report what failed and why.
argument-hint: '<site> [tests/features/<name>.feature | @tag]'
---

# /django-test

Test the Django site named in: `$ARGUMENTS`

`$ARGUMENTS` stands for what was typed after the command. An AI CLI that does not fill it in
reads the same from the request: the name of the site, then, if anything, one feature path or one
tag.

The first word is the site (its folder name in a sites folder of the workspace). What follows, if
anything, narrows the run: a path that starts with `tests/features/` is one feature (or one folder
of features), a word that starts with `@` is a tag expression. With nothing after the site, the whole
suite runs. With no site at all, stop and ask for one: list the candidates with
`ls -d ~/workspace/*/*/.ddev/config.django.yaml`.

The workspace is container-based (DDEV by default) and everything below runs in the site's container
through the workspace's own command. Never run `npx cucumber-js`, `npx playwright`, `python` or
`manage.py` on the host for a site.

## 1. Find the site

```bash
ls -d ~/workspace/*/<site>/.ddev/config.django.yaml
```

Work from that sites folder (`cd ~/workspace/<folder>`). A site with no superuser has no account to
test with: say so, and name `bash cmd-django-project.sh <site> --install --add-users --polls` (it
rebuilds the site from nothing).

## 2. Set the testing stack up, when it is missing

```bash
bash cmd-tools-testing.sh <site>
```

It adds webship-js, the Django admin step pack, the users registry (`administrator`, `editor`,
`viewer`), the handle the test-object steps work as, and `tests/features/site.feature`. A project
that has `cucumber.js` already keeps it; the setup adds only what is missing.

## 3. Match every step

```bash
bash cmd-tools-testing.sh <site> --dry-run
```

Every step must match exactly one definition. An undefined step is a phrase that does not exist: find
the real one in the pack's README or in the `django-scenarios` skill, never invent a step.

## 4. Run

```bash
bash cmd-tools-testing.sh <site> --run                                     # the whole suite
bash cmd-tools-testing.sh <site> --run --path tests/features/site.feature  # one feature
bash cmd-tools-testing.sh <site> --run --tags @critical                    # one tag
```

## 5. Report

The scenarios and steps that passed and failed, then for each failure: the step, its message and
hint, the screenshot the run kept, and what it means (a defect of the site, a scenario to fix, or a
request the browser cut, which a second run clears). A suite never creates an account, never writes
a password into a feature file, and never writes a platform name into a step phrase. For writing or
fixing scenarios, use the `django-scenarios` skill or hand over to the `django-tester` agent; for
changing the site, to `django-site-builder`.

Before you write or change a scenario, or read a failed run, read the book *Automated Functional
Testing Recipes* (its `README.md`, then the matching chapter):
`.claude/automated-functional-testing-recipes/` in the project,
`~/.claude/automated-functional-testing-recipes/`, or
https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes
