require_relative "../lib/local_store"
require_relative "../lib/samba_attrs"

module PuavoRest
class School < LdapModel
  include LocalStore
  include SambaAttrs

  ldap_map :dn, :dn
  ldap_map :puavoId, :id, LdapConverters::SingleValue
  ldap_map :puavoExternalId, :external_id, LdapConverters::SingleValue
  ldap_map :objectClass, :object_classes, LdapConverters::ArrayValue
  ldap_map :displayName, :name
  ldap_map :puavoSchoolCode, :school_code, LdapConverters::SingleValue
  ldap_map :puavoDeviceImage, :preferred_image
  ldap_map :puavoSchoolHomePageURL, :homepage
  ldap_map(:puavoPrinterQueue, :printer_queue_dns){ |v| Array(v) }
  ldap_map(:puavoWirelessPrinterQueue, :wireless_printer_queue_dns){ |v| Array(v) }
  ldap_map :preferredLanguage, :preferred_language
  ldap_map :puavoLocale, :locale
  ldap_map :puavoWlanSSID, :wlan_networks, LdapConverters::ArrayOfJSON
  ldap_map :puavoAllowGuest, :allow_guest, LdapConverters::StringBoolean
  ldap_map :puavoAutomaticImageUpdates, :automatic_image_updates, LdapConverters::StringBoolean
  ldap_map :puavoPersonalDevice, :personal_device, LdapConverters::StringBoolean
  ldap_map(:puavoTag, :tags){ |v| Array(v) }
  ldap_map :puavoConf, :puavoconf, LdapConverters::PuavoConfObj
  ldap_map :gidNumber, :gid_number, LdapConverters::Number
  ldap_map :cn, :abbreviation
  ldap_map(:puavoActiveService, :external_services) do |es|
      Array(es).map { |s| s.downcase.strip }
  end
  ldap_map(:puavoMountpoint, :mountpoints){|m| Array(m).map{|json| JSON.parse(json) }}
  ldap_map :puavoTimezone, :timezone
  ldap_map :puavoKeyboardLayout, :keyboard_layout
  ldap_map :puavoKeyboardVariant, :keyboard_variant
  ldap_map :puavoImageSeriesSourceURL, :image_series_source_urls, LdapConverters::ArrayValue

  # Internal attributes, do not use! These are automatically set when
  # User#school_dns is updated
  ldap_map :member, :member_dns, LdapConverters::ArrayValue
  ldap_map :memberUid, :member_usernames, LdapConverters::ArrayValue

  ldap_map :puavoDeviceAutoPowerOffMode, :autopoweroff_mode
  ldap_map :puavoDeviceOnHour,           :daytime_start_hour
  ldap_map :puavoDeviceOffHour,          :daytime_end_hour

  before :create do
    if Array(object_classes).empty?
      self.object_classes = ['top','posixGroup','puavoSchool','sambaGroupMapping']
    end

    if id.nil?
      self.id = IdPool.next_id("puavoNextId").to_s
    end

    if gid_number.nil?
      self.gid_number = IdPool.next_id("puavoNextGidNumber")
    end

    if dn.nil?
      self.dn = "puavoId=#{ id },#{ self.class.ldap_base }"
    end

    write_samba_attrs

    # FIXME set sambaSID and sambaGroupType
  end


  def self.ldap_base
    "ou=Groups,#{ organisation["base"] }"
  end

  def self.base_filter
    "(objectClass=puavoSchool)"
  end

  computed_attr :puavo_id
  def puavo_id
    id
  end

  def printer_queues
    @printer_queues ||= PrinterQueue.by_dn_array(printer_queue_dns)
  end

  def wireless_printer_queues
    @wireless_printer_queues ||= PrinterQueue.by_dn_array(wireless_printer_queue_dns)
  end

  def mountpoints=(value)
    write_raw(:puavoMountpoint, value.map{|m| m.to_json})
  end

  # Cached organisation query
  def organisation
    @organisation ||= Organisation.by_dn(self.class.organisation["base"])
  end

  def devices
    Device.by_attr(:school_dn, dn, :multiple => true)
  end

  def ltsp_servers
    LtspServer.by_attr(:school_dns, dn, :multiple => true)
  end

  def preferred_image
    image = get_own(:preferred_image)
    image ? image.strip : organisation.preferred_image
  end

  def allow_guest
     if get_own(:allow_guest).nil?
       organisation.allow_guest
     else
       get_own(:allow_guest)
     end
  end

  def automatic_image_updates
     if get_own(:automatic_image_updates).nil?
       organisation.automatic_image_updates
     else
       get_own(:automatic_image_updates)
     end
  end

  def personal_device
     if get_own(:personal_device).nil?
       organisation.personal_device
     else
       get_own(:personal_device)
     end
  end

  def image_series_source_urls
     if get_own(:image_series_source_urls).empty?
       organisation.image_series_source_urls
     else
       get_own(:image_series_source_urls)
     end
  end

  def preferred_language
    if get_own(:preferred_language).nil?
      organisation.preferred_language
    else
      get_own(:preferred_language)
    end
  end

  def locale
    if get_own(:locale).nil?
      organisation.locale
    else
      get_own(:locale)
    end
  end

  def puavoconf
    (organisation.puavoconf || {}) \
      .merge(get_own(:puavoconf) || {})
  end

  def timezone
    if get_own(:timezone).nil?
      organisation.timezone
    else
      get_own(:timezone)
    end
  end

  def keyboard_layout
    if get_own(:keyboard_layout).nil?
      organisation.keyboard_layout
    else
      get_own(:keyboard_layout)
    end
  end

  def keyboard_variant
    if get_own(:keyboard_variant).nil?
      organisation.keyboard_variant
    else
      get_own(:keyboard_variant)
    end
  end

  def autopoweroff_attr_with_organisation_fallback(attr)
    [ nil, 'default' ].include?( get_own(:autopoweroff_mode) ) \
      ? organisation.send(attr)                                \
      : get_own(attr)
  end

  autopoweroff_attrs = [ :autopoweroff_mode,
                         :daytime_start_hour,
                         :daytime_end_hour ]
  autopoweroff_attrs.each do |attr|
    define_method(attr) { autopoweroff_attr_with_organisation_fallback(attr) }
  end

  # Write internal samba attributes. Implementation is based on the puavo-web
  # code is not actually tested on production systems
  def write_samba_attrs
    set_samba_sid

    write_raw(:sambaGroupType, ["2"])
  end

end

class Schools < PuavoSinatra
  get "/v3/schools" do
    auth :basic_auth, :server_auth, :kerberos
    json School.all
  end

  get "/v3/schools/:school_id/users" do
    auth :basic_auth, :kerberos
    school = School.by_attr!(:id, params["school_id"])
    json User.by_attr(:school_dns, school.dn, :multiple => true)
  end

  get "/v3/schools/:school_id/groups" do
    auth :basic_auth, :kerberos
    school = School.by_attr!(:id, params["school_id"])
    json Group.by_attr(:school_dn, school.dn, :multiple => true)
  end

  get "/v3/schools/:school_id/teaching_groups" do
    auth :basic_auth, :kerberos
    school = School.by_attr!(:id, params["school_id"])
    json Group.teaching_groups_by_school(school)
  end
end



end
