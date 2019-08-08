
Feature: Manage users
  In order to allow others to using all services
  As administrator
  I want to manage the set of users

  Background:
    Given a new school and group with names "School 1", "Class 4" on the "example" organisation
    And a new role with name "Class 4" and which is joined to the "Class 4" group
    And the following roles:
    | displayName |
    | Staffs      |
    And the following users:
      | givenName | sn     | uid   | password | school_admin | role_name | puavoEduPersonAffiliation |
      | Pavel     | Taylor | pavel | secret   | true         | Staffs     | staff                     |
    And I am logged in as "cucumber" with password "cucumber"

  Scenario: Create new user by staff
    Given I follow "Logout"
    And I am logged in as "pavel" with password "secret"
    When I am on the new user page
    Then I should not see "SSH public key"
    When I fill in the following:
    | Surname    | Doe      |
    | Given name | Jane     |
    | Username   | jane.doe |
    And I check "Student"
    And I check "Class 4"
    And I press "Create"
    Then I should see "Jane"
    And I should see "Doe"
    And I should not see "SSH public key"

  Scenario: Create new user
    Given the following groups:
    | displayName | cn      |
    | Class 6B    | class6b |
    And I am on the new user page
    When I fill in the following:
    | Surname                   | Mabey                 |
    | Given name                | Ben                   |
    | Username                  | ben                   |
    | user[mail][]              | ben.mabey@example.com |
    | user[telephoneNumber][]   | +35814123123123       |
    | user[new_password]        | secretpw              |
    | Confirm new password      | secretpw              |
    | Personnel Number          | 556677                |
    | SSH public key            | ssh-rsa Zm9vYmFy      |   # the key is "foobar" in base64
# FIXME test mail and telephoneNumber for more values
#   | Group                      |       |
#   | Password                   |       |
#   | Password confirmation      |       |
#   | puavoEduPersonEntryYear    |       |
#   | puavoEduPersonEmailEnabled |       |
    # And set photo?
    And I check "Student"
    And the "Language" select box should contain "Default"
    And the "Language" select box should contain "Finnish"
    And the "Language" select box should contain "Swedish \(Finland\)"
    And the "Language" select box should contain "English \(United States\)"
    And the "Language" select box should contain "German \(Switzerland\)"
    And I select "English (United States)" from "Language"
    And I check "Class 4"
    # FIXME
    And I choose "user_puavoAllowRemoteAccess_true"
    And I attach the file at "features/support/test.jpg" to "Image"
    And I press "Create"
    Then I should see the following:
    |                                                 |
    | Mabey                                           |
    | Ben                                             |
    | ben                                             |
    | Class 4                                         |
    | ben.mabey@example.com                           |
    | +35814123123123                                 |
    | Student                                         |
    | English (United States)                         |
    | Yes                                             |
    | Mabey Ben                                       |
    | 556677                                          |
    | 38:58:f6:22:30:ac:3c:91:5f:30:0c:66:43:12:c6:3f |
    And I should see "Class 4" on the "Groups by roles"
    And I should see image of "ben"
    And the memberUid should include "ben" on the "Class 4" group
    And the member should include "ben" on the "Class 4" group
    And the memberUid should include "ben" on the "Class 4" role
    And the member should include "ben" on the "Class 4" role
    And the memberUid should include "ben" on the "School 1" school
    And the member should include "ben" on the "School 1" school
    And the memberUid should include "ben" on the "Domain Users" samba group
    When I follow "Edit..."
    Then I am on the edit user page with "ben"
    When I follow "Cancel"
    Then I am on the show user page with "ben"
    #When I follow "Users" within ".navbarFirstLevel"
    When I follow "Users" within "#pageContainer #tabs .first"
    Then I should see "Mabey Ben"
    And I should see "ben"
    And I should see "Student"
    And I should see the following special ldap attributes on the "User" object with "ben":
    | preferredLanguage      | "en" |

  Scenario: Create duplicate user to organisation
    Given the following users:
      | givenName | surname | uid | password | role_name | puavoEduPersonAffiliation |
      | Ben       | Mabey   | ben | secret   | Class 4   | student                   |
    And I am on the new user page
    When I fill in the following:
    | Surname                   | Mabey                 |
    | Given name                | Ben                   |
    | Username                  | ben                   |
    | user[new_password]        | secretpw              |
    | Confirm new password      | secretpw              |
    And I check "Student"
    And I check "Class 4"
    And I press "Create"
    Then I should see "Username has already been taken"
    Then I should see "Failed to create the user!"

  Scenario: Create user with empty values
    Given the following users:
      | givenName | surname | uid | password | role_name | puavoEduPersonAffiliation |
      | Ben       | Mabey   | ben | secret   | Class 4   | student                   |
    And I am on the new user page
    And I press "Create"
    Then I should see "Failed to create the user!"
    And I should see "Given name can't be blank"
    And I should see "Surname can't be blank"
    And I should see "Username can't be blank"
    And I should see "User type can't be blank"
    And I should see "Roles can't be blank"

  Scenario: Create user with incorrect password confirmation
    And I am on the new user page
    When I fill in the following:
    | Surname                   | Mabey             |
    | Given name                | Ben               |
    | Username                  | ben               |
    | user[new_password]        | secretpw          |
    | Confirm new password      | test confirmation |
    And I check "Student"
    And I check "Class 4"
    And I press "Create"
    Then I should see "Failed to create the user!"
    And I should see "New password doesn't match the confirmation"

  Scenario: Edit user
    Given the following users:
      | givenName | surname | uid    | password | puavoEduPersonAffiliation | role_name |
      | Ben       | Mabey   | ben    | secret   | visitor                   | Class 4   |
      | Joseph    | Wilk    | joseph | secret   | visitor                   | Class 4   |
    And the following groups:
    | displayName | cn      |
    | Class 6B    | class6b |
    And I am on the edit user page with "ben"
    When I fill in the following:
    | Surname    | MabeyEDIT       |
    | Given name | BenEDIT         |
    | Username   | ben-edit        |
    | Email      | ben@example.com |
