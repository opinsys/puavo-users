Given /^the following roles:$/ do |roles|
  set_ldap_admin_connection
  roles.hashes.each do |new_role|
    new_role[:puavoSchool] = @school.dn
    Role.create(new_role)
  end
end

When /^I delete the (\d+)(?:st|nd|rd|th) role$/ do |pos|
  visit roles_url
  within("table tr:nth-child(#{pos.to_i+1})") do
    click_link "Destroy"
  end
end

Then /^I should see the following roles:$/ do |expected_roles_table|
  rows = find('table').all('tr')
  table = rows.map { |r| r.all('th,td').map { |c| c.text.strip } }
  expected_roles_table.diff!(table)
end

Given /^a new role with name "([^\"]*)" and which is joined to the "([^\"]*)" group$/ do
  |role_name, group_name|
  group = Group.find( :first,
                      :attribute => "displayName",
                      :value => group_name )
  role = Role.new
  role.displayName = role_name
  role.puavoSchool = @school.dn
  role.save
  role.groups << group
end

Given /^a new role with name "([^\"]*)" and which is joined to the "([^\"]*)" group to "([^\"]*)" school$/ do
  |role_name, group_name, school_name|
  group = Group.find( :first,
                      :attribute => "displayName",
                      :value => group_name )
  role = Role.new
  role.displayName = role_name
  role.puavoSchool = School.find(:first, :attribute => "displayName", :value => school_name).dn
  role.save
  role.groups << group
end
