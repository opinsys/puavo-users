# Generic test helpers shared with rails and puavo-rest
require "webmock"

# XXX remove or think of some other mechanism for these:
temp_connect_hosts = ['puavo-standalone-test.puavo.net', '10.246.134.48']

connect_hosts = [ '127.0.0.1', 'localhost' ] + temp_connect_hosts

WebMock.allow_net_connect!
WebMock.disable_net_connect!(allow: connect_hosts)

module Puavo
module Test

  def self.setup_test_connection(organisation_key='example')
    test_organisation = Puavo::Organisation.find(organisation_key)
    default_ldap_configuration = ActiveLdap::Base.ensure_configuration

    # Setting up ldap configuration
    LdapBase.ldap_setup_connection(
      test_organisation.ldap_host,
      test_organisation.ldap_base,
      default_ldap_configuration["bind_dn"],
      default_ldap_configuration["password"]
    )

    owner = User.find(:first,
                      :attribute => "uid",
                      :value => test_organisation.owner)
    if owner.nil?
      raise "Cannot find organisation owner for '#{ organisation_key }'. Organisation not created?"
    end

    ExternalService.ldap_setup_connection(
      test_organisation.ldap_host,
      "o=puavo",
      "uid=admin,o=puavo",
      "password"
    )

    return owner.dn.to_s, test_organisation.owner_pw
  end

  def self.destroy_most_ldap_entries
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

    Device.all.each { |d| d.destroy }
    Server.all.each { |d| d.destroy }
    LdapService.all.each { |e| e.destroy }
    ExternalService.all.each { |e| e.destroy }
    ExternalFile.all.each { |e| e.destroy }
    Printer.all.each { |p| p.destroy }

    domain_users = SambaGroup.find('Domain Users')
    domain_users.memberUid = []
    domain_users.save

    domain_users = SambaGroup.find('Domain Admins')
    domain_users.memberUid = []
    domain_users.save
  end

  def self.clean_up_ldap
    owner_dn, owner_pw = setup_test_connection('example')
    destroy_most_ldap_entries()

    ldap_organisation = LdapOrganisation.current
    ldap_organisation.puavoDeviceOnHour = "14"
    ldap_organisation.puavoDeviceOffHour = "15"
    ldap_organisation.puavoDeviceAutoPowerOffMode = "off"
    ldap_organisation.puavoLocale = "en_US.UTF-8"
    ldap_organisation.o = "Example Organisation"
    ldap_organisation.puavoDomain = "example.puavo.net"
    ldap_organisation.puavoDeviceImage = nil
    ldap_organisation.puavoAllowGuest = nil
    ldap_organisation.puavoActiveService = nil
    ldap_organisation.puavoTimezone = "Europe/Helsinki"
    ldap_organisation.puavoKeyboardLayout = "en"
    ldap_organisation.puavoKeyboardVariant = "US"
    ldap_organisation.owner = ['uid=admin,o=puavo', owner_dn]
    ldap_organisation.puavoImageSeriesSourceURL = "https://foobar.puavo.net/organisationpref.json"
    ldap_organisation.puavoWlanSSID = []
    ldap_organisation.save!

    setup_test_connection('anotherorg')
    anotherorg = LdapOrganisation.current
    anotherorg.puavoDomain = "anotherorg.puavo.net"
    anotherorg.o = "Another Organisation"
    anotherorg.save!

    owner_dn, owner_pw = setup_test_connection('heroes')
    # The external logins testing code sets some "heroes"-organisation user
    # passwords to something else than "secret", so reset those.
    User.all.each do |user|
      user.set_password (user.dn.to_s == owner_dn ? owner_pw : 'secret')
      user.save!
    end

    # destroy users from organisation used for external_login tests
    setup_test_connection('external')
    destroy_most_ldap_entries()

    puavo_ca_url = "http://" + Puavo::CONFIG["puavo_ca"]["host"] + ":" + Puavo::CONFIG["puavo_ca"]["port"].to_s
    HTTP.basic_auth( :user => "uid=admin,o=puavo",
                     :pass => "password" )
      .delete(puavo_ca_url + "/certificates/test_clean_up")

    # restore connection
    setup_test_connection('example')
  end



end
end
