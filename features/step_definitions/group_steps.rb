Given(/^the following groups to "(.*?)"$/) do |school_name, groups|
  set_ldap_admin_connection
  school = School.find(:first, :attribute => "displayName", :value => school_name)
  groups.hashes.each do |new_group| 
    new_group[:puavoSchool] = school.dn
    group = Group.create(new_group)
  end
end

Given /^the following groups:$/ do |groups|
  set_ldap_admin_connection
  groups.hashes.each do |new_group| 
    new_group[:puavoSchool] = @school.dn
    group = Group.create(new_group)
  end
end
