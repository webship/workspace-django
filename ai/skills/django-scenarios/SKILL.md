---
name: django-scenarios
description: Write webship-js scenarios for the admin of a Django site of the Webship Workspace from phrases that exist — the Django admin step pack's steps by area (the session, the index, the change list, the forms and their fields, inline rows, deleting and the history, the password, users and groups), the handles of the users registry, the test objects a scenario makes and the steps delete, the traps found on a real site, and three features that pass on a site built with the polls app. Use when writing or fixing a scenario for a Django admin, choosing a step for an admin screen, or turning a manual check of the admin into a feature.
---

# django-scenarios

Scenarios for the admin of a site built with the Django plugin (`bash cmd-django-project.sh <site>
--install --add-users --polls`) in a container-based workspace (DDEV by default), tested with webship-js
and `@webship-js/django-steps` once `bash cmd-tools-testing.sh <site>` set the project up. Every phrase
below exists in the pack or in webship-js; a scenario names no platform.

## Accounts and test objects

- `Given I am a logged in user with the "editor" user`: `administrator` (a superuser), `editor`
  (staff, the group Editors), `viewer` (staff, the group Viewers, view only). `Given I am not logged in`
  for a visitor: it opens the admin's login page (a plain project has no home page).
- `Given there is no "…" in the "Questions" list`: for an object the scenario makes itself; it is
  deleted now when a stopped run left it, and again after the scenario.
- `Given there is a "…" in the "Questions" list with:` and a table of labels and values: a test
  object made through the add form as the data administrator, deleted after the scenario. Every object
  a scenario adds through a form on screen is deleted after it too.
- `Then there should be no "…" in the "Questions" list`: a check as the data administrator.

## Phrases by area

| Area | Steps |
| --- | --- |
| Session | `I log in as "editor" with the login form`, `I log in with the user name "…" and the password "…"`, `the login should be refused with "…"`, `I log out`, `I should be logged in as "editor"`, `I should not be logged in`, `I should be on the admin login page` |
| Index | `I open the admin index`, `the admin index should list the app "Polls"`, `the app "Polls" should list the model "Questions"`, `I should be able to add "Questions"` (or `change`, `view`), `my recent actions should list "…" as added`, `the breadcrumbs should read "Home › Polls › Questions"`, `I follow "Polls" in the breadcrumbs`, `I filter the navigation sidebar with "…"`, `the navigation sidebar should show "…"`, `I switch the admin theme to "dark"`, `I should not be allowed to open "/admin/auth/user/"` |
| List | `I open the "Questions" list`, `I search the list for "…"`, `the search should find 2 results of 24`, `the list should show "…"`, `the list should count 24 questions`, `the list should have 10 rows`, `the "…" row should show "Science" in the "Category" column`, `I sort the list by "Date published" in descending order`, `the first row of the list should be "…"`, `I choose "Science" in the "By category" filter`, `I clear all filters`, `I show the filter counts`, `the "By category" filter should count 5 for "Science"`, `I choose "2025" in the date drill-down`, `I go to page 2 of the list`, `I show all rows of the list` |
| Selection and actions | `I select "…" in the list`, `I select all rows on the page`, `I select everything in the list`, `the selection should read "2 of 10 selected"`, `I run the action "Delete selected questions"`, `the list should offer the action "…"` |
| Forms | `I open the add form of "Questions"`, `I open "…" in the "Questions" list`, `I open "…" from the list`, `I set "Question text" to "…"`, `I set "Date published" to "now"`, `I set these fields:`, `"Category" should be set to "Science"`, `"Total votes" should be read-only and show "0"`, `I choose "Science" in the "Category" autocomplete`, `I choose "Fun" in the "Tags" selector`, `the "Tags" selector should have "Fun" chosen`, `I open the section "Date information"`, `I save the form and continue editing`, `the form should be saved`, `I should see the success message "…"`, `the field "Question text" should have the error "This field is required."`, `I should see the "Change question" form for "…"`, `the form should be read-only` |
| Inline rows | `the "Choices" inline should have 3 rows`, `I add a row to the "Choices" inline`, `I fill in the "Choices" inline:`, `I set "Choice text" to "Yes" in row 1 of the "Choices" inline`, `I remove row 2 of the "Choices" inline`, `the "Choices" inline should list "Yes"` |
| Deleting and history | `I click "Delete"`, `the delete confirmation should list "Choice: Yes"`, `the delete confirmation should count "Choices: 2"`, `I confirm the deletion`, `I cancel the deletion`, `the deletion should be refused because of "…"`, `I delete "…" from the "Questions" list`, `I open the history`, `the history should list "Added." by "editor"` |
| Accounts | `I change my password to "…"`, `I try to change my password with my old password and the new passwords "…" and "…"`, `the password change should be refused with "…"`, `the user "editor" should be staff`, `the user "editor" should be in the "Editors" group`, `the "Editors" group should have the "Can change question" permission` |

