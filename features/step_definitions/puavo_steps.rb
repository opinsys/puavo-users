require 'digest'
require 'base64'
require 'timecop'

Before do |scenario|
  test_organisation = Puavo::Organisation.find('example')
  default_ldap_configuration = ActiveLdap::Base.ensure_configuration
  # Setting up ldap configuration
  LdapBase.ldap_setup_connection( test_organisation.ldap_host,
                                  test_organisation.ldap_base,
                                  default_ldap_configuration["bind_dn"],
                                  default_ldap_configuration["password"] )

  @owner_dn = User.find(:first, :attribute => "uid", :value => test_organisation.owner).dn.to_s
  @owner_password = test_organisation.owner_pw

  LdapBase.ldap_setup_connection( test_organisation.ldap_host,
                                  test_organisation.ldap_base,
                                  @owner_dn,
                                  @owner_password )

  # Clean Up LDAP server: destroy all schools, groups and users
  User.all.each do |u|
    unless u.uid == "cucumber"
      u.destroy
    end
  end
  Group.all.each do |g|
    unless g.displayName == "Maintenance"
      g.destroy
    end
  end
  School.all.each do |s|
    unless s.displayName == "Administration"
      s.destroy
    end
  end
  Role.all.each do |p|
    unless p.displayName == "Maintenance"
      p.destroy
    end
  end

  ExternalService.all.each do |e| e.destroy end

  OauthClient.all.each do |c| c.destroy end

  domain_users = SambaGroup.find('Domain Users')
  domain_users.memberUid = []
  domain_users.save

  domain_users = SambaGroup.find('Domain Admins')
  domain_users.memberUid = []
  domain_users.save

  ldap_organisation = LdapOrganisation.current
  ldap_organisation.preferredLanguage = "fi"
  ldap_organisation.puavoDeviceOnHour = "14"
  ldap_organisation.puavoDeviceOffHour = "15"
  ldap_organisation.puavoDeviceAutoPowerOffMode = "off"
  ldap_organisation.preferredLanguage = "en"
  ldap_organisation.o = "Example Organisation"
  ldap_organisation.save!
end

Given /^I am logged in as "([^\"]*)" organisation owner$/ do |organisation_name|
  organisation = Puavo::Organisation.find(organisation_name)

  visit login_path
  fill_in("Username", :with => organisation.owner)
  fill_in("Password", :with => organisation.owner_pw)
  click_button("Login")
  page.should have_content("Login successful!")
end

