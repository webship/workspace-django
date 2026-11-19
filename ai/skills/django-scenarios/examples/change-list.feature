Feature: The editor finds questions in the list
  The list of questions of a site built with the polls app: 24 sample questions, 10 a page.

  Background:
    Given I am a logged in user with the "editor" user
    And I am on the "Questions" list

  Scenario: A search and a filter
    When I search the list for "train"
    Then the search should find 2 results of 24
    And the list should show "Do you travel by train or by plane?"
    When I search the list for ""
    And I choose "Science" in the "By category" filter
    Then the list should count 5 questions

  Scenario: Sorting and the pages
    When I sort the list by "Date published"
    Then the first row of the list should be "What's up?"
    And the list should have 3 pages
    When I go to page 3 of the list
    Then the list should have 4 rows
