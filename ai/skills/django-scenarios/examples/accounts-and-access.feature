Feature: Who may do what in the admin
  The groups of the default accounts, a view-only account, and a page an account is refused.

  Scenario: The groups and their permissions
    Given I am a logged in user with the "administrator" user
    Then the user "editor" should be in the "Editors" group
    And the "Viewers" group should have the "Can view question" permission
    And the "Viewers" group should not have the "Can change question" permission

  Scenario: The viewer reads a question without changing it
    Given I am a logged in user with the "viewer" user
    And I am on the "Questions" list
    When I search the list for "What's up"
    And I open "What's up?" from the list
    Then I should see the "View question" form for "What's up?"
    And the form should be read-only

  @js-off
  Scenario: The editor is refused the accounts
    Given I am a logged in user with the "editor" user
    Then I should not be allowed to open "/admin/auth/user/"