Given /^a new ([^\"]*) with names (.*) on the "([^\"]*)" organisation$/ \
do |names_of_the_models, values, organisation|
  set_ldap_admin_connection
  Puavo::Organisation.find(organisation)
  models = names_of_the_models.split(' and ')
  values = values.split(', ').map { |value| value.tr('"', '') }
  models_value = Hash.new
  index = 0
  models.each do |model|
    models_value[model] = values[index]
    index += 1
  end

  if models_value.has_key?('school')
    @school = School.new( :displayName =>  models_value['school'],
                          :cn => models_value['school'].downcase.gsub(/[^a-z0-9]/, "")
                          )
    @school.save!
  end
  if models_value.has_key?('group')
    @group = Group.create( :displayName => models_value['group'],
                           :cn => models_value['group'].downcase.gsub(/[^a-z0-9]/, "") )
    @school.groups << @group
  end
end

Given /^"([^\"]*)" is a school admin on the "([^\"]*)" school$/ do |uid, school_name|
  set_ldap_admin_connection
  school = School.find(:first, :attribute => "displayName", :value => school_name)
  user = User.find(:first, :attribute => "uid", :value => uid)
  user.puavoAdminOfSchool = Array(user.puavoAdminOfSchool).push school.dn
  user.save
  school.puavoSchoolAdmin = Array(school.puavoSchoolAdmin) + Array(user.dn)
  school.save
end

When /^I check field by id "([^\"]*)"$/ do |field_id|
  check( field_with_id(field_id) )
end

Given /^I am on ([^\"]+) with "([^\"]*)"$/ do |page_name, value|
  set_ldap_admin_connection
  case page_name
  when /user page$/
    user = User.find(:first, :attribute => "uid", :value => value)
    case page_name
    when /edit/
      visit edit_user_path(@school, user)
    when /show/
      visit user_path(@school, user)
    end
  when /school page$/
    @school = School.find( :first, :attribute => "displayName", :value => value )
    visit school_path(@school)
    #visit path_to(page_name) # FIXME
  when /group page/
    group = Group.find( :first, :attribute => "displayName", :value => value )
    case page_name
    when /the group page/
      visit group_path(@school, group)
    when /the edit group page/
      visit edit_group_path(@school, group)
    end
  when /role page/
    role = Role.find( :first, :attribute => "displayName", :value => value )
    case page_name
    when /show/
      visit role_path(@school, role)
    when /edit/
      visit edit_role_path(@school, role)
    end
  else
    raise "Unknow page: #{page_name}"
  end
end

When /^I get on ([^\"]+) with "([^\"]*)"$/ do |page_name, value| 
  page.driver.browser.basic_authorize('cucumber', 'cucumber')
  case page_name
  when /user JSON page$/
    @json_user = User.find(:first, :attribute => "uid", :value => value)
    case page_name
    when /show/
      visit "/users/users/" + @json_user.id.to_s + ".json"
    end
  when /users JSON page$/
    # FIXME:
    #school = School.find(:first, :attribute => "displayName", :value => value)
    visit users_path(@school, :format => :json)
  when /members group JSON page$/
    json_group = Group.find(:first, :attribute => "displayName", :value => value)
    visit "/users/#{@school.id}/groups/" + json_group.id.to_s + "/members.json"
  end
end

Then /^I should see JSON '([^\']*)'$/ do |json_string|
  response_data = ActiveSupport::JSON.decode(page.body)
  compare_data = ActiveSupport::JSON.decode(json_string)

  if compare_data.class == Hash
    response_data = [response_data]
    compare_data = [compare_data]
  end

  keys = compare_data.first.keys
  response_data.each do |r|
    r.keys.each do |k|
      unless keys.include?(k)
        r.delete(k)
      end
    end
  end

  if response_data.first
    keys = response_data.first.keys
  else
    keys = []
  end

  response_data = response_data.sort { |a,b| stringify(a, keys) <=> stringify(b, keys) }
  compare_data = compare_data.sort { |a,b| stringify(a, keys) <=> stringify(b, keys) }
  response_data.length.should == compare_data.length
  response_data.each_index do |i|
    response_data[i].should == compare_data[i]
  end
end

private

def stringify(hash_data, keys)
  keys.map{ |k| "#{k} => #{hash_data[k]}" }.join
end

def sort_tags(tags)
  return tags.split(TagList.delimiter).sort.join(TagList.delimiter)
end

When /^I fill in textarea "([^\"]*)" with "([^\"]*)"$/ do |field, value|
  fill_in(field, :with => value)
end

Then /^I should see the following:$/ do |values|
  values.rows.each do |value|
    step %{I should see "#{value.first}"}
  end
end

Then /^named the "([^\"]*)" field should contain "([^\"]*)"$/ do |field, value|
  field_named(field).value.should =~ /#{value}/
end

Then /^id the "([^\"]*)" field should contain "([^\"]*)"$/ do |field_id, value|
  field_with_id(field_id).value.should =~ /#{value}/
end

Then /^id the "([^\"]*)" field should not contain "([^\"]*)"$/ do |field_id, value|
  field_with_id(field_id).value.should_not =~ /#{value}/
end

Then /^"([^"]*)" should be selected for "([^"]*)"$/ do |value, field_id|
  field_with_id(field_id).native.search(".//option[@selected = 'selected']").inner_html.should =~ /#{value}/
end

Then /^I can select "([^\"]*)" from the "([^\"]*)"$/ do |value, field_id|
  field_with_id(field_id).native.inner_html.should =~ /#{value}/
end

Then /^the "([^\"]*)" select box should contain "([^\"]*)"$/ do |field, value|
  field_labeled(field).native.inner_html.should =~ /#{value}/
end

Then /^I can not select "([^\"]*)" from the "([^\"]*)"$/ do |value, field|
  field_labeled(field).native.inner_html.should_not =~ /#{value}/
end
Then /^the "([^\"]*)" ([^ ]+) not include incorret ([^ ]+) values$/ do |object_name, class_name, method|
  object = eval(class_name.capitalize).send("find", :first, :attribute => 'displayName', :value => object_name)
  Array(object.send(method)).each do |dn|
    lambda{ User.find(dn) }.should_not raise_error
  end
end

When /^I follow "([^\"]*)" on the "([^\"]*)" ([^ ]+)$/ do |link_name, name, model|
  set_ldap_admin_connection
  link_id = link_name.downcase + "_#{model}_" + 
    eval(model.capitalize).send("find", :first,
                                :attribute => "displayName",
                                :value => name ).id.to_s
  steps %Q{
    When I follow "#{link_id}"
  }
end


Then /^the ([^ ]*) should include "([^\"]*)" on the "([^\"]*)" (.*)$/ do |method, uid, object_name, model|
  memberUid_include?(model, object_name, method, uid).should == true
end

Then /^the ([^ ]*) should not include "([^\"]*)" on the "([^\"]*)" (.*)$/ do |method, uid, object_name, model|
  memberUid_include?(model, object_name, method, uid).should == false
end

When /^I follow the PDF link "([^\"]*)"$/ do |link_name|
  click_link(link_name)
  tmp_pdf = Tempfile.new('tmp_pdf')
  tmp_pdf.binmode # Switch to binary mode to avoid encoding errors
  tmp_pdf << page.body
  tmp_pdf.close
  tmp_txt = Tempfile.new('tmp_txt')
  tmp_txt.close
  `pdftotext -q #{tmp_pdf.path} #{tmp_txt.path}`
  @pdf_text = File.read tmp_txt.path
end

Then /^I should see "([^\"]*)" on the PDF$/ do |text|
  @pdf_text.should have_content(text)
end

When /^I cut nextPuavoId value by one$/ do
  pool = IdPool.find('IdPool')
  pool.puavoNextId -= 1
  pool.save!
end

Then /^I should see "([^\"]*)" titled "([^\"]*)"$/ do |text, title|
  page.has_xpath?("//div[text()='#{text}'][@title='#{ title }']")
end

def memberUid_include?(model, object_name, method, uid)
  set_ldap_admin_connection
  # manipulate string to Class name, e.g. "school" -> "School", "samba group" -> "SambaGroup"
  model = model.split(" ").map { |m| m.capitalize }.join("")
  object = Class.class_eval(model).find( :first, :attribute => "displayName", :value => object_name )
  
  case method
  when "member"
    user = User.find( :first, :attribute => "uid", :value => uid )
    return Array(object.send(method)).include?(user.dn)
  when "memberUid"
    return Array(object.send(method)).include?(uid)
  end
end

def set_ldap_admin_connection
  unless LdapBase.connected?
    test_organisation = Puavo::Organisation.find('example')
    default_ldap_configuration = ActiveLdap::Base.ensure_configuration
    # Setting up ldap configuration
    LdapBase.ldap_setup_connection( test_organisation.ldap_host,
                                    test_organisation.ldap_base,
                                    @owner_dn,
                                    @owner_password )
  end
end

Given /^I wait ([0-9]+) (hour|day|month|year)s?$/ do |digit, type|
  Timecop.travel Time.now + digit.to_i.send(type)
end

