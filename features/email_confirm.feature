Feature: Confirm email address

  Background:
    Given a new school and group with names "Example school 1", "Class 1" on the "example" organisation
    And the following users:
      | givenName | sn    | uid | password  | school_admin | puavoEduPersonAffiliation | mail           |
      | Ben       | Mabey | ben | bensecret | true         | student                   | ben@foobar.com |


  Scenario: Confirm email address
    Given generate new email confirm token for user "ben" with "ben@example.com" with secret "secret"
    When I am on the email confirm page
    Then I should see "Confirm your email address"
    When I fill in "Password" with "bensecret"
    And I press "Confirm"
    Then I should see "Your email address has been confirmed"

  Scenario: Confirm email address when first login failed
    Given generate new email confirm token for user "ben" with "ben@example.com" with secret "secret"
    When I am on the email confirm page
    And I fill in "Password" with "invalid bensecret"
    And I press "Confirm"
    Then I should see "Login failed! Please check your password."
    And I should see "Confirm your email address"
    When I fill in "Password" with "bensecret"
    And I press "Confirm"
    Then I should see "Your email address has been confirmed"

  Scenario: Invalid JWT token
    Given generate new email confirm token for user "ben" with "ben@example.com" with secret "BROKEN"
    When I am on the email confirm page
    Then I should see "Invalid JWT token"
