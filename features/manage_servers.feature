Feature: Manage servers
  In order to [goal]
  [stakeholder]
  wants [behaviour]

  Background:
    Given a new school and group with names "Example school 1", "Class 1" on the "example" organisation
    And a new school and group with names "Example school 2", "Class 1" on the "example" organisation
    And the following servers:
    | puavoHostname | macAddress        |
    | someserver    | bc:5f:f4:56:59:71 |
    And I am logged in as "cucumber" with password "cucumber"

  Scenario: Edit server configuration
    Given I am on the server list page
    Then I should see "someserver"
    And I follow "someserver"
    And I follow "Edit..."
    And I check "Example school 2"
    And I press "Update"
    And I should see "Example school 2" within "#serverSchoolLimitBox"

  Scenario: Check for unique server tags
    Given I am on the server list page
    Then I should see "someserver"
    And I follow "someserver"
    And I follow "Edit..."
    And I fill in "Tags" with "tagA tagB"
    And I press "Update"
    And I should see "tagA tagB"

  Scenario: Check that duplicate tags are removed
    Given I am on the server list page
    Then I should see "someserver"
    And I follow "someserver"
    And I follow "Edit..."
    And I fill in "Tags" with "tagA tagB tagB"
    And I press "Update"
    And I should see "tagA tagB"

  Scenario: Primary user validation check
    Given I am on the server list page
    Then I should see "someserver"
    And I follow "someserver"
    And I follow "Edit..."
    And I fill in "Device primary user" with "invalid user"
    And I press "Update"
    And I should see "Device primary user is invalid"

  Scenario: Serial number validation check
    Given I am on the server list page
    Then I should see "someserver"
    And I follow "someserver"
    And I follow "Edit..."
    And I fill in "Serial number" with "ääääöööäääääööööö"
    And I press "Update"
    And I should see "Serial number contains invalid characters"

  Scenario: Hostname validation check
    Given I am on the server list page
    Then I should see "someserver"
    And I follow "someserver"
    And I follow "Edit..."
    And I fill in "Hostname" with "äasdöfäfäasdöfädsöfädf"
    And I press "Update"
    And I should see "Hostname contains invalid characters (allowed characters are: a-z0-9-)"
