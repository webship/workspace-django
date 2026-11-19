Feature: The admin answers and its accounts work
  As the owner of the site
  I want the admin's login, each default account and the refusals to work
  So that a build that came out broken is caught before anything else is tested

  # Placed by the workspace's testing setup as a starting point: it is yours to change.
  # The accounts are the default ones (cmd-tools-django-manage.sh --add-users); a scenario logs in by a
  # handle of the users registry in cucumber.js, so no password is written here. It passes on a site
  # built with --install --add-users, with or without --polls.

  @critical
  Scenario: The admin login page is served
    Given I am not logged in
    Then I should be on the admin login page
    And the page should have a main landmark

  Scenario Outline: The <account> account logs in
    Given I am not logged in
    When I log in as "<account>" with the login form
    Then I should be logged in as "<account>"

    Examples:
      | account       |
      | administrator |
      | editor        |
      | viewer        |

  Scenario: A wrong password is refused
    Given I am not logged in
    When I log in with the user name "nobody at all" and the password "Wrong-password-1"
    Then the login should be refused with "Please enter the correct username and password for a staff account."
    And I should not be logged in

  Scenario: The administrator sees the accounts and their groups
    Given I am a logged in user with the "administrator" user
    Then the app "Authentication and Authorization" should list the model "Users"
    And the user "editor" should be staff
    And the user "editor" should be in the "Editors" group
    And the user "viewer" should be in the "Viewers" group

  @js-off
  Scenario: The editor may not open the accounts
    Given I am a logged in user with the "editor" user
    Then the admin index should not list the app "Authentication and Authorization"
    And I should not be allowed to open "/admin/auth/user/"
