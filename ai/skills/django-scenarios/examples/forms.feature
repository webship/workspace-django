Feature: The editor adds a question
  A question with a date, a category, tags and choices, and the refusal of a form without them.

  Background:
    Given there is no "Skill test question" in the "Questions" list
    And I am a logged in user with the "editor" user

  Scenario: Every kind of field
    When I open the add form of "Questions"
    And I set "Question text" to "Skill test question"
    And I set "Date published" to "2026-04-01 09:30:00"
    And I choose "Science" in the "Category" autocomplete
    And I choose "Fun, Serious" in the "Tags" selector
    And I fill in the "Choices" inline:
      | Choice text | Votes |
      | Yes         | 2     |
      | No          | 1     |
    And I save the form and continue editing
    Then the form should be saved
    And "Total votes" should be read-only and show "3"
    And the "Choices" inline should list "Yes"

  Scenario: A refused form
    When I open the add form of "Questions"
    And I save the form
    Then the form should show the error "Please correct the errors below."
    And the field "Question text" should have the error "This field is required."