## A scenario, start to end

A deletion that lists what it takes with it, then the history of another object: each object the
scenario makes is deleted after it, whatever happens in it.

```gherkin
Feature: Deleting and the history
  Scenario: A question deleted with its choices
    Given there is no "Skill delete question" in the "Questions" list
    And I am a logged in user with the "editor" user
    When I open the add form of "Questions"
    And I set "Question text" to "Skill delete question"
    And I set "Date published" to "2026-05-01 10:00:00"
    And I fill in the "Choices" inline:
      | Choice text |
      | Yes         |
      | No          |
    And I save the form and continue editing
    And I click "Delete"
    Then the delete confirmation should list "Choice: Yes"
    And the delete confirmation should count "Choices: 2"
    When I confirm the deletion
    Then there should be no "Skill delete question" in the "Questions" list

  Scenario: The history of a change
    Given there is a "Skill history question" in the "Questions" list with:
      | Question text  | Skill history question |
      | Date published | 2026-05-03 10:00:00    |
    And I am a logged in user with the "editor" user
    When I open "Skill history question" in the "Questions" list
    And I set "Category" to "Sport"
    And I save the form and continue editing
    And I open the history
    Then the history should list "Changed Category." by "editor"
```

## Traps found on a real site

- A field's label is written without its colon: "Question text", not "Question text:". webship-js's
  `I fill in "…" with "…"` wants the label exactly, colon included; `I set "…" to "…"` finds the field
  as a person reads it, whatever its kind.
- A list shows one page at a time (10 rows on the test site): search for a row, or go to its page,
  before a step looks for it there.
- The date drill-down goes one level at a time: from a month, "‹ 2025" goes back to the year, and only
  from a year does "‹ All dates" show.
- A field in a folded section is hidden until the section opens; the steps open it, a plain webship-js
  step does not.
- The admin's messages use typographic quotes (“…”) and apostrophes (’): the steps take straight ones
  for them.
- A changed password is set back after the scenario by the steps; a password changed by hand is not.
- On a shared machine the browser on the host can lose a request when another container starts: run
  the suite in the container (`bash cmd-tools-testing.sh <site> --run`).

## Examples

- [`examples/change-list.feature`](examples/change-list.feature): a search, a filter, sorting and the pages of the list.
- [`examples/forms.feature`](examples/forms.feature): a question added with every kind of field, and a refused form.
- [`examples/accounts-and-access.feature`](examples/accounts-and-access.feature): the groups, the view-only account and a refusal.

Copy them into `tests/features/` of the project and run them:

```bash
bash cmd-tools-testing.sh <site> --run --path tests/features/forms.feature
```

## The book

For any automated functional testing in this work (a Gherkin feature, a step definition, choosing a
step, a test run and its failures), read the book *Automated Functional Testing Recipes* first.

- **Where.** Use the first that exists: `.claude/automated-functional-testing-recipes/` in the project,
  `~/.claude/automated-functional-testing-recipes/` (installed by webship/webship-js-ai-agent,
  webship/webship-js-skills or webship/ai-agents), or
  https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes
- **How.** Its `README.md` first, then the chapter that matches the task (one file per chapter,
  named by its subject), not the single complete file.
- **Which wins.** The installed webship-js package and the step pack are the source of truth for
  step phrasing. When they differ from the book, follow them and say so.
- **For Django.** Start with `ch09-table-list-testing.md` (the lists, their rows and columns),
  `ch06-form-testing-recipes.md` (the forms and their fields), `ch10-authentication-authorization.md`
  (logins, sessions and refusals) and `ch21-when-tests-go-bad.md` (flaky, brittle and slow scenarios).