#   | Uid number                 |           |
#   | Home directory             |           |
#   | Telephone number           |           |
#   | puavoEduPersonEntryYear    |           |
#   | puavoEduPersonEmailEnabled |           |
#   | Password                   |           |
#   | Password confirmation      |           |
    # And set photo?
    And I check "Visitor"
    And I check "Staffs"
    And I attach the file at "features/support/test.jpg" to "Image"
    And I press "Update"
    Then I should see the following:
    |                 |
    | MabeyEDIT       |
    | BenEDIT         |
    | ben-edit        |
    | Staffs           |
    | Visitor         |
    | ben@example.com |
    And I should see "Class 4" on the "Groups by roles"
    And I should see image of "ben-edit"
    And the memberUid should include "ben-edit" on the "Class 4" group
    And the member should include "ben-edit" on the "Class 4" group
    And the memberUid should not include "ben" on the "Class 4" group
    And the memberUid should include "ben-edit" on the "Class 4" role
    And the member should include "ben-edit" on the "Class 4" role
    And the memberUid should not include "ben" on the "Class 4" role
    And the memberUid should include "ben-edit" on the "School 1" school
    And the memberUid should not include "ben" on the "School 1" school
    And the member should include "ben-edit" on the "School 1" school
    And the memberUid should include "ben-edit" on the "Domain Users" samba group
    And the memberUid should not include "ben" on the "Domain Users" samba group
    When I follow "Edit..."
    And I fill in "Given name" with "BenEDIT2"
    And I press "Update"
    Then I should see "User was successfully updated."
    Given I am on the show user page with "joseph"
    And I should see "Joseph"
    And I should see "Wilk"
    And I should see "joseph"
    And I should not see "BenEDIT"
    And I should not see "MabeyEDIT"
    And I should not see "ben-edit"

  Scenario: Listing users
    Given the following users:
      | givenName | surname | uid    | password | puavoEduPersonAffiliation | role_name |
      | Ben       | Mabey   | ben    | secret   | visitor                   | Class 4   |
      | Joseph    | Wilk    | joseph | secret   | visitor                   | Class 4   |
    And the following groups:
    | displayName | cn      |
    | Class 6B    | class6b |
    When I follow "School 1" within "#left"
    And I follow "Users" within "#pageContainer"
    Then I should see "Mabey Ben" within "#pageContainer"
    And I should not see /\["ben"\]/
    And I should not see "PuavoEduPersonAffiliation"



  Scenario: Delete user
    Given the following users:
      | givenName | surname | uid    | password | role_name | puavoEduPersonAffiliation | school_admin |
      | Ben       | Mabey   | ben    | secret   | Class 4   | admin                     | true         |
      | Joseph    | Wilk    | joseph | secret   | Class 4   | student                   | false        |
    And I am on the show user page with "ben"
    When I follow "Delete user"
    Then I should see "User was successfully removed."
    And the memberUid should not include "ben" on the "School 1" school
    And the "School 1" school not include incorret member values
    And the memberUid should not include "ben" on the "Class 4" group
    And the "Class 4" group not include incorret member values
    And the memberUid should not include "ben" on the "Class 4" role
    And the "Class 4" role not include incorret member values
    And the memberUid should not include "ben" on the "Domain Users" samba group
    And the "School 1" school not include incorret puavoSchoolAdmin values
    And the memberUid should not include "ben" on the "Domain Admins" samba group

  Scenario: Get user information in JSON
    Given the following users:
      | givenName | surname | uid    | password | role_name | puavoEduPersonAffiliation |
      | Ben       | Mabey   | ben    | secret   | Class 4   | student                   |
      | Joseph    | Wilk    | joseph | secret   | Class 4   | student                   |
    When I get on the show user JSON page with "ben"
    Then I should see JSON '{"given_name": "Ben", "surname": "Mabey", "uid": "ben"}'
    When I get on the users JSON page with "School 1"
    Then I should see JSON '[{"given_name": "Ben", "surname": "Mabey", "uid": "ben"},{"given_name": "Joseph", "surname": "Wilk", "uid": "joseph"}, {"given_name": "Pavel", "surname": "Taylor", "uid": "pavel"}]'

  Scenario: Check new user special ldap attributes
    Given the following users:
      | givenName | surname | uid | password | role_name | puavoEduPersonAffiliation |
      | Ben       | Mabey   | ben | secret   | Class 4   | student                   |
    Then I should see the following special ldap attributes on the "User" object with "ben":
    | sambaSID             | "^S-[-0-9+]"                   |
    | sambaAcctFlags       | "\[U\]"                        |
    | sambaPrimaryGroupSID | "^S-[-0-9+]"                   |
    | homeDirectory        | "/home/ben"                    |

  Scenario: Role selection does not lost when edit user and get error
    Given the following users:
      | givenName | surname | uid | password | puavoEduPersonAffiliation | role_name |
      | Ben       | Mabey   | ben | secret   | visitor                   | Class 4   |
    And I am on the edit user page with "ben"
    When I fill in "user[new_password]" with "some text"
    And I check "Staffs"
    And I press "Update"
    Then I should see "New password doesn't match the confirmation"
    And the "Staffs" checkbox should be checked

  Scenario: Role selection does not lost when create new user and get error
    Given I am on the new user page
    When I fill in the following:
    | Surname    | Mabey |
    | Given name | Ben   |
    | Username   | ben   |
    And I check "Class 4"
    And I press "Create"
    Then I should see "User type can't be blank"
    And the "Class 4" checkbox should be checked

  Scenario: Create new user with invalid username
    Given the following groups:
    | displayName | cn      |
    | Class 6B    | class6b |
    And I am on the new user page
    When I fill in the following:
    | Surname                   | Mabey                 |
    | Given name                | Ben                   |
    | user[mail][]              | ben.mabey@example.com |
    | user[telephoneNumber][]   | +35814123123123       |
    | user[new_password]        | secretpw              |
    | Confirm new password      | secretpw              |
    And I check "Student"
    And I check "Class 4"
    And I fill in "Username" with "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    And I press "Create"
    Then I should see "Username is too long (maximum is 255 characters)"
    When I fill in "Username" with "aa"
    And I press "Create"
    Then I should see "Username is too short (min is 3 characters)"
    When I fill in "Username" with "-ab"
    And I press "Create"
    Then I should see "Username must begin with a small letter"
    When I fill in "Username" with ".ab"
    And I press "Create"
    Then I should see "Username must begin with a small letter"
    When I fill in "Username" with "abc%&/()}]"
    And I press "Create"
    Then I should see "Username contains invalid characters (allowed characters are a-z0-9.-)"
    When I fill in "Username" with "ben.Mabey"
    And I press "Create"
    Then I should see "Username contains invalid characters (allowed characters are a-z0-9.-)"
    When I fill in "Username" with "ben-james.mabey"
    And I press "Create"
    Then I should see "User was successfully created."

  Scenario: Move user to another school
    Given the following users:
    | givenName | sn     | uid  | password | role_name | puavoEduPersonAffiliation |
    | Joe       | Bloggs | joe  | secret   | Class 4   | student                   |
    | Jane      | Doe    | jane | secret   | Class 4   | student                   |
    And a new school and group with names "Example school 2", "Class 5" on the "example" organisation
    And a new role with name "Class 5" and which is joined to the "Class 5" group
    And "pavel" is a school admin on the "Example school 2" school
    And I am on the show user page with "jane"
    When I follow "Change school"
    And I select "Example school 2" from "new_school"
    And I press "Continue"
    Then I should see "Select the new role"
    When I select "Class 5" from "new_role"
    And I press "Change the school"
    Then I should see "User(s) school has been changed!"
    And the sambaPrimaryGroupSID attribute should contain "Example school 2" of "jane"
    And the homeDirectory attribute should contain "Example school 2" of "jane"
    And the gidNumber attribute should contain "Example school 2" of "jane"
    And the puavoSchool attribute should contain "Example school 2" of "jane"
    And the memberUid should include "jane" on the "Example school 2" school
    And the member should include "jane" on the "Example school 2" school
    And the memberUid should not include "jane" on the "School 1" school
    And the member should not include "jane" on the "School 1" school
    And the memberUid should include "jane" on the "Class 5" group
    And the member should include "jane" on the "Class 5" group
    And the memberUid should not include "jane" on the "Class 4" group
    And the member should not include "jane" on the "Class 4" group
    And the memberUid should include "jane" on the "Class 5" role
    And the member should include "jane" on the "Class 5" role
    And the memberUid should not include "jane" on the "Class 4" role
    And the member should not include "jane" on the "Class 4" role

  Scenario: Lock user
    Given the following users:
      | givenName | surname | uid    | password | puavoEduPersonAffiliation | role_name |
      | Ben       | Mabey   | ben    | secret   | visitor                   | Class 4   |
      | Joseph    | Wilk    | joseph | secret   | visitor                   | Class 4   |
    And the following groups:
    | displayName | cn      |
    | Class 6B    | class6b |
    And I am on the edit user page with "ben"
    When I check "User is locked"
    And I press "Update"
    Then I should see "User is locked"

  Scenario: Create user with invalid SSH public key
    Given I am on the new user page
    When I fill in the following:
    | Surname        | Doe      |
    | Given name     | Jane     |
    | Username       | jane.doe |
    | SSH public key | foobar   |
    And I check "Class 4"
    And I check "Student"
    And I press "Create"
    Then I should see "Jane"
    And I should see "Doe"
    And I should see "Invalid public key"

  Scenario: Give the user a non-image file as the image
    Given I am on the new user page
    When I fill in the following:
    | Surname        | Doe      |
    | Given name     | Jane     |
    | Username       | jane.doe |
    And I attach the file at "features/support/hello.txt" to "Image"
    And I press "Create"
    Then I should see "Failed to save the image"

  Scenario: Give the user an invalid email address
    Given I am on the new user page
    When I fill in the following:
    | Surname        | Doe      |
    | Given name     | Jane     |
    | Username       | jane.doe |
    | user[mail][]              | foo<html>@bar.äää |
    And I press "Create"
    Then I should see "The email address is not valid."

  Scenario: Email addresses are trimmed
    Given I am on the new user page
    When I fill in the following:
    | Surname        | Donald                  |
    | Given name     | Duck                    |
    | Username       | donald.duck             |
    And I fill in "Email" with " donald.duck@calisota.us "
    And I check "Class 4"
    And I check "Student"
    And I press "Create"
    Then I should see "User was successfully created."
    And I should see "donald.duck@calisota.us"

  Scenario: Reverse name is updated
    Given the following users:
      | givenName | surname | uid    | password | puavoEduPersonAffiliation | role_name |
      | Donald    | Duck    | donald | 313      | visitor                   | Class 4   |
    Then I am on the show user page with "donald"
    And I should see "Donald Duck"
    And I should see "Duck Donald"
    #
    When I follow "Edit..."
    Then I am on the edit user page with "donald"
    And I fill in "Given name" with "Duck"
    And I fill in "Surname" with "Donald"
    And I fill in "Username" with "duck.donald"
    And I press "Update"
    Then I should see "User was successfully updated."
    And I should see "Duck Donald"
    And I should see "Donald Duck"

  Scenario: Prevent user deletion
    Given the following users:
      | givenName | surname | uid    | password | puavoEduPersonAffiliation | role_name |
      | Donald    | Duck    | donald | 313      | visitor                   | Class 4   |
    Then I am on the show user page with "donald"
    And I should see "Delete user"
    And I should see "Prevent deletion"
    When I follow "Prevent deletion"
    Then I should see "User deletion has been prevented."
    And I should see "This user cannot be deleted"
    And I should not see "Prevent deletion"
    And I should not see "Delete user"

  Scenario: Mark user for deletion
    Given the following users:
      | givenName | surname | uid    | password | puavoEduPersonAffiliation | role_name |
      | Donald    | Duck    | donald | 313      | visitor                   | Class 4   |
    Then I am on the show user page with "donald"
    And I should see "Delete user"
    And I should see "Mark for deletion"
    #
    When I follow "Mark for deletion"
    Then I should see "This user has been marked for deletion"
    And I should see "Remove deletion marking"
    And I should not see "Mark for deletion"
    And I should see "Delete user"
    #
    When I follow "Remove deletion marking"
    Then I should see "User is no longer marked for deletion"
    And I should not see "This user has been marked for deletion"
    And I should see "Mark for deletion"

  Scenario: Prevent the deletion of a user who has already been marked for deletion
    Given the following users:
      | givenName | surname | uid    | password | puavoEduPersonAffiliation | role_name |
      | Donald    | Duck    | donald | 313      | visitor                   | Class 4   |
    Then I am on the show user page with "donald"
    #
    When I follow "Mark for deletion"
    Then I should see "This user has been marked for deletion"
    #
    When I follow "Prevent deletion"
    Then I should see "User deletion has been prevented."
    And I should see "This user cannot be deleted"
    And I should not see "This user has been marked for deletion"
    And I should not see "Prevent deletion"
    And I should not see "Delete user"

  Scenario: Delete users who are marked for deletion
    Given the following users:
      | givenName | surname | uid    | password | puavoEduPersonAffiliation | role_name |
      | Donald    | Duck    | donald | 313      | visitor                   | Class 4   |
      | Daisy     | Duck    | daisy  | 314      | visitor                   | Class 4   |
    When I follow "School 1" within "#left"
    And I follow "Users" within "#pageContainer"
    And I should not see "Delete users who are marked for deletion"
    #
    Then I am on the show user page with "donald"
    And I should see "Delete user"
    And I should see "Mark for deletion"
    When I follow "Mark for deletion"
    Then I should see "This user has been marked for deletion"
    #
    When I follow "School 1" within "#left"
    And I follow "Users" within "#pageContainer"
    Then I should see "Users marked for later deletion"
    And I should see "Duck Donald" within "#pageContainer"
    And I should see "Duck Daisy" within "#pageContainer"
    And I should see "Delete users who are marked for deletion"
    #
    When I follow "Delete users who are marked for deletion"
    Then I should see "1 users removed"
    And I should not see "Duck Donald" within "#pageContainer"
    And I should see "Duck Daisy" within "#pageContainer"

# FIXME
#  @allow-rescue
#  Scenario: Get user infromation in JSON from wrong school
#    Given a new school and group with names "School 2", "Class 8"
#    And the following users:
#     | given_names | lastname | login | group   | password | password_confirmation |
#     | Gerry       | Cheevers | gerry | Class 8 | secret   | secret                |
#    When I get on the show user JSON page with "gerry"
#    Then I should see "You are not allowed to access this action."
#    When I am on the new user_session page
#    And I am logged in as "gerry" with password "secret"
#    And I get on the show user JSON page with "pavel"
#    Then I should see "You are not allowed to access this action."

